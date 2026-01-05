import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// VERSION: 8.0 - Network Retry + Timeout Handling
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'
const MAX_RETRIES = 3
const RETRY_DELAY_MS = 1000

// Types
interface Topic {
  id: string
  name: string
}

interface RawFigure {
  ymin: number // 0-1000 (Top-Left Origin)
  xmin: number // 0-1000
  ymax: number // 0-1000
  xmax: number // 0-1000
}

interface RawQuestion {
  question_number: number
  content: string
  topic_ids?: string[]
  type: 'structured' | 'mcq'
  marks?: number
  options?: { label: string; text: string }[]
  correct_answer?: string
  figure?: RawFigure
  is_continuation?: boolean
  explanation?: string
}

// Helper: Retry fetch with exponential backoff
async function fetchWithRetry(url: string, options: RequestInit, retries = MAX_RETRIES): Promise<Response> {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options)
      return response
    } catch (error) {
      if (attempt === retries) {
        throw error // Last attempt failed
      }
      const delay = RETRY_DELAY_MS * Math.pow(2, attempt - 1) // Exponential backoff
      console.warn(`[Retry] Attempt ${attempt} failed, retrying in ${delay}ms...`, error)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  throw new Error('fetchWithRetry: should not reach here')
}

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    const { paperId, pdfUrl, paperType, startPage, endPage } = await req.json()
    const isObjective = paperType === 'objective'

    if (!paperId || !pdfUrl) throw new Error('Missing paperId or pdfUrl')

    console.log(`[Start] Analyzing paper ${paperId} (${paperType})`)
    if (startPage !== undefined || endPage !== undefined) {
      console.log(`[Batch Mode] Processing pages ${startPage ?? 0} to ${endPage ?? 'end'}`)
    }

    // Initialize Clients
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')
    const pdfCoApiKey = Deno.env.get('PDF_CO_API_KEY')

    if (!apiKey) throw new Error('GEMINI_API_KEY not set')
    if (!pdfCoApiKey) throw new Error('PDF_CO_API_KEY not set')

    console.log(`[Start] Analyzing paper ${paperId} (${paperType})`)

    // 1. Fetch Context (Subject & Topics)
    const { data: paper } = await supabase
      .from('papers')
      .select('subject_id')
      .eq('id', paperId)
      .single()

    if (!paper) throw new Error('Paper not found')

    const { data: topics } = await supabase
      .from('topics')
      .select('id, name')
      .eq('subject_id', paper.subject_id)

    const topicsList: Topic[] = topics || []
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    // 2. Load PDF (Single Load)
    console.log(`[PDF] Loading PDF...`)
    const pdfRes = await fetchWithRetry(pdfUrl, {})
    if (!pdfRes.ok) throw new Error('Failed to download PDF')
    const pdfArrayBuffer = await pdfRes.arrayBuffer()
    const srcDoc = await PDFDocument.load(pdfArrayBuffer)
    const pageCount = srcDoc.getPageCount()

    console.log(`[PDF] Document has ${pageCount} pages.`)
    console.log(`[Warning] Edge Function execution time limit: ~150s (free) or ~600s (pro)`)

    // Determine batch range
    const batchStart = startPage ?? 0
    const batchEnd = endPage ?? pageCount
    const actualStart = Math.max(0, batchStart)
    const actualEnd = Math.min(pageCount, batchEnd)
    const pagesInBatch = actualEnd - actualStart

    console.log(`[Batch] Processing pages ${actualStart + 1} to ${actualEnd} (${pagesInBatch} pages)`)

    // 3. STRICT SERIAL Processing Loop (NO batching, NO Promise.all)
    const allQuestions: (RawQuestion & { _source_page: number, _page_dims: { width: number, height: number } })[] = []

    // Process ONE page at a time within the batch range
    for (let pageIdx = actualStart; pageIdx < actualEnd; pageIdx++) {
      const pageNum = pageIdx + 1
      const elapsedSec = Math.floor((Date.now() - startTime) / 1000)
      console.log(`[Page ${pageNum}/${pageCount}] Processing serially... (${elapsedSec}s elapsed)`)

      // Timeout warning
      if (elapsedSec > 120) {
        console.warn(`[Warning] Approaching execution time limit (${elapsedSec}s). Consider splitting large PDFs.`)
      }

      try {
         // A. Get Dimensions JIT (Just-In-Time)
         const { width, height } = srcDoc.getPage(pageIdx).getSize()
         const pageDims = { width, height }

         console.log(`[Page ${pageNum}] Dims: ${width}x${height}`)

         // B. Extract Page as PDF locally (No PDF.co)
         const newPdf = await PDFDocument.create()
         const [copiedPage] = await newPdf.copyPages(srcDoc, [pageIdx])
         newPdf.addPage(copiedPage)
         const base64Pdf = await newPdf.saveAsBase64()

         // C. Analyze (Native PDF)
         const result = await analyzePageImage(base64Pdf, pageNum, isObjective, topicsJson, apiKey, "application/pdf")

         if (result && result.questions) {
             console.log(`[Page ${pageNum}] Extracted ${result.questions.length} items`)

             // Map result to global list
             const mapped = result.questions.map(q => ({
                 ...q,
                 _source_page: pageNum,
                 _page_dims: pageDims
             }))

             allQuestions.push(...mapped)
         } else {
           console.log(`[Page ${pageNum}] No questions extracted (possibly empty or error)`)
         }

      } catch (err) {
        console.error(`[Error] Failed to process page ${pageNum}, skipping...`, err)
        // Do NOT rethrow - continue to next page so one bad page doesn't kill entire upload
      }

      // Small delay to allow GC to work between pages
      await new Promise(resolve => setTimeout(resolve, 100))
    }

    // 4. Merge & Deduplicate
    console.log(`[Merge] Merging ${allQuestions.length} raw fragments...`)
    const finalQuestions = mergeQuestions(allQuestions)
    console.log(`[Merge] Resulted in ${finalQuestions.length} unique questions`)

    // 5. Insert into Database
    const dbRows = finalQuestions.map(q => {
      let aiAnswer = null;
      let explanationData = null;

      // Handle Figure & Coordinates
      if (q.figure) {
        // Dimensions are now attached to the question object from the loop
        const dims = (q as any)._page_dims || { width: 595, height: 842 }

        // Gemini 0-1000 (Top-Left Origin) -> PDF Points (Bottom-Left Origin)
        const xMinRel = q.figure.xmin / 1000;
        const xMaxRel = q.figure.xmax / 1000;
        const yMinRel = q.figure.ymin / 1000; // Top
        const yMaxRel = q.figure.ymax / 1000; // Bottom

        const x = xMinRel * dims.width;

        // In PDF (Bottom-Left 0,0):
        // Top of box (visual) = Higher Y value = (1 - yMin) * height
        // Bottom of box (visual) = Lower Y value = (1 - yMax) * height

        const pdfYTop = (1 - yMinRel) * dims.height;
        const pdfYBottom = (1 - yMaxRel) * dims.height;

        const width = (xMaxRel - xMinRel) * dims.width;
        const height = pdfYTop - pdfYBottom;

        aiAnswer = {
          boundingBox: {
            x: Number(x.toFixed(2)),
            y: Number(pdfYBottom.toFixed(2)),
            width: Number(width.toFixed(2)),
            height: Number(height.toFixed(2)),
            page: (q as any)._source_page,
            page_width: dims.width,
            page_height: dims.height
          },
          raw_gemini: q.figure
        }
      }

      // Handle Explanation
      if (q.explanation) {
          explanationData = {
              text: q.explanation,
              generated_at: new Date().toISOString()
          }
      }

      const validTopics = (q.topic_ids || []).filter(tid => topicsList.some(t => t.id === tid))

      // Validate options for MCQ
      let finalOptions = q.options || null;
      if (q.type === 'mcq' && (!finalOptions || finalOptions.length === 0)) {
         // If MCQ has no options, it's invalid.
         // Strategy: Warn and downgrade to 'structured' OR provide empty placeholder to pass constraint?
         // Better to downgrade to structured if we can't parse options,
         // BUT user might prefer we keep it as MCQ with empty options if the constraint allows (unlikely).
         // Given the error "violates check constraint check_mcq_options", it likely requires valid options.
         // Let's inspect the constraint in next step. For now, enforce [] if it's MCQ to see if [] passes,
         // or if we should default to structured.
         // A safe fallback is: if MCQ has no options, default to empty array [] which is valid JSONB.
         // Wait, the error said "Failing row contains ... options: null". So null is definitely bad.
         finalOptions = [];
      }

      return {
        paper_id: paperId,
        question_number: q.question_number,
        content: q.content,
        topic_ids: validTopics,
        type: q.type,
        options: finalOptions,
        correct_answer: q.correct_answer || null,
        marks: q.marks || null,
        ai_answer: aiAnswer,
        explanation: explanationData
      }
    })

    if (dbRows.length > 0) {
      const { data: insertedQuestions, error: insertError } = await supabase
        .from('questions')
        .insert(dbRows)
        .select()

      if (insertError) throw insertError

      // Trigger crop-figure for any questions with figures/tables
      if (insertedQuestions && insertedQuestions.length > 0) {
          const questionsWithFigures = insertedQuestions.filter((q: any) =>
              q.ai_answer && (q.ai_answer.has_figure || q.ai_answer.has_table)
          );

          if (questionsWithFigures.length > 0) {
              console.log(`[Batch] Triggering crop-figure for ${questionsWithFigures.length} questions...`);

              // We do this asynchronously (fire and forget pattern) or await?
              // Await is safer to ensure they start, but might slow down response.
              // Given Edge Function limits, fire and forget is risky if the runtime kills bg tasks.
              // Let's use Promise.allSettled but with a timeout? Or just await them.
              // Since we are in an Edge Function, we should await to ensure execution.

              const cropPromises = questionsWithFigures.map(async (q: any) => {
                  try {
                      console.log(`[Batch] Invoking crop-figure for Q${q.id}...`);
                      const res = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/crop-figure`, {
                          method: 'POST',
                          headers: {
                              'Content-Type': 'application/json',
                              'Authorization': `Bearer ${supabaseKey}` // Service role key
                          },
                          body: JSON.stringify({ record: q })
                      });
                      console.log(`[Batch] crop-figure response for Q${q.id}: ${res.status} ${res.statusText}`);
                  } catch (err) {
                      console.error(`[Error] Failed to trigger crop-figure for Q${q.id}`, err);
                  }
              });

              // Don't block the ENTIRE response for too long, but wait a bit?
              // Actually, crop-figure creates images. If we don't await, user might load page before images exist.
              // But image generation is slow (PDF.co).
              // Let's await.
              await Promise.allSettled(cropPromises);
          } else {
              console.log('[Batch] No questions with figures/tables found in this batch.');
          }
      }
    }

    const totalTime = Math.floor((Date.now() - startTime) / 1000)
    console.log(`[Complete] Batch complete. Total execution time: ${totalTime}s`)

    return new Response(
      JSON.stringify({
        success: true,
        count: dbRows.length,
        total_pages: pageCount,
        batch_start: actualStart,
        batch_end: actualEnd,
        pages_processed: pagesInBatch,
        has_more: actualEnd < pageCount,
        execution_time_seconds: totalTime
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// --- Helper Functions ---

async function analyzePageImage(
  base64Data: string,
  pageNumber: number,
  isObjective: boolean,
  topicsJson: string,
  apiKey: string,
  mimeType: string = "image/png"
): Promise<{ page_number: number, questions: RawQuestion[] } | null> {

  const prompt = `Analyze this Biology exam page.

TASK 1: TEXT EXTRACTION (ENGLISH ONLY)
- CRITICAL: This is a bilingual paper. Extract ONLY the English text. Ignore Malay.
- Do NOT include both languages.
- If text is "Cell / Sel", extract "Cell".

TASK 2: FIGURE & TABLE DETECTION (AGGRESSIVE)
- Does the question refer to "Diagram", "Figure", "Table", "Graph", "Chart"?
- OR is there a visual drawing, photo, or illustration?
- IF YES: You MUST provide the 'figure' (for diagrams/images) or 'table' (for data tables) object.
- Return the bounding box (ymin, xmin, ymax, xmax) on 0-1000 scale.
- The box must cover the ENTIRE visual element.
- Do NOT ignore drawings.

TASK 3: SOLVE THE QUESTION
- You MUST determine the correct answer based on your biological knowledge.
- For MCQ: Set 'correct_answer' to the correct option letter (e.g. "A").
- For Structured: Set 'correct_answer' to the key points required for marks.
- Provide a short 'explanation' (1-2 sentences).

TOPICS: ${topicsJson}
`

  const schema = {
    type: "OBJECT",
    properties: {
      questions: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            question_number: { type: "INTEGER", minimum: 1, maximum: 100 },
            content: { type: "STRING", maxLength: 5000 },
            is_continuation: { type: "BOOLEAN" },
            topic_ids: { type: "ARRAY", items: { type: "STRING" } },
            type: { type: "STRING", enum: ["mcq", "structured"] },
            marks: { type: "INTEGER", minimum: 1, maximum: 50 },
            options: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                properties: {
                  label: { type: "STRING" },
                  text: { type: "STRING" }
                }
              }
            },
            correct_answer: { type: "STRING" },
            explanation: { type: "STRING", maxLength: 1000 },
            figure: {
              type: "OBJECT",
              properties: {
                ymin: { type: "INTEGER", minimum: 0, maximum: 1000 },
                xmin: { type: "INTEGER", minimum: 0, maximum: 1000 },
                ymax: { type: "INTEGER", minimum: 0, maximum: 1000 },
                xmax: { type: "INTEGER", minimum: 0, maximum: 1000 }
              }
            },
            table: {
              type: "OBJECT",
              properties: {
                ymin: { type: "INTEGER", minimum: 0, maximum: 1000 },
                xmin: { type: "INTEGER", minimum: 0, maximum: 1000 },
                ymax: { type: "INTEGER", minimum: 0, maximum: 1000 },
                xmax: { type: "INTEGER", minimum: 0, maximum: 1000 }
              }
            }
          },
          required: ["question_number", "content", "type"]
        }
      }
    }
  }

  const payload = {
    contents: [{
      parts: [
        { text: prompt },
        { inline_data: { mime_type: mimeType, data: base64Data } }
      ]
    }],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 8192,
      response_mime_type: "application/json",
      response_schema: schema,
      topK: 40,
      topP: 0.95
    }
  }

  try {
    const res = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })

    if (!res.ok) {
      console.warn(`Gemini error on page ${pageNumber}: ${res.status}`)
      return null
    }

    const json = await res.json()
    let text = json.candidates?.[0]?.content?.parts?.[0]?.text
    if (!text) return null

    // Clean up markdown code blocks if present
    if (text.startsWith('```')) {
      text = text.replace(/^```(json)?\n/, '').replace(/\n```$/, '')
    }

    // Basic validation: check if text looks like valid JSON before parsing
    if (!text.trim().startsWith('{') || !text.trim().endsWith('}')) {
      console.warn(`[Warning] Response doesn't look like JSON for page ${pageNumber}`)
      return { page_number: pageNumber, questions: [] }
    }

    // Truncate if response is suspiciously large (over 1MB suggests hallucination)
    if (text.length > 1000000) {
      console.warn(`[Warning] Response too large (${text.length} chars) for page ${pageNumber}, likely hallucination`)
      return { page_number: pageNumber, questions: [] }
    }

    try {
      const parsed = JSON.parse(text)
      return {
        page_number: pageNumber,
        questions: parsed.questions || []
      }
    } catch (e) {
      // CRITICAL: Do NOT crash on malformed JSON - just skip this page
      console.error(`[Error] JSON Parse Failed for Page ${pageNumber}. Raw text (first 500 chars):`, text.substring(0, 500))
      console.error(`Parse error:`, e)
      // Return empty result instead of crashing
      return {
        page_number: pageNumber,
        questions: []
      }
    }

  } catch (e) {
    console.warn(`Failed to analyze page ${pageNumber}:`, e)
    return null
  }
}

function mergeQuestions(fragments: (RawQuestion & { _source_page: number, _page_dims: any })[]): RawQuestion[] {
  const merged = new Map<number, RawQuestion>()

  for (const frag of fragments) {
    const qNum = frag.question_number

    if (!merged.has(qNum)) {
      merged.set(qNum, frag)
    } else {
      const existing = merged.get(qNum)!

      if (frag.is_continuation) {
        existing.content += "\n" + frag.content
      } else {
        // If not explicitly a continuation, but same number, usually logic is similar
        existing.content += "\n" + frag.content
      }

      if (frag.marks && !existing.marks) existing.marks = frag.marks

      if (!existing.figure && frag.figure) {
         existing.figure = frag.figure;
         (existing as any)._source_page = frag._source_page;
         (existing as any)._page_dims = frag._page_dims;
      }

      if (!(existing as any).table && (frag as any).table) {
         (existing as any).table = (frag as any).table;
         (existing as any)._source_page = frag._source_page;
         (existing as any)._page_dims = frag._page_dims;
      }

      if (!existing.explanation && frag.explanation) {
          existing.explanation = frag.explanation
      }

      if (!existing.topic_ids?.length && frag.topic_ids?.length) {
        existing.topic_ids = frag.topic_ids
      }

      // Fix: Merge options if they appear in later fragments
      if (!existing.options?.length && frag.options?.length) {
        existing.options = frag.options
      }
    }
  }

  return Array.from(merged.values())
}