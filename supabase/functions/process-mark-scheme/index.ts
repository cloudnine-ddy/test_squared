
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// PROCESS MARK SCHEME (V3 - Unified Background Processing)
// Supports both MCQ and Structured Papers.
// Runs in background to prevent client timeouts.

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent'
const MAX_RETRIES = 5
const CONCURRENCY_LIMIT = 5 // Increased concurrency for speed (5 workers)

async function fetchWithRetry(url: string, options: RequestInit, retries = MAX_RETRIES): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options)
      if (response.ok) return response
      if (i < retries - 1) await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
      else return response
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

    console.log(`[Request] Starting Mark Scheme processing for ${paperId}`)

    // BACKGROUND PROCESSING
    const processingPromise = (async () => {
        try {
            const supabase = createClient(
                Deno.env.get('SUPABASE_URL') ?? '',
                Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
            )
            const apiKey = Deno.env.get('GEMINI_API_KEY')
            if (!apiKey) throw new Error('GEMINI_API_KEY missing')

            // 1. Fetch Questions (ALL types)
            const { data: questions, error: qError } = await supabase
                .from('questions')
                .select('id, question_number, structure_data, content, type, ai_answer, official_answer')
                .eq('paper_id', paperId)
            
            if (qError || !questions || !questions.length) {
                console.log("No questions found, aborting background task.")
                return
            }
            console.log(`Processing ${questions.length} questions (Background)...`)

            // 2. Download Mark Scheme
            const msRes = await fetch(markSchemeUrl)
            if (!msRes.ok) throw new Error('Failed to download PDF')
            const msBlob = await msRes.arrayBuffer()
            const msPdfDoc = await PDFDocument.load(msBlob)

            // Convert to base64
            let msBase64 = '';
            const u8 = new Uint8Array(await msPdfDoc.save());
            const chunkSize = 32768;
            for(let i=0; i<u8.length; i+=chunkSize) msBase64 += String.fromCharCode(...u8.subarray(i, i+chunkSize));
            msBase64 = btoa(msBase64);

            // 3. Extract Answers with Gemini
            // Prompt optimized to handle BOTH MCQ and Structured formats
            const prompt = `EXTRACT OFFICIAL ANSWERS.
OUTPUT JSON:
{ "answers": [ 
  {"question_number": 1, "sub_part": "a", "official_answer": "cell A", "marks": 1},
  {"question_number": 2, "official_answer": "B", "marks": 1} 
] }
RULES:
1. MCQ: Answer is letter (A,B,C,D).
2. Structured: Answer is key marking points.
3. Sub-parts: "a", "b(i)". If none, omit sub_part.
4. Marks: Default 1 if unclear.`;

            const geminiRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: 'application/pdf', data: msBase64 } }] }],
                    generationConfig: { temperature: 0.1, maxOutputTokens: 16384, responseMimeType: "application/json" }
                })
            })

            const geminiJson = await geminiRes.json()
            let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || '{}'

            // Robust JSON Parse
            let extractedAnswers: any[] = []
            try {
                extractedAnswers = JSON.parse(rawText.replace(/```json|```/g, '').trim()).answers || []
            } catch(e) {
                try {
                    const match = rawText.match(/\{[\s\S]*"answers"\s*:[\s\S]*\}/)
                    if (match) extractedAnswers = JSON.parse(match[0]).answers || []
                } catch(e2) { console.warn("MS Parse Failed", e2) }
            }
            console.log(`Extracted ${extractedAnswers.length} official answers.`)

            // 4. Build Work Queue
            const workQueue: any[] = []
            
            for (const q of questions) {
                // Filter answers for this question
                const qAnswers = extractedAnswers.filter((a: any) => String(a.question_number) === String(q.question_number));

                if (q.type === 'mcq') {
                    // Start with exact match logic, but fall back to the first answer available if no specific subpart logic applies
                    // Usually MCQ has 1 answer per question number
                     const ans = qAnswers[0];
                     if (ans && ans.official_answer && ans.official_answer.length <= 2) { // Sanity check for MCQ letter
                         workQueue.push({
                             type: 'mcq',
                             qId: q.id,
                             question_content: q.content,
                             official_answer: ans.official_answer,
                             marks: ans.marks,
                             existing_ai_answer: q.ai_answer
                         })
                     } else if (ans) {
                         // Maybe it extracted "The answer is B"? Heuristic cleanup?
                         const letter = ans.official_answer.match(/^[A-D]$/i) ? ans.official_answer.toUpperCase() : null;
                         if (letter) {
                             workQueue.push({ type: 'mcq', qId: q.id, question_content: q.content, official_answer: letter, marks: ans.marks, existing_ai_answer: q.ai_answer })
                         }
                     }
                } else {
                    // Structured - Match Blocks
                    const blocks = (q.structure_data || []) as any[];
                    let qModified = false;
                    
                    for (const block of blocks) {
                        if (block.type === 'question_part') {
                            const cleanBlockLabel = (block.label || '').replace(/[^a-z0-9]/gi, '').toLowerCase();
                            // Find match
                            let match = qAnswers.find((a: any) => {
                                const cleanAns = (a.sub_part || '').replace(/[^a-z0-9]/gi, '').toLowerCase();
                                return cleanAns === cleanBlockLabel || cleanAns.endsWith(cleanBlockLabel);
                            });

                            if (match) {
                                block.official_answer = match.official_answer;
                                block.marks = match.marks || block.marks;
                                qModified = true;
                                
                                workQueue.push({
                                    type: 'structured',
                                    qId: q.id, // We group updates later? No, we update blocks in memory and push 'explanation' task
                                    blockReference: block, // Mutate in place
                                    question_content: block.content,
                                    official_answer: match.official_answer
                                })
                            }
                        }
                    }
                    if (qModified) {
                         // We need to save this question eventually
                         // We track it via the 'questions' array references which are being mutated
                    }
                }
            }

            console.log(`Queued ${workQueue.length} AI Tasks.`)

            // 5. Process Queue (Parallel)
            // Limit concurrency
            for (let i = 0; i < workQueue.length; i += CONCURRENCY_LIMIT) {
                const batch = workQueue.slice(i, i + CONCURRENCY_LIMIT);
                await Promise.all(batch.map(async (task) => {
                    const aiPrompt = task.type === 'mcq'
                        ? `Explain why "${task.official_answer}" is correct for: "${task.question_content}". 3 sentences max.`
                        : `Model answer for: "${task.question_content}". Points: "${task.official_answer}". 3 sentences max.`;
                    
                    try {
                         const solRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                                method: 'POST',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify({ contents: [{ parts: [{ text: aiPrompt }] }] })
                            }, 1);
                         
                         if (solRes.ok) {
                             const solJson = await solRes.json();
                             const text = solJson.candidates?.[0]?.content?.parts?.[0]?.text;
                             
                             if (task.type === 'mcq') {
                                 task.ai_solution = text; // Temporary storage
                             } else {
                                 task.blockReference.ai_answer = text;
                             }
                         }
                    } catch (e) { /* Ignore */ }
                }));
            }

            // 6. Save Logic
            const updates = [];
            // Group by Question again
             // For MCQ: update 'official_answer', 'marks', 'ai_answer'
             // For Structured: update 'structure_data'
            
            // Re-iterate questions which now have mutated data or queued tasks completed
            for (const q of questions) {
                if (q.type === 'mcq') {
                     // Find the task if any
                     const task = workQueue.find(t => t.qId === q.id);
                     if (task && (task.official_answer || task.ai_solution)) {
                         updates.push(
                             supabase.from('questions').update({
                                 official_answer: task.official_answer,
                                 marks: task.marks,
                                 ai_answer: { ...q.ai_answer, ai_solution: task.ai_solution }
                             }).eq('id', q.id)
                         );
                     }
                } else {
                    // Check if structure_data changed (we could check if we mutated it)
                    // We can just save all structured questions that had matches?
                    // Optimization: check if any block has official_answer
                    const hasUpdates = (q.structure_data || []).some((b: any) => b.official_answer);
                    if (hasUpdates) {
                         updates.push(
                             supabase.from('questions').update({
                                 structure_data: q.structure_data
                             }).eq('id', q.id)
                         );
                    }
                }
            }

            await Promise.all(updates);
            console.log(`[Success] Updated ${updates.length} questions.`);

        } catch (err) {
            console.error("[Background Error]", err)
        }
    });

    // Invoke Background Task
    // @ts-ignore
    EdgeRuntime.waitUntil(processingPromise)

    return new Response(JSON.stringify({
        success: true,
        message: 'Mark scheme processing started in background',
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500, headers: corsHeaders })
  }
})
