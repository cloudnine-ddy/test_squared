import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// VERSION: 9.0 - UNIFIED PROCESSING (MCQ + Structured get same treatment)
// Improvements:
// - Batch overlap (1 page) for cross-page questions
// - Dynamic subject prompts
// - Retry mechanism (3 attempts)
// - Parallel mark scheme processing
// - Both MCQ and Structured get: crop, answers, AI solution

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'
const BATCH_SIZE = 10
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
    const { paperId, pdfUrl, markSchemeUrl, paperType } = await req.json()
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
    console.log(`Total Pages: ${totalPages}. Processing with ${BATCH_OVERLAP}-page overlap...`)

    let allQuestions: CompactQuestion[] = []

    // BATCH LOOP WITH OVERLAP
    for (let i = 0; i < totalPages; i += (BATCH_SIZE - BATCH_OVERLAP)) {
        const startPage = i + 1
        const endPage = Math.min(i + BATCH_SIZE, totalPages)

        // Skip if this batch would be just 1-2 pages at the end (already covered)
        if (startPage >= totalPages) break

        console.log(`Processing Batch: Pages ${startPage}-${endPage}...`)

        // Create Sub-PDF
        const subDoc = await PDFDocument.create()
        const pageIndices = []
        for (let j = 0; j < (endPage - startPage + 1); j++) pageIndices.push(i + j)

        const copiedPages = await subDoc.copyPages(srcDoc, pageIndices)
        copiedPages.forEach(p => subDoc.addPage(p))
        const subPdfBytes = await subDoc.saveAsBase64()

        // DYNAMIC SUBJECT-BASED PROMPT
        // Both MCQ and Structured now extract figures and provide rationale
        const prompt = isObjective
          ? `You are a ${subjectName} MCQ exam analyzer (Batch pages ${startPage}-${endPage}).
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
          : `You are a ${subjectName} structured question analyzer (Batch pages ${startPage}-${endPage}).
CRITICAL: Any question with diagrams, graphs, tables = HAS FIGURE. Estimate bounding box.
OUTPUT JSON (COMPACT ARRAY):
{ "d": [ [1, "Full question text", ["topic-uuid"], "structured", 6, null, null, "Key points for answer", "Layout notes", "Figure description", [1,20,30,50,40]] ] }
TOPICS: ${topicsJson}
RULES:
1. Extract ALL structured questions from these pages
2. Use compact array format strictly
3. For index 7, provide key points/expected answer structure
4. Figure coordinates are PERCENTAGES. [page, x%, y%, width%, height%]
5. For questions WITHOUT figures, use null for index 10
6. Include sub-parts in the content (a, b, c, etc.)
7. IMPORTANT: The content field should ONLY contain the actual question text. IGNORE:
   - Dotted lines for student answers (................)
   - Empty answer spaces
   - Page numbers, barcodes, copyright text
   - "[Turn over]" markers
   Example: For "(a) State the function of X. ..............." extract only "(a) State the function of X."`

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

            if (!geminiRes.ok) throw new Error(`Gemini Error Batch ${startPage}-${endPage}: ${await geminiRes.text()}`)
            const geminiJson = await geminiRes.json()
            let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || ''
            if (rawText.includes('```')) rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()

            let rawData: any = {}
            try { rawData = JSON.parse(rawText) } catch(e) {
                 let repaired = rawText.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (m) => m.replace(/\n/g, '\\n'))
                 try { rawData = JSON.parse(repaired) } catch(err) { console.warn(`Batch ${startPage}-${endPage} parse fail`, err) }
            }

            const batchQs = (rawData.d || rawData.questions || (Array.isArray(rawData) ? rawData : [])) as CompactQuestion[]
            if (batchQs.length) {
                console.log(`Batch ${startPage}-${endPage}: Extracted ${batchQs.length} questions`)

                // ADJUST PAGE NUMBERS for offset
                const offsetQs = batchQs.map(q => {
                   const newQ: CompactQuestion = [...q]
                   if (Array.isArray(newQ[10]) && newQ[10].length >= 1) {
                        newQ[10][0] = newQ[10][0] + (startPage - 1)
                   }
                   return newQ
                }) as CompactQuestion[]

                allQuestions = [...allQuestions, ...offsetQs]
            }
        } catch (batchErr) {
            console.error(`Error processing batch ${startPage}-${endPage}:`, batchErr)
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

    // Step 7: Batch Insert
    const { data: insertedQuestions, error: insertError } = await supabase.from('questions').insert(uniqueQuestions).select('id, question_number')
    if (insertError) throw insertError

    // Step 8: Crop Figures - FOR BOTH MCQ AND STRUCTURED
    let figsCropped = 0
    const questionsWithFigures = uniqueQuestions.filter(q => q.ai_answer.has_figure)
    if (insertedQuestions && questionsWithFigures.length) {
        console.log(`Processing ${questionsWithFigures.length} figures (both MCQ and Structured)...`)
        for (const q of questionsWithFigures) {
            const insertedQ = insertedQuestions.find(iq => iq.question_number === q.question_number)
            if (!insertedQ) continue

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
                })
                if (cropRes.ok) figsCropped++
            } catch (e) { console.warn(`Crop failed Q${q.question_number}`, e) }
        }
    }

    // Step 9: Mark Scheme - PARALLEL PROCESSING for BOTH types
    let answersExtracted = 0
    if (hasMarkScheme && insertedQuestions) {
        console.log('Processing Mark Scheme with parallel batches...')
        try {
            const msRes = await fetch(markSchemeUrl)
            if (msRes.ok) {
                const msBlob = await msRes.blob()
                const msArrayBuffer = await msBlob.arrayBuffer()

                function toBase64(u8: Uint8Array) {
                   let b = ''; const l=u8.length;
                   for(let i=0;i<l;i+=32768) b+=String.fromCharCode(...u8.subarray(i,i+32768));
                   return btoa(b);
                }
                const msBase64 = toBase64(new Uint8Array(msArrayBuffer))

                const msPrompt = `You are extracting OFFICIAL ANSWERS from a mark scheme PDF.
Extract answers for ALL questions (MCQ and structured).

OUTPUT JSON:
{ "answers": [
  {"question_number": 1, "sub_part": "a", "official_answer": "cell A / sperm cell", "marks": 1},
  {"question_number": 1, "sub_part": "b(i)", "official_answer": "contains genetic information; controls cell activities", "marks": 2}
] }

RULES:
1. For MCQ: official_answer is the letter (A, B, C, D)
2. For structured: official_answer is the full marking point text
3. Use sub_part for questions with parts (a, b, c, bi, bii, etc.)
4. If a question has no sub-parts, omit sub_part
5. Include ALL questions, even if marks are unclear (default to 1)
6. Combine multiple marking points with semicolons`

                const msGemini = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: msPrompt }, { inline_data: { mime_type: 'application/pdf', data: msBase64 } }] }],
                        generationConfig: { temperature: 0.1, maxOutputTokens: 8192, responseMimeType: "application/json" }
                    })
                })

                if (msGemini.ok) {
                    const msJson = await msGemini.json()
                    const msText = msJson.candidates?.[0]?.content?.parts?.[0]?.text || '{}'
                    const msParsed = JSON.parse(msText.replace(/```json|```/g, '').trim())
                    const answers = msParsed.answers || []

                    // PARALLEL PROCESSING in batches of PARALLEL_BATCH_SIZE
                    for (let i = 0; i < answers.length; i += PARALLEL_BATCH_SIZE) {
                        const batch = answers.slice(i, i + PARALLEL_BATCH_SIZE)

                        await Promise.all(batch.map(async (ans: any) => {
                            const qMatch = insertedQuestions.find(q => q.question_number === ans.question_number)
                            if (!qMatch) return

                            const originalQ = uniqueQuestions.find(q => q.question_number === ans.question_number)
                            if (!originalQ) return

                            // Generate AI Solution for BOTH MCQ and Structured
                            const solPrompt = originalQ.type === 'mcq'
                              ? `You are a ${subjectName} tutor. Provide a concise explanation of why "${ans.official_answer}" is correct.

Question: ${originalQ.content || 'See paper'}
Correct Answer: ${ans.official_answer}

Write EXACTLY 4-5 sentences explaining the scientific reasoning.
CRITICAL RULES:
- Start directly with the explanation
- NO preambles like "Okay, let's break down...", "The answer is...", "Let me explain...", "Sure..."
- NO headings like "**The Big Idea:**" or "**Why this works:**"
- Just pure scientific explanation
- Keep it concise and focused on key concepts`
                              : `You are a ${subjectName} tutor. Write a concise model answer for this structured question.

Question: ${originalQ.content || 'See paper'}
Marking Points: ${ans.official_answer}
Marks: ${ans.marks || 'unknown'}

Write a model answer as a student would write it (4-5 sentences maximum). Include all marking points as prose.
CRITICAL RULES:
- Start directly with the answer content
- NO preambles or explanations about the marking scheme
- Write as if you are the student answering in an exam
- Concise and focused`

                            const solRes = await fetchWithRetry(`${GEMINI_API_URL}?key=${apiKey}`, {
                                method: 'POST',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify({ contents: [{ parts: [{ text: solPrompt }] }] })
                            })

                            let solText = null
                            if (solRes.ok) {
                                const solJson = await solRes.json()
                                solText = solJson.candidates?.[0]?.content?.parts?.[0]?.text
                            }

                            const existingRational = originalQ.ai_answer?.ai_solution

                            await supabase.from('questions').update({
                                official_answer: ans.official_answer,
                                marks: ans.marks,
                                ai_answer: {
                                    ...originalQ.ai_answer,
                                    marks: ans.marks,
                                    ai_solution: solText || existingRational
                                }
                            }).eq('id', qMatch.id)
                            answersExtracted++
                        }))
                    }
                }
            }
        } catch (e) { console.warn("Mark scheme error", e) }
    }

    return new Response(JSON.stringify({
        success: true,
        message: `Extracted ${uniqueQuestions.length} questions`,
        figures_cropped: figsCropped,
        answers_extracted: answersExtracted
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error) {
    console.error('Fatal:', error)
    return new Response(JSON.stringify({ error: 'Unexpected error', details: String(error) }), { status: 500, headers: corsHeaders })
  }
})