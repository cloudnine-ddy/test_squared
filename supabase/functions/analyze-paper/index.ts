import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// VERSION: 9.0 - UNIFIED PROCESSING (MCQ + Structured get same treatment)
// Improvements:
// - Batch overlap (1 page) for cross-page questions
// - Dynamic subject prompts
// - Retry mechanism (3 attempts)
// - Parallel mark scheme processing
// - Both MCQ and Structured get: crop, answers, AI solution

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent'
const BATCH_SIZE = 5 // Reduced from 10 to avoid token limits & timeouts
const BATCH_OVERLAP = 1 // Overlap 1 page between batches
const MAX_RETRIES = 3
const PARALLEL_BATCH_SIZE = 5 // For mark scheme processing

// Types for structured data
interface Topic {
  id: string
  name: string
}

// Compact Response Interface
type CompactQuestion = [
    number,             // 0: question_number
    string,             // 1: content
    string[],           // 2: topic_ids
    string,             // 3: type ("mcq" | "structured")
    number,             // 4: marks
    [string, string][], // 5: options [[label, text], ...] OR null
    string,             // 6: correct_answer
    string,             // 7: ai_rational (Solution explanation)
    string,             // 8: layout_scan
    string,             // 9: figure_description
    [number, number, number, number, number] | null // 10: figure [pg, x, y, w, h]
]

interface CompactResponse {
    d: CompactQuestion[]
}

// Retry helper with exponential backoff
async function fetchWithRetry(url: string, options: RequestInit, retries = MAX_RETRIES): Promise<Response> {
  for (let i = 0; i < retries; i++) {
    try {
      const response = await fetch(url, options)
      if (response.ok) return response
      // If not ok, throw to trigger retry
      if (i < retries - 1) {
        console.warn(`Attempt ${i + 1} failed, retrying in ${Math.pow(2, i) * 1000}ms...`)
        await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
      } else {
        return response // Last attempt, return whatever we got
      }
    } catch (e) {
      if (i === retries - 1) throw e
      console.warn(`Attempt ${i + 1} error: ${e}, retrying...`)
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

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { paperId, pdfUrl, markSchemeUrl, paperType, startPage, endPage } = await req.json()
    const isObjective = paperType === 'objective'

    console.log(`[V9.0] Paper type: "${paperType}", MCQ=${isObjective}`)

    if (!paperId || !pdfUrl) {
      return new Response(JSON.stringify({ error: 'Missing paperId or pdfUrl' }), { status: 400, headers: corsHeaders })
    }

    const hasMarkScheme = !!markSchemeUrl

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) return new Response(JSON.stringify({ error: 'GEMINI_API_KEY not configured' }), { status: 500, headers: corsHeaders })

    // Step 1: Get paper details + SUBJECT NAME
    const { data: paper, error: paperError } = await supabase
      .from('papers')
      .select('subject_id, subjects(name)')
      .eq('id', paperId)
      .single()
    if (paperError || !paper) return new Response(JSON.stringify({ error: 'Paper not found' }), { status: 404, headers: corsHeaders })

    const subjectName = (paper as any).subjects?.name || 'Biology'
    console.log(`Subject: ${subjectName}`)

    // Step 2: Fetch topics
    const { data: topics } = await supabase.from('topics').select('id, name').eq('subject_id', paper.subject_id)
    const topicsList: Topic[] = topics || []
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    // Step 3: Download PDF & Prepare Batches with OVERLAP
    console.log(`Downloading PDF: ${pdfUrl}`)
    const pdfResponse = await fetch(pdfUrl)
    if (!pdfResponse.ok) return new Response(JSON.stringify({ error: 'Failed to download PDF' }), { status: 500, headers: corsHeaders })
    const pdfArrayBuffer = await pdfResponse.arrayBuffer()

    const srcDoc = await PDFDocument.load(pdfArrayBuffer)
    const totalPages = srcDoc.getPageCount()
    console.log(`Total Pages: ${totalPages}`)

    let allQuestions: CompactQuestion[] = []

    // Helper to process a specific range of pages
    const processBatch = async (batchStartIdx: number, batchEndIdx: number) => {
        const startPageDisplay = batchStartIdx + 1
        const endPageDisplay = batchEndIdx // Exclusive index effectively becomes inclusive page num if 0-based start, wait: 0-based index 5 is Page 6. 
        // Logic: Indices [0, 1, 2] -> Pages 1, 2, 3.
        // Client sends start=0, end=6. Indices: 0, 1, 2, 3, 4, 5.
        
        console.log(`Processing Batch: Pages ${startPageDisplay}-${batchEndIdx}...`)

        // Create Sub-PDF
        const subDoc = await PDFDocument.create()
        const pageIndices = []
        for (let j = batchStartIdx; j < batchEndIdx; j++) {
            if (j < totalPages) pageIndices.push(j)
        }

        if (pageIndices.length === 0) return

        const copiedPages = await subDoc.copyPages(srcDoc, pageIndices)
        copiedPages.forEach(p => subDoc.addPage(p))
        const subPdfBytes = await subDoc.saveAsBase64()

        // DYNAMIC SUBJECT-BASED PROMPT
        const prompt = isObjective
          ? `You are a ${subjectName} MCQ exam analyzer (Batch pages ${startPageDisplay}-${batchEndIdx}).
CRITICAL: Any question mentioning "diagram", "figure", "shows", "below" = HAS FIGURE. Estimate figure bounding box.
OUTPUT JSON (COMPACT ARRAY):
{ "d": [ [1, "Content", ["topic-uuid"], "mcq", 1, [["A","Option A text"]], "B", "Explanation why B is correct", "Layout notes", "Figure description", [1,20,30,50,40]] ] }
TOPICS: ${topicsJson}
RULES:
1. Extract ALL questions from these pages
2. Use compact array format strictly
3. SOLVE each question - provide correct answer (index 6) and explanation (index 7)
4. Figure coordinates are PERCENTAGES relative to page. [page, x%, y%, width%, height%]
5. For questions WITHOUT figures, use null for index 10`
          : `You are a ${subjectName} structured question analyzer (Batch pages ${startPageDisplay}-${batchEndIdx}).
CRITICAL: Any question with diagrams, graphs, tables = HAS FIGURE. Estimate bounding box.
OUTPUT JSON (COMPACT ARRAY):
{ "d": [ [1, "Full question text", ["topic-uuid"], "structured", 6, null, null, "Key points for answer", "Layout notes", "Figure description", [1,20,30,50,40]] ] }
TOPICS: ${topicsJson}
RULES:
1. Extract ALL structured questions.
2. COMPACT ARRAY FORMAT ONLY.
3. Index 7: Key answer points.
4. Fig coords: [page, x%, y%, w%, h%]. No fig? null.
5. Content: QUESTION TEXT ONLY. Ignore dots/empty lines/turn over/copyright.
6. Sub-parts (a,b,c) must be in content.
7. CRITICAL: Do NOT output markdown. Do NOT truncate JSON.`

        // Gemini Call with RETRY
        try {
            const geminiRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: "application/pdf", data: subPdfBytes } }] }],
                    generationConfig: { temperature: 0.1, maxOutputTokens: 16384, responseMimeType: "application/json" }
                })
            })

            if (!geminiRes.ok) throw new Error(`Gemini Error: ${await geminiRes.text()}`)
            const geminiJson = await geminiRes.json()
            let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || ''
            if (rawText.includes('```')) rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()

            // ROBUST JSON EXTRACTION & REPAIR
            let rawData: any = {}
            try {
                rawData = JSON.parse(rawText)
            } catch(e) {
                try {
                    const jsonMatch = rawText.match(/\{[\s\S]*"d"\s*:[\s\S]*\}/)
                    if (jsonMatch) rawData = JSON.parse(jsonMatch[0])
                    else throw new Error("No JSON block found")
                } catch (err2) {
                    console.warn(`Batch parse fail, attempting aggressive repair.`)
                    function balanceJSON(jsonStr: string): string { 
                        let stack = [];
                        let inString = false;
                        let escaped = false;
                        for (let i = 0; i < jsonStr.length; i++) {
                            const char = jsonStr[i];
                            if (!inString && (char === '{' || char === '[')) stack.push(char);
                            else if (!inString && char === '}' && stack[stack.length - 1] === '{') stack.pop();
                            else if (!inString && char === ']' && stack[stack.length - 1] === '[') stack.pop();
                            else if (char === '"' && !escaped) inString = !inString;
                            escaped = (char === '\\' && !escaped);
                        }
                        while (stack.length > 0) {
                            const last = stack.pop();
                            if (last === '{') jsonStr += '}';
                            if (last === '[') jsonStr += ']';
                        }
                        return jsonStr;
                    }
                    let repaired = rawText.trim();
                    try {
                        rawData = JSON.parse(balanceJSON(repaired))
                    } catch (e3) {
                         const lastClosing = Math.max(repaired.lastIndexOf('}'), repaired.lastIndexOf(']'));
                         if (lastClosing > 10) {
                             try { rawData = JSON.parse(repaired.substring(0, lastClosing + 1)); } catch(e4) {}
                         }
                    }
                }
            }

            const batchQs = (rawData.d || rawData.questions || (Array.isArray(rawData) ? rawData : [])) as CompactQuestion[]
            if (batchQs.length) {
                console.log(`Batch ${startPageDisplay}-${batchEndIdx}: Extracted ${batchQs.length} questions`)

                const offsetQs = batchQs
                    .filter(q => Array.isArray(q))
                    .map(q => {
                       const newQ: CompactQuestion = [...q]
                       if (Array.isArray(newQ[10]) && newQ[10].length >= 1) {
                            // Adjust relative to batch start
                            newQ[10][0] = newQ[10][0] + (startPageDisplay - 1)
                       }
                       return newQ
                    }) as CompactQuestion[]

                allQuestions = [...allQuestions, ...offsetQs]
            }
        } catch (batchErr) {
            console.error(`Error processing batch:`, batchErr)
        }
    }

    // MAIN EXECUTION LOGIC
    // Check if client provided specific batch range (req.body.startPage / endPage)
    // Note: Request json was parsed into { ... startPage, endPage ... } earlier?
    // We need to re-parse or rely on variable access.
    // Deno `req.json()` consumes body? Yes. We parsed it at start.
    // We need to cast the initial props.

    // Using values parsed at top of function
    // MAIN EXECUTION LOGIC
    if (startPage !== undefined && endPage !== undefined) {
         // CLIENT-DRIVEN SINGLE BATCH MODE (Prevents Worker Limit by distributing load)
         console.log(`Processing Single Requested Batch: ${startPage} to ${endPage}`)
         await processBatch(startPage, endPage)
    } else {
         // LEGACY LOOP MODE (Only if no specific batch requested)
         console.log("Legacy Mode: Processing Full Paper Loop")
         for (let i = 0; i < totalPages; i += (BATCH_SIZE - BATCH_OVERLAP)) {
            const sp = i + 1
            if (sp > totalPages) break
            const ep = Math.min(i + BATCH_SIZE, totalPages)
            await processBatch(i, ep)
        }
    }

    console.log(`Total Extracted Questions (before dedup): ${allQuestions.length}`)

    // Step 6: Data Transformation
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    const questionsToInsert = allQuestions.map(row => {
        if (!Array.isArray(row)) return null

        let formattedOptions: {label: string, text: string}[] | null = null
        if (Array.isArray(row[5])) {
            formattedOptions = row[5].map(opt => {
                if (Array.isArray(opt) && opt.length >= 2) return { label: opt[0], text: opt[1] }
                return { label: "?", text: String(opt) }
            })
        }

        const figArr = row[10]
        const figureData = (Array.isArray(figArr) && figArr.length >= 5) ? {
            page: figArr[0], x: figArr[1], y: figArr[2], width: figArr[3], height: figArr[4]
        } : undefined

        const layoutScan = row[8] || "No scan provided"
        const figDesc = row[9] || (figureData ? "Figure detected" : null)
        const aiRational = row[7] || null

        // Figure Metadata - SAME FOR BOTH MCQ AND STRUCTURED
        const figureMetadata = figureData ? {
            has_figure: true,
            layout_scan: layoutScan,
            figure_description: figDesc,
            figure_location: {
                page: figureData.page,
                x_percent: figureData.x,
                y_percent: figureData.y,
                width_percent: figureData.width,
                height_percent: figureData.height
            },
            ai_solution: aiRational
        } : {
            has_figure: false,
            layout_scan: layoutScan,
            ai_solution: aiRational
        }

        return {
            paper_id: paperId,
            question_number: row[0],
            content: row[1],
            topic_ids: (row[2] || []).filter(id => uuidRegex.test(id)),
            type: row[3] || "mcq",
            options: formattedOptions,
            correct_answer: row[6],
            marks: row[4] || 1,
            ai_answer: figureMetadata,
            official_answer: null,
            image_url: null
        }
    }).filter(q => q !== null)

    // DEDUPLICATE by question_number (overlap may cause duplicates)
    const uniqueQuestions = []
    const seenNumbers = new Set()
    for (const q of questionsToInsert) {
        if (!seenNumbers.has(q.question_number)) {
            seenNumbers.add(q.question_number)
            uniqueQuestions.push(q)
        }
    }

    console.log(`Transformed ${uniqueQuestions.length} unique questions.`)

    // Step 7: Batch Upsert (IDEMPOTENT)
    const { data: insertedQuestions, error: insertError } = await supabase
        .from('questions')
        .upsert(uniqueQuestions, { onConflict: 'paper_id,question_number', ignoreDuplicates: false })
        .select('id, question_number')

    if (insertError) throw insertError

    // Step 8: Crop Figures - CONCURRENT BATCHED PROCESSING
    let figsCropped = 0
    const questionsWithFigures = uniqueQuestions.filter(q => q.ai_answer.has_figure)
    
    if (insertedQuestions && questionsWithFigures.length) {
        console.log(`Processing ${questionsWithFigures.length} figures...`)
        
        // Process in batches of 5 to avoid overwhelming Supabase/Rate Limits
        // but faster than sequential
        const CROP_BATCH_SIZE = 5;
        for (let i = 0; i < questionsWithFigures.length; i += CROP_BATCH_SIZE) {
             const batch = questionsWithFigures.slice(i, i + CROP_BATCH_SIZE);
             await Promise.all(batch.map(async (q) => {
                 const insertedQ = insertedQuestions.find(iq => iq.question_number === q.question_number)
                 if (!insertedQ) return

                 try {
                     const cropRes = await fetchWithRetry(`${supabaseUrl}/functions/v1/crop-figure`, {
                         method: 'POST',
                         headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${supabaseKey}`, 'apikey': supabaseKey },
                         body: JSON.stringify({
                             pdfUrl, questionId: insertedQ.id, page: q.ai_answer.figure_location.page,
                             bbox: {
                                 x: q.ai_answer.figure_location.x_percent, y: q.ai_answer.figure_location.y_percent,
                                 width: q.ai_answer.figure_location.width_percent, height: q.ai_answer.figure_location.height_percent
                             }
                         })
                     }, 2) // Reduced retries for speed
                     if (cropRes.ok) figsCropped++
                 } catch (e) {
                     console.warn(`Crop failed Q${q.question_number}`, e)
                 }
             }));
             // Small delay between batches
             if (i + CROP_BATCH_SIZE < questionsWithFigures.length) await new Promise(r => setTimeout(r, 500));
        }
    }

    return new Response(JSON.stringify({
        success: true,
        message: `Extracted ${uniqueQuestions.length} questions`,
        figures_cropped: figsCropped,
        answers_extracted: 0, // Handled asynchronously by process-mark-scheme now
        warnings: questionsWithFigures.length > figsCropped ? "Some figures failed to crop" : null
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('Fatal:', error)
    return new Response(JSON.stringify({ error: 'Unexpected error', details: String(error) }), { status: 500, headers: corsHeaders })
  }
})