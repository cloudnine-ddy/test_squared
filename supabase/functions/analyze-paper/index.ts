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

         // B. Render Page (PDF.co) with retry
         const renderPayload = {
           url: pdfUrl,
           pages: String(pageIdx),
           async: false
         }
         
         const renderRes = await fetchWithRetry('https://api.pdf.co/v1/pdf/convert/to/png', {
           method: 'POST',
           headers: { 'Content-Type': 'application/json', 'x-api-key': pdfCoApiKey },
           body: JSON.stringify(renderPayload)
         })
         
         if (!renderRes.ok) {
           throw new Error(`PDF.co error: ${renderRes.status}`)
         }
         
         const renderJson = await renderRes.json()
         const imageUrl = renderJson.urls?.[0] || renderJson.url
         
         if (!imageUrl) throw new Error(`Failed to render page ${pageNum}: No URL returned`)

         // C. Download Image with retry
         const imgRes = await fetchWithRetry(imageUrl, {})
         if (!imgRes.ok) throw new Error(`Failed to download rendered image: ${imgRes.status}`)
         
         const imgBuffer = await imgRes.arrayBuffer()
         
         // CRITICAL FIX: Use chunked processing instead of spread operator
         // The spread operator (...array) causes stack overflow on large arrays
         const uint8Array = new Uint8Array(imgBuffer)
         const chunkSize = 8192 // Process 8KB at a time
         let binaryString = ''
         
         for (let i = 0; i < uint8Array.length; i += chunkSize) {
           const chunk = uint8Array.subarray(i, i + chunkSize)
           binaryString += String.fromCharCode.apply(null, Array.from(chunk))
         }
         
         const imgBase64 = btoa(binaryString)

         // D. Analyze with Gemini (has internal JSON error handling + retry)
         const result = await analyzePageImage(imgBase64, pageNum, isObjective, topicsJson, apiKey)
         
         if (result && result.questions) {
           console.log(`[Page ${pageNum}] Found ${result.questions.length} items`)
           const questionsWithPage = result.questions.map((q: RawQuestion) => ({
             ...q,
             _source_page: pageNum,
             _page_dims: pageDims
           }))
           allQuestions.push(...questionsWithPage)
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

      return {
        paper_id: paperId,
        question_number: q.question_number,
        content: q.content,
        topic_ids: validTopics,
        type: q.type,
        options: q.options || null,
        correct_answer: q.correct_answer || null,
        marks: q.marks || null,
        ai_answer: aiAnswer, 
        explanation: explanationData
      }
    })

    if (dbRows.length > 0) {
      const { error: insertError } = await supabase
        .from('questions')
        .insert(dbRows)

      if (insertError) throw insertError
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
  apiKey: string
): Promise<{ page_number: number, questions: RawQuestion[] } | null> {
  
  const prompt = `Analyze this Biology exam page.
1. Ignore non-English text.
2. Identify question numbers.
3. If a question continues from previous page, mark "is_continuation": true.
4. If a diagram/figure exists for a question, provide its bounding box (0-1000 scale, Top-Left origin).
   - Ensure the box covers the ENTIRE figure image tightly.
5. Extract content exactly. Map topics to IDs provided.
6. Provide a short "explanation" for the question if possible (1-2 sentences).

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
        { inline_data: { mime_type: "image/png", data: base64Data } }
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
        existing.content += "\n" + frag.content
      }

      if (frag.marks && !existing.marks) existing.marks = frag.marks
      
      if (!existing.figure && frag.figure) {
         existing.figure = frag.figure;
         (existing as any)._source_page = frag._source_page;
         (existing as any)._page_dims = frag._page_dims;
      }
      
      if (!existing.explanation && frag.explanation) {
          existing.explanation = frag.explanation
      }
      
      if (!existing.topic_ids?.length && frag.topic_ids?.length) {
        existing.topic_ids = frag.topic_ids
      }
    }
  }

  return Array.from(merged.values())
}