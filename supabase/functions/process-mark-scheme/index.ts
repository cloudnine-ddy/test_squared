import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// PROCESS MARK SCHEME (V2 - Robust Chunked Parallelism)
// 1. Extracts all answers from MS
// 2. Matches them to Question Blocks in memory
// 3. Queues AI tasks (explanations)
// 4. Processes AI tasks in limited batches (Concurrency Control)
// 5. Updates Database

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'
const MAX_RETRIES = 5
const CONCURRENCY_LIMIT = 1 // Sequential processing to respect 10 RPM limit

// Retry helper
async function fetchWithRetry(url: string, options: RequestInit, retries = MAX_RETRIES): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options)
      if (response.ok) return response
      if (i < retries - 1) {
        await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
      } else {
        return response
      }
    } catch (e) {
      if (i === retries - 1) throw e
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
    }
  }
  throw new Error('Max retries exceeded')
}

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { paperId, markSchemeUrl } = await req.json()
    if (!paperId || !markSchemeUrl) {
      return new Response(JSON.stringify({ error: 'Missing parameters' }), { status: 400, headers: corsHeaders })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    const apiKey = Deno.env.get('GEMINI_API_KEY')
    if (!apiKey) throw new Error('GEMINI_API_KEY missing')

    // 1. Fetch Questions
    const { data: questions, error: qError } = await supabase
      .from('questions')
      .select('id, question_number, structure_data, content, type')
      .eq('paper_id', paperId)
      .eq('type', 'structured')
    
    if (qError || !questions || !questions.length) {
      return new Response(JSON.stringify({ success: true, message: 'No questions' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    console.log(`Processing ${questions.length} questions...`)

    // 2. Download Mark Scheme
    const msRes = await fetch(markSchemeUrl)
    if (!msRes.ok) throw new Error('Failed to download PDF')
    const msBlob = await msRes.arrayBuffer()
    const msPdfDoc = await PDFDocument.load(msBlob)
    
    // Convert to base64
    let msBase64 = '';
    const u8 = new Uint8Array(await msPdfDoc.save());
    const chunkSize = 32768;
    for(let i=0; i<u8.length; i+=chunkSize) {
        msBase64 += String.fromCharCode(...u8.subarray(i, i+chunkSize));
    }
    msBase64 = btoa(msBase64);

    // 3. Extract Answers with Gemini
    const prompt = `You are a MARK SCHEME EXTRACTOR.
Extract ALL answers for this paper.

OUTPUT JSON:
{
  "answers": [
    { "question_number": 1, "sub_part": "a", "official_answer": "Force = mass x acceleration", "marks": 1 },
    { "question_number": 1, "sub_part": "b(i)", "official_answer": "150 N", "marks": 2 }
  ]
}

RULES:
1. Extract answers for EVERY question and sub-part.
2. "sub_part" should match valid part labels like "a", "b", "i", "ii", "a(i)". 
3. "official_answer": The exact text from the mark scheme key.
4. "marks": Marks awarded.`;

    const geminiRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: 'application/pdf', data: msBase64 } }] }],
            generationConfig: { temperature: 0.1, maxOutputTokens: 16384, responseMimeType: "application/json" }
        })
    })

    const geminiJson = await geminiRes.json()
    const rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || '{}'
    const extractedAnswers = JSON.parse(rawText).answers || []
    console.log(`Extracted ${extractedAnswers.length} official answers.`)

    // 4. Match & Build Work Queue
    const aiQueue: any[] = []
    const modifiedQuestions = new Set<string>()

    for (const q of questions) {
        let qModified = false;
        const blocks = (q.structure_data || []) as any[];
        
        // Filter answers relevant to this question (Normalize to string)
        const qAnswers = extractedAnswers.filter((a: any) => String(a.question_number) === String(q.question_number));

        if (qAnswers.length === 0) {
            console.log(`No answers found for Q${q.question_number}`);
        }

        for (const block of blocks) {
            if (block.type === 'question_part') {
                const cleanBlockLabel = (block.label || '').replace(/[^a-z0-9]/gi, '').toLowerCase(); 
                
                // Strategy 1: Exact Match
                let match = qAnswers.find((a: any) => {
                    const cleanAnsLabel = (a.sub_part || '').replace(/[^a-z0-9]/gi, '').toLowerCase();
                    return cleanAnsLabel === cleanBlockLabel;
                });

                // Strategy 2: Fuzzy "Ends With" Match (e.g. Block "ii" matches Ans "aii")
                // Only if no exact match and block label is not empty
                if (!match && cleanBlockLabel.length > 0) {
                     match = qAnswers.find((a: any) => {
                        const cleanAnsLabel = (a.sub_part || '').replace(/[^a-z0-9]/gi, '').toLowerCase();
                        return cleanAnsLabel.endsWith(cleanBlockLabel);
                    });
                }
                
                if (!match) {
                     // Last resort log
                     // console.log(`Failed to match Q${q.question_number} part "${block.label}"...`);
                }

                if (match) {
                    // Update metadata immediately
                    block.official_answer = match.official_answer;
                    block.marks = match.marks || block.marks;
                    qModified = true;

                    // Add AI Task to Queue
                    aiQueue.push({
                        block,
                        question_content: block.content, // Context for AI
                        official_answer: match.official_answer,
                        question_number: q.question_number,
                        label: block.label
                    });
                }
            }
        }
        if (qModified) modifiedQuestions.add(q.id);
    }

    console.log(`Queued ${aiQueue.length} AI explanations. Processing in batches of ${CONCURRENCY_LIMIT}...`)

    // 5. Process AI Queue (Chunked & Throttled)
    for (let i = 0; i < aiQueue.length; i += CONCURRENCY_LIMIT) {
        const batch = aiQueue.slice(i, i + CONCURRENCY_LIMIT);
        
        // Wait 2 seconds BETWEEN batches (Optimized for speed, relying on retries)
        if (i > 0) {
            console.log("Throttling for rate limit (2s)...");
            await new Promise(r => setTimeout(r, 2000));
        }

        await Promise.all(batch.map(async (task) => {
            const aiPrompt = `You are a helpful tutor explaining an exam solution.
            
Question: "${task.question_content}"
Official Mark Scheme Answer: "${task.official_answer}"

Your Task:
1. EXPLAIN why this is the correct answer.
2. If the mark scheme is brief (e.g., just keywords), expand it into full sentences.
3. Don't just repeat the answer - explain the concept.

Output: A clear, student-friendly explanation.`;

            try {
                const solRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ 
                        contents: [{ parts: [{ text: aiPrompt }] }],
                        generationConfig: { maxOutputTokens: 300 }
                    })
                }, 1); // 1 retry

                if (solRes.ok) {
                    const solJson = await solRes.json();
                    const solText = solJson.candidates?.[0]?.content?.parts?.[0]?.text;
                    if (solText) task.block.ai_answer = solText;
                }
            } catch (e) {
                console.warn(`AI failed for Q${task.question_number} ${task.label}`, e);
            }
        }));
    }

    // 6. Save Updates
    let savedCount = 0;
    for (const q of questions) {
        if (modifiedQuestions.has(q.id)) {
            await supabase.from('questions')
                .update({ structure_data: q.structure_data })
                .eq('id', q.id);
            savedCount++;
        }
    }

    return new Response(JSON.stringify({
        success: true,
        message: `Updated ${savedCount} questions with official answers and AI explanations.`,
        answers_found: extractedAnswers.length
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('Fatal:', error)
    return new Response(JSON.stringify({ error: String(error) }), { status: 500, headers: corsHeaders })
  }
})
