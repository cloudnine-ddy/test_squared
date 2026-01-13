import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// Edge Function for processing structured questions from PDFs - BATCHED VERSION + CROP FIGURES
// Extracts multi-part questions, creates JSONB block structure, and detects/crops figures
// Version 1.1: Added figure cropping integration

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'
const MAX_RETRIES = 3

interface StructuredQuestionResponse {
  question_number: number
  blocks: Array<{
    type: 'text' | 'figure' | 'question_part'
    content?: string
    url?: string
    figure_label?: string
    description?: string
    label?: string
    input_type?: string
    correct_answer?: any
    official_answer?: string
    ai_answer?: string
    marks?: number
    page?: number
    bbox?: { x: number, y: number, width: number, height: number } // Added bbox details
  }>
  topic_ids: string[]
  total_marks: number
}

// Retry helper
async function fetchWithRetry(url: string, options: RequestInit, retries = MAX_RETRIES): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options)
      if (response.ok) return response
      if (i < retries - 1) {
        console.warn(`Attempt ${i + 1} failed, retrying in ${Math.pow(2, i) * 1000}ms...`)
        await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
      } else {
        return response
      }
    } catch (e) {
      if (i === retries - 1) throw e
      console.warn(`Attempt ${i + 1} error: ${e}, retrying...`)
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
    }
  }
  throw new Error('Max retries exceeded')
}

// Helper: Clean JSON string aggressively
function cleanJsonString(input: string): string {
  // 1. Remove markdown code blocks
  let cleaned = input.replace(/```json/g, '').replace(/```/g, '').trim();

  // 2. Remove non-printable control characters (ASCII 0-31) except newline, tab, carriage return
  cleaned = cleaned.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');

  // 3. Fix localized quotes
  cleaned = cleaned.replace(/[\u201C\u201D]/g, '"');

  return cleaned;
}

/**
 * Makes question part labels globally unique by adding a counter suffix.
 * Example: First (i) stays (i), second (i) becomes (i)_1, third becomes (i)_2
 */
function makeLabelsUnique(blocks: any[]): any[] {
  const labelCounts = new Map<string, number>();

  return blocks.map(block => {
    if (block.type === 'question_part' && block.label) {
      const label = block.label;
      const count = labelCounts.get(label) || 0;
      labelCounts.set(label, count + 1);

      // If this is a duplicate (count > 0), add suffix
      if (count > 0) {
        console.log(`  🔄 Deduplicating label "${label}" -> "${label}_${count}"`);
        return {
          ...block,
          label: `${label}_${count}`
        };
      }
    }
    return block;
  });
}

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  let pdfUrl = ''; // Define early for error logging context

  try {
    const { paperId, pdfUrl: inputPdfUrl, startPage, endPage } = await req.json()
    pdfUrl = inputPdfUrl;

    if (!paperId || !pdfUrl) {
      return new Response(
        JSON.stringify({ error: 'Missing paperId or pdfUrl' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY not configured' }),
        { status: 500, headers: corsHeaders }
      )
    }

    // Get paper details and subject
    const { data: paper, error: paperError } = await supabase
      .from('papers')
      .select('subject_id, subjects(name)')
      .eq('id', paperId)
      .single()

    if (paperError || !paper) {
      return new Response(
        JSON.stringify({ error: 'Paper not found' }),
        { status: 404, headers: corsHeaders }
      )
    }

    const subjectName = (paper as any).subjects?.name || 'Subject'
    console.log(`Processing structured questions for ${subjectName} (Pages ${startPage ?? 'All'} to ${endPage ?? 'All'})`)

    // Fetch topics
    const { data: topics } = await supabase
      .from('topics')
      .select('id, name')
      .eq('subject_id', paper.subject_id)

    const topicsList = topics || []
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    // Download PDF
    console.log(`Downloading PDF...`)
    const pdfResponse = await fetch(pdfUrl)
    if (!pdfResponse.ok) throw new Error('Failed to download PDF');

    const pdfArrayBuffer = await pdfResponse.arrayBuffer()
    const srcDoc = await PDFDocument.load(pdfArrayBuffer)
    const totalPdfPages = srcDoc.getPageCount()

    // Handle Batching Logic
    let subDoc = srcDoc;
    let actualStartPage = 0; // Relative offset 0-based

    if (typeof startPage === 'number' && typeof endPage === 'number') {
      const safeStart = Math.max(0, startPage);
      const safeEnd = Math.min(totalPdfPages, endPage);
      actualStartPage = safeStart; // Remember this to offset page numbers later

      console.log(`Creating batch PDF from page ${safeStart} to ${safeEnd}...`)
      subDoc = await PDFDocument.create();

      const pageIndices = [];
      for(let i = safeStart; i < safeEnd; i++) {
        pageIndices.push(i);
      }

      if (pageIndices.length > 0) {
        const copiedPages = await subDoc.copyPages(srcDoc, pageIndices);
        copiedPages.forEach(p => subDoc.addPage(p));
      } else {
         return new Response(JSON.stringify({ success: true, message: 'Skipping empty batch range', questions_created: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
      }
    }

    const pdfBytes = await subDoc.save()
    function toBase64(u8: Uint8Array) {
      let b = ''
      const l = u8.length
      for (let i = 0; i < l; i += 32768) {
        b += String.fromCharCode(...u8.subarray(i, i + 32768))
      }
      return btoa(b)
    }
    const pdfBase64 = toBase64(new Uint8Array(pdfBytes))

    // Gemini prompt with BBOX REQUEST and AI ANSWER GENERATION
    const prompt = `You are a ${subjectName} exam analyzer extracting STRUCTURED QUESTIONS from this specific batch of pages.
CRITICAL: Process the exam paper sequentially. EXTRACT FIGURES and diagrams carefully.

OUTPUT FORMAT: Strict JSON Object containing a "questions" array.
Each question object must represent the full question flow as an ordered list of "blocks".

BLOCK TYPES:
1. "text": For introduction text or context (e.g., "(b) A new species was introduced..." with 0 marks).
2. "figure": For diagrams, graphs, charts.
   - "figure_label": "Figure 1", "Figure 2.1"
   - "description": VERY BRIEF description of visual (Max 15 words).
   - "page": Relative page number in this batch (1-based index).
   - "bbox": Estimate bounding box coordinates as PERCENTAGES [x, y, width, height]. Example: {"x": 10, "y": 20, "width": 80, "height": 40}.
   - HEURISTIC: Figures are almost always located IMMEDIATELY ABOVE their label (e.g., "Fig. 1.1"). Look for the label, then define the bbox for the visual area above it. Exclude the label from the bbox if possible.
3. "question_part": For actual questions that require answers (a, b, i, ii).
   - "label": CRITICAL - Use HIERARCHICAL labels that match mark schemes:
     * For main parts: "(a)", "(b)", "(c)"
     * For sub-parts: "(a)(i)", "(a)(ii)", "(b)(i)", "(b)(ii)"
     * For sub-sub-parts: "(a)(i)(1)", "(a)(i)(2)"
     * NEVER use just "(i)" or "(ii)" alone - ALWAYS prepend the parent part letter
   - "content": Question text.
   - "marks": Number of marks (MUST be > 0 for question_part).
   - "ai_answer": GENERATE a concise, accurate answer based on the question and mark scheme if visible.

CRITICAL RULE FOR 0-MARK PARTS:
- If you see a part like "(b)" that is just introductory text with 0 marks (e.g., "A new species was introduced to an ecosystem."), treat it as a "text" block, NOT a "question_part".
- Only create "question_part" blocks for parts that have marks > 0 and require an answer.

EXAMPLE JSON OUTPUT:
{
  "questions": [
    {
      "question_number": 1,
      "blocks": [
        { "type": "text", "content": "A system consists of two blocks. (Summarized)" },
        { "type": "figure", "figure_label": "Figure 1.1", "description": "Blocks on ramp", "page": 1, "bbox": {"x": 10, "y": 20, "width": 80, "height": 30} },
        { "type": "text", "content": "(b) A new species was introduced to an ecosystem." },
        { "type": "figure", "figure_label": "Fig. 1.2", "description": "Population growth graph", "page": 1, "bbox": {"x": 10, "y": 55, "width": 80, "height": 25} },
        { "type": "question_part", "label": "(b)(i)", "content": "Complete the sentence to describe the term population.", "marks": 1, "ai_answer": "A population is a group of organisms of one species living in the same area at the same time." },
        { "type": "question_part", "label": "(b)(ii)", "content": "Describe and explain the reasons for the shape of the graph at X.", "marks": 3, "ai_answer": "The graph shows exponential growth initially, then levels off as the population reaches carrying capacity due to limited resources." }
      ],
      "topic_ids": ["topic-uuid"],
      "total_marks": 4
    }
  ]
}

TOPICS AVAILABLE: ${topicsJson}

RULES:
1. EXTRACT ALL structured questions found in this batch.
2. PRESERVE ORDER.
3. For "figure": MUST include "page" and "bbox" (percentages). Use the "Above Label" heuristic. Keep descriptions SHORT.
4. Scan for question numbers (1, 2, 3...). If a question starts in this batch, extract it.
5. IGNORE: Page numbers, "Turn over", copyright, barcodes.
6. Group all parts (a, b, i, ii) under their parent Question Number.
7. CRITICAL: Keep JSON output valid and within token limits.
8. SUMMARIZE long "text" blocks. Do not copy entire reading passages word-for-word if they exceed 50 words. Just give the gist.
9. GENERATE ai_answers for ALL question_part blocks. Make them concise and accurate.
10. CRITICAL: ONLY extract questions that are ACTUALLY PRESENT in these pages. Do NOT hallucinate or invent question numbers.
11. If a question is split across pages (starts in this batch but continues beyond), still extract it with the parts visible in this batch.
12. LABEL FORMAT: When you see "1 (a) (i)" in the paper, extract label as "(a)(i)". When you see "1 (b) (ii)", extract as "(b)(ii)". ALWAYS include parent context.
13. 0-MARK PARTS: If a part has 0 marks or is just context/introduction, use "text" block type, NOT "question_part".

Extract ALL structured questions from this batch.`;

    // Call Gemini
    console.log('Calling Gemini...')
    const geminiRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: 'application/pdf', data: pdfBase64 } }
          ]
        }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 16384,
          responseMimeType: 'application/json'
        }
      })
    })

    if (!geminiRes.ok) throw new Error(`Gemini API error: ${await geminiRes.text()}`)

    const geminiJson = await geminiRes.json()
    let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || '{}'
    rawText = cleanJsonString(rawText);

    let parsedData: any = {}
    try {
      parsedData = JSON.parse(rawText)
    } catch (e) {
      console.warn('First JSON parse failed, attempting repair:', e)

      // REPAIR STRATEGY:
      // 1. Double-escape backslashes that might be single
      // 2. Escape unescaped newlines/tabs inside strings

      let repaired = rawText;

      // Naive repair for unescaped newlines inside double quotes
      // We assume strings don't contain \" yet for simplicity of this heuristic regex
      repaired = repaired.replace(/(".*?")/gs, (match) => {
          // Inside a string, replace literal line breaks with \n
          return match.replace(/\r?\n/g, '\\n').replace(/\t/g, '\\t');
      });

      try {
        parsedData = JSON.parse(repaired)
        console.log('JSON repair successful')
      } catch (e2) {
        console.error('Failed to parse Gemini response after repair:', e2)
        // Check for truncation
        if (rawText.length > 50000) {
             console.error('Possible truncation detected (Output length: ' + rawText.length + ')');
        }
        return new Response(JSON.stringify({ error: 'Failed to parse AI response (Invalid JSON from model)', raw_length: rawText.length }), { status: 500, headers: corsHeaders })
      }
    }

    const rawQuestions = parsedData.questions || []

    // Deduplicate questions by MERGING blocks for the same question_number
    const uniqueQuestionsMap = new Map();
    rawQuestions.forEach((q: StructuredQuestionResponse) => {
        if (!uniqueQuestionsMap.has(q.question_number)) {
            uniqueQuestionsMap.set(q.question_number, q);
        } else {
            // MERGE Logic: Append blocks from the duplicate to the existing question
            const existing = uniqueQuestionsMap.get(q.question_number);
            if (q.blocks && existing.blocks) {
                existing.blocks.push(...q.blocks);
            }
            // Update output fields if present in the new chunk
            if (q.total_marks > existing.total_marks) existing.total_marks = q.total_marks;

            console.log(`Merged duplicate Question ${q.question_number} (Added ${q.blocks?.length || 0} blocks).`);
        }
    });
    const questions = Array.from(uniqueQuestionsMap.values());

    // Enhanced logging
    const questionNumbers = questions.map(q => q.question_number).sort((a, b) => a - b);
    console.log(`📊 Batch Summary: Extracted ${questions.length} unique questions from batch (Raw: ${rawQuestions.length})`);
    console.log(`📋 Question Numbers: [${questionNumbers.join(', ')}]`);

    if (questions.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No questions found', questions_created: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Insert questions first to get IDs
    const questionsToInsert = questions.map((q: StructuredQuestionResponse) => {
      // Fixup page numbers in blocks (add batch offset)
      if (q.blocks) {
        q.blocks.forEach(b => {
          if (b.type === 'figure' && b.page) {
             // Gemini returns 1-based relative page.
             // If batch starts at 0 (page 1), and Gemini says page 1 -> correct is 1.
             // If batch starts at 10 (page 11), Gemini says page 1 -> correct is 11.
             // So: offset + relative_page.
             // But wait, crop-figure expects 1-based absolute page number.
             // actualStartPage is 0-based index. So page 11 is index 10.
             // absolute_page = (actualStartPage + 1) + (relative_page - 1)
             // simplified: actualStartPage + relative_page.
             b.page = actualStartPage + b.page;
          }
        });
      }

      const textBlocks = q.blocks.filter(b => b.type === 'text')
      const contentSummary = textBlocks.length > 0
        ? textBlocks.map(b => b.content).join(' ').substring(0, 200)
        : `Structured Question ${q.question_number}`

      // Calculate total marks from parts
      let calculatedMarks = 0;
      if (q.blocks) {
        q.blocks.forEach(b => {
          if (b.type === 'question_part' && typeof b.marks === 'number') {
            calculatedMarks += b.marks;
          }
        });
      }
      const finalMarks = calculatedMarks > 0 ? calculatedMarks : (q.total_marks || 1);

      return {
        paper_id: paperId,
        question_number: q.question_number,
        type: 'structured',
        content: contentSummary,
        structure_data: q.blocks,
        topic_ids: q.topic_ids || [],
        marks: finalMarks,
        official_answer: '',
        ai_answer: null
      }
    })

    // Native Upsert - Constraint Exists!
    // The previous error "duplicate key value violates unique constraint" CONFIRMS the constraint exists.
    // So we can safely use .upsert() now.

    const { data: insertedQuestions, error: insertError } = await supabase
      .from('questions')
      .upsert(questionsToInsert, { onConflict: 'paper_id, question_number' })
      .select('id, question_number, structure_data');

    if (insertError) throw insertError
    if (!insertedQuestions) throw new Error('Insert returned no data');

    console.log(`Successfully inserted ${insertedQuestions.length} questions. Checking for figures to crop...`);

    // Figure Cropping Phase
    let figsCropped = 0;

    for (const q of insertedQuestions) {
        const structureData = q.structure_data as any[];
        if (!Array.isArray(structureData)) continue;

        let modified = false;
        let firstImageUrl: string | null = null; // Track first image for image_url field

        // Apply label deduplication
        q.structure_data = makeLabelsUnique(structureData);

        for (const block of q.structure_data) { // Iterate over potentially modified structureData
            if (block.type === 'figure' && block.bbox) {
                // Call crop-figure Edge Function
                // URL: ${supabaseUrl}/functions/v1/crop-figure
                console.log(`Cropping figure for Q${q.question_number}, Page ${block.page}...`);
                try {
                     const cropRes = await fetchWithRetry(`${supabaseUrl}/functions/v1/crop-figure`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${supabaseKey}`,
                            'apikey': supabaseKey
                        },
                        body: JSON.stringify({
                            pdfUrl,
                            questionId: q.id,
                            page: block.page,
                            bbox: block.bbox // {x, y, width, height}
                        })
                    });

                    if (cropRes.ok) {
                        const cropJson = await cropRes.json();
                        if (cropJson.image_url) {
                            block.url = cropJson.image_url; // Update URL in the block
                            if (!firstImageUrl) firstImageUrl = cropJson.image_url; // Store first image
                            modified = true;
                            figsCropped++;
                        }
                    } else {
                        console.warn(`Crop failed for Q${q.question_number}: ${await cropRes.text()}`);
                    }
                } catch (e) {
                    console.warn(`Crop exception Q${q.question_number}: ${e}`);
                }
            }
        }

        // Update DB with both structure_data and image_url field
        if (modified) {
            await supabase.from('questions')
                .update({
                    structure_data: structureData, // Save updated blocks with URLs
                    image_url: firstImageUrl // Also populate image_url for UI compatibility
                })
                .eq('id', q.id);
        }
    }

    console.log(`Cropped ${figsCropped} figures.`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Extracted ${insertedQuestions.length} questions, cropped ${figsCropped} figures`,
        questions_created: insertedQuestions.length,
        question_ids: insertedQuestions.map(q => q.id),
        total_pages: totalPdfPages // Critical for client loop
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Fatal error:', error)
    return new Response(
      JSON.stringify({
        error: 'Unexpected error',
        details: String(error)
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
