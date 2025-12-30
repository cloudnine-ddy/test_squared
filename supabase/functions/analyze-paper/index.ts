import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// VERSION: 4.0 - Optimized prompt for smaller output
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

// Types for structured data
interface Topic {
  id: string
  name: string
}

interface FigureBbox {
  page: number        // 1-indexed page number
  x: number           // percentage from left (0-100)
  y: number           // percentage from top (0-100)
  width: number       // percentage width (0-100)
  height: number      // percentage height (0-100)
}

interface ExtractedQuestion {
  question_number: number
  content: string
  topic_ids: string[]
  type: 'structured' | 'mcq'
  marks?: number
  options?: { label: string; text: string }[]
  correct_answer?: string
  layout_scan?: string | null  // Forces spatial reasoning
  figure_description?: string | null  // Forces vision encoder
  figure?: FigureBbox
}

interface AIResponse {
  questions: ExtractedQuestion[]
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

    console.log(`[DEBUG] Paper type received: "${paperType}"`)
    console.log(`[DEBUG] Is objective (MCQ): ${isObjective}`)

    if (!paperId || !pdfUrl) {
      return new Response(
        JSON.stringify({ error: 'Missing paperId or pdfUrl' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const hasMarkScheme = !!markSchemeUrl
    console.log(`Mark scheme provided: ${hasMarkScheme}`)
    if (hasMarkScheme) {
      console.log(`Mark scheme URL: ${markSchemeUrl}`)
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) {
      console.error('GEMINI_API_KEY not set')
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[1/6] Starting analysis for paper: ${paperId}`)

    // Step 1: Get paper details to find subject_id
    const { data: paper, error: paperError } = await supabase
      .from('papers')
      .select('id, subject_id, year, season, variant')
      .eq('id', paperId)
      .single()

    if (paperError || !paper) {
      console.error('Paper not found:', paperError)
      return new Response(
        JSON.stringify({ error: 'Paper not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[2/6] Paper found: ${paper.year} ${paper.season} (Subject: ${paper.subject_id})`)

    // Step 2: Fetch topics for this subject
    const { data: topics, error: topicsError } = await supabase
      .from('topics')
      .select('id, name')
      .eq('subject_id', paper.subject_id)

    if (topicsError) {
      console.error('Failed to fetch topics:', topicsError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch topics' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const topicsList: Topic[] = topics || []
    console.log(`[3/6] Found ${topicsList.length} topics for this subject`)

    // Step 3: Download PDF and convert to base64
    console.log(`[4/6] Downloading PDF from: ${pdfUrl}`)
    const pdfResponse = await fetch(pdfUrl)
    if (!pdfResponse.ok) {
      console.error('Failed to download PDF:', pdfResponse.status)
      return new Response(
        JSON.stringify({ error: 'Failed to download PDF' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const pdfBlob = await pdfResponse.blob()
    const arrayBuffer = await pdfBlob.arrayBuffer()
    const pdfBytes = new Uint8Array(arrayBuffer)

    // Convert to base64 (chunked to avoid stack overflow)
    function uint8ArrayToBase64(bytes: Uint8Array): string {
      const CHUNK_SIZE = 0x8000 // 32KB chunks
      let binary = ''
      for (let i = 0; i < bytes.length; i += CHUNK_SIZE) {
        const chunk = bytes.subarray(i, Math.min(i + CHUNK_SIZE, bytes.length))
        binary += String.fromCharCode.apply(null, Array.from(chunk))
      }
      return btoa(binary)
    }

    const base64Data = uint8ArrayToBase64(pdfBytes)
    console.log(`PDF downloaded: ${(pdfBytes.length / 1024 / 1024).toFixed(2)} MB`)

    // Step 4: Build the prompt for Gemini based on paper type
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    const objectivePrompt = `You are a Biology MCQ exam analyzer.

CRITICAL: Questions often mention "The diagram shows..." THIS MEANS there is an image!

REAL EXAM PATTERN:
Number: 4
Intro: "The diagram shows a cross-section through two guard cells..."
  arrow down
DIAGRAM with labels W,X,Y,Z
  arrow down
Question: "Which labelled structures would also be found in animal cell?"
  arrow down
Options: A, B, C, D

DETECTION RULE:
IF intro mentions "diagram/figure/graph/table" then set has_figure = true and provide coordinates

TOPICS (use id NOT name):
${topicsJson}

OUTPUT JSON:
{
  "questions": [
    {
      "question_number": 4,
      "content": "Which labelled structures would also be found in an animal cell?",
      "topic_ids": ["uuid"],
      "type": "mcq",
      "marks": 1,
      "options": [
        {"label":"A", "text":"W and X"},
        {"label":"B", "text":"X and Y"},
        {"label":"C", "text":"Y and Z"},
        {"label":"D", "text":"Z and W"}
      ],
      "correct_answer": "C",
      "layout_scan": "Found 4. Intro says The diagram shows. Below is labeled diagram. Below diagram is question. DIAGRAM DETECTED.",
      "figure_description": "Cross-section of two guard cells with labeled structures W,X,Y,Z",
      "figure": {"page":1, "x":20, "y":30, "width":60, "height":35}
    }
  ]
}

RULES:
1. layout_scan = MANDATORY (describe what you see vertically)
2. figure_description = Required if image exists
3. figure = Percentages (0-100) of page width/height
4. content = Question text ONLY (no A/B/C/D)
5. Extract ALL questions

Return valid JSON, no markdown.`

    const subjectivePrompt = `You are a Biology structured question analyzer.

PATTERN: Intro then Diagram then Sub-questions (a)(b)(c)

DETECTION RULE:
IF intro mentions "diagram/figure/graph" then set has_figure = true and provide coordinates

TOPICS (use id NOT name):
${topicsJson}

OUTPUT JSON:
{
  "questions": [
    {
      "question_number": 1,
      "content": "Full question with all parts: (a) Name structure X. (b) Describe function...",
      "topic_ids": ["uuid"],
      "type": "structured",
      "marks": 6,
      "layout_scan": "Found 1. Intro says The diagram shows a plant cell. Below is labeled diagram. Below are parts (a)(b). DIAGRAM DETECTED.",
      "figure_description": "Labeled plant cell diagram showing nucleus, chloroplasts, cell wall",
      "figure": {"page":1, "x":20, "y":25, "width":60, "height":40}
    }
  ]
}

RULES:
1. layout_scan = MANDATORY
2. figure_description = Required if image exists
3. figure = Percentages (0-100)
4. content = Combine ALL sub-parts into one text
5. marks = Total marks

Return valid JSON, no markdown.`

    const prompt = isObjective ? objectivePrompt : subjectivePrompt
    console.log(`Using ${isObjective ? 'OBJECTIVE (MCQ)' : 'SUBJECTIVE (Written)'} prompt`)

    // Step 5: Send to Gemini
    console.log('[5/6] Sending to Gemini for analysis...')

    const geminiPayload = {
      contents: [{
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: "application/pdf",
              data: base64Data
            }
          }
        ]
      }],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 16384,
      }
    }

    const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiPayload)
    })

    if (!geminiRes.ok) {
      const errorText = await geminiRes.text()
      console.error('Gemini API error:', geminiRes.status, errorText)
      return new Response(
        JSON.stringify({ error: 'Gemini API error', details: errorText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const geminiJson = await geminiRes.json()

    // Parse Gemini response
    let extractedData: AIResponse
    try {
      let rawText = geminiJson.candidates[0].content.parts[0].text

      // Remove markdown code blocks if present
      if (rawText.includes('```')) {
        rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
      }

      // Try parsing directly first
      try {
        extractedData = JSON.parse(rawText)
      } catch (firstError) {
        console.log('First parse failed, attempting repair...')

        // Try to repair common issues
        // 1. Fix unescaped control characters inside strings only
        let repaired = rawText

        // Replace unescaped newlines inside string values
        // This regex finds strings and escapes newlines within them
        repaired = repaired.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (match) => {
          return match
            .replace(/\n/g, '\\n')
            .replace(/\r/g, '\\r')
            .replace(/\t/g, '\\t')
        })

        extractedData = JSON.parse(repaired)
      }

      console.log(`Gemini extracted ${extractedData.questions.length} questions`)
    } catch (parseError) {
      console.error('Failed to parse Gemini response:', parseError)
      // Log first 2000 chars of response for debugging
      const rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || 'No text'
      console.error('Raw response (first 2000 chars):', rawText.substring(0, 2000))
      console.error('Response length:', rawText.length)
      return new Response(
        JSON.stringify({ error: 'Failed to parse AI response', details: String(parseError) }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 6: Process figures and insert questions
    console.log('[6/6] Processing questions...')

    // Identify questions with figures for later processing
    const questionsWithFigures = extractedData.questions.filter(q => q.figure)
    console.log(`Found ${questionsWithFigures.length} questions with figures`)

    // Get valid topic IDs for validation
    const validTopicIds = new Set(topicsList.map(t => t.id))

    // UUID regex pattern for validation
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    // Process each question
    const questionsToInsert = []

    for (const question of extractedData.questions) {
      if (question.figure) {
        console.log(`Question ${question.question_number} has figure on page ${question.figure.page}`)
      }

      // Filter topic_ids to only include valid UUIDs that exist in our topics
      let filteredTopicIds: string[] = []
      if (question.topic_ids && Array.isArray(question.topic_ids)) {
        filteredTopicIds = question.topic_ids.filter(id => {
          const isValidUuid = typeof id === 'string' && uuidRegex.test(id)
          const existsInDb = validTopicIds.has(id)
          if (!isValidUuid) {
            console.warn(`Filtering out invalid topic_id (not UUID): ${id}`)
          } else if (!existsInDb) {
            console.warn(`Filtering out topic_id (not in DB): ${id}`)
          }
          return isValidUuid && existsInDb
        })
      }

      console.log(`Q${question.question_number}: ${filteredTopicIds.length} valid topic_ids`)

      // Store figure metadata in ai_answer field for now (can be used for future cropping)
      const figureMetadata = question.figure ? {
        has_figure: true,
        layout_scan: question.layout_scan,
        figure_description: question.figure_description,
        figure_location: {
          page: question.figure.page,
          x_percent: question.figure.x,
          y_percent: question.figure.y,
          width_percent: question.figure.width,
          height_percent: question.figure.height
        }
      } : {
        has_figure: false,
        layout_scan: question.layout_scan
      }

      questionsToInsert.push({
        paper_id: paperId,
        question_number: question.question_number,
        content: question.content,
        topic_ids: filteredTopicIds,
        type: question.type,
        options: question.options || null,
        correct_answer: question.correct_answer || null,
        marks: question.marks || null,  // Save marks to proper column
        image_url: null,
        official_answer: null,
        ai_answer: figureMetadata, // Store figure info here (temporary, until cropped)
      })
    }

    // Insert all questions
    const { data: insertedQuestions, error: insertError } = await supabase
      .from('questions')
      .insert(questionsToInsert)
      .select('id, question_number')

    if (insertError) {
      console.error('Failed to insert questions:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to save questions', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Successfully inserted ${questionsToInsert.length} questions`)

    // Step 7: Process figures by calling crop-figure function (using pdf.co API)
    let figuresCropped = 0
    if (insertedQuestions && questionsWithFigures.length > 0) {
      console.log(`[7/7] Processing ${questionsWithFigures.length} figures with pdf.co...`)

      for (const question of questionsWithFigures) {
        const insertedQ = insertedQuestions.find(
          (q: { question_number: number }) => q.question_number === question.question_number
        )

        if (!insertedQ || !question.figure) continue

        try {
          console.log(`Cropping figure for Q${question.question_number}...`)

          // Call crop-figure directly with service role auth
          const cropResponse = await fetch(`${supabaseUrl}/functions/v1/crop-figure`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${supabaseKey}`,
              'apikey': supabaseKey,
            },
            body: JSON.stringify({
              pdfUrl,
              questionId: insertedQ.id,
              page: question.figure.page,
              bbox: {
                x: question.figure.x,
                y: question.figure.y,
                width: question.figure.width,
                height: question.figure.height
              }
            })
          })

          const cropResult = await cropResponse.json()

          if (!cropResponse.ok || cropResult.error) {
            console.warn(`Failed to crop figure for Q${question.question_number}:`, cropResult.error || cropResponse.status)
          } else {
            figuresCropped++
            console.log(`✅ Cropped and stored figure for Q${question.question_number}`)
          }
        } catch (cropError) {
          console.warn(`Error cropping figure for Q${question.question_number}:`, cropError)
        }
      }
    }

    // Step 8: Process mark scheme if provided
    let answersExtracted = 0
    if (hasMarkScheme && insertedQuestions) {
      console.log(`[8/8] Processing mark scheme...`)

      try {
        // Download mark scheme PDF
        console.log(`Downloading mark scheme from: ${markSchemeUrl}`)
        const msResponse = await fetch(markSchemeUrl)
        console.log(`Mark scheme download status: ${msResponse.status}`)
        if (!msResponse.ok) {
          console.warn('Failed to download mark scheme')
        } else {
          const msBlob = await msResponse.blob()
          const msArrayBuffer = await msBlob.arrayBuffer()
          const msBytes = new Uint8Array(msArrayBuffer)
          const msBase64 = uint8ArrayToBase64(msBytes)

          console.log(`Mark scheme downloaded: ${(msBytes.length / 1024).toFixed(1)} KB`)

          // Build prompt for answer extraction
          const msPrompt = `You are analyzing an EXAM MARK SCHEME / ANSWER SHEET.

Extract the OFFICIAL ANSWERS for each question. The mark scheme may contain:
- Direct answers (e.g., "A", "42", "x = 5")
- Marking criteria (e.g., "Award 1 mark for method, 2 for answer")
- Acceptable alternative answers

For each question, extract:
1. question_number: The question number (1, 2, 3, etc.)
2. official_answer: The official answer or marking criteria (as a clear string)
3. marks: Number of marks available (extract from [1], [2 marks], etc.)

Return ONLY valid JSON:
{
  "answers": [
    {"question_number": 1, "official_answer": "B", "marks": 1},
    {"question_number": 2, "official_answer": "x = 5\\nMethod: rearrange equation\\nAnswer: substitute and solve", "marks": 3}
  ]
}`

          // Send to Gemini
          const msGeminiPayload = {
            contents: [{
              parts: [
                { text: msPrompt },
                { inline_data: { mime_type: 'application/pdf', data: msBase64 } }
              ]
            }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 8192
            }
          }

          const msGeminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(msGeminiPayload)
          })

          if (msGeminiRes.ok) {
            const msGeminiJson = await msGeminiRes.json()
            const msRawText = msGeminiJson.candidates?.[0]?.content?.parts?.[0]?.text || ''
            const msCleanJson = msRawText.replace(/\`\`\`json/g, '').replace(/\`\`\`/g, '').trim()

            try {
              const answersData = JSON.parse(msCleanJson)
              console.log(`Extracted ${answersData.answers?.length || 0} answers from mark scheme`)

              // Match answers to questions and generate AI solutions
              for (const answer of answersData.answers || []) {
                const matchingQ = insertedQuestions.find(
                  (q: { question_number: number }) => q.question_number === answer.question_number
                )

                if (matchingQ) {
                  // Generate AI step-by-step solution
                  const solutionPrompt = `You are a helpful tutor. Generate a clear, student-friendly step-by-step solution.

Question: ${questionsToInsert.find(q => q.question_number === answer.question_number)?.content || 'See paper'}

Official Answer: ${answer.official_answer}
Marks Available: ${answer.marks || 'Unknown'}

Create a solution that:
1. Explains the approach simply
2. Shows clear working steps
3. Explains WHY each step is correct
4. Highlights common mistakes to avoid

Format your response as clear numbered steps. Be concise but thorough.`

                  const solutionRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                      contents: [{ parts: [{ text: solutionPrompt }] }],
                      generationConfig: { temperature: 0.3, maxOutputTokens: 1024 }
                    })
                  })

                  let aiSolution = null
                  if (solutionRes.ok) {
                    const solutionJson = await solutionRes.json()
                    aiSolution = solutionJson.candidates?.[0]?.content?.parts?.[0]?.text || null
                  }

                  // Update question with official answer and AI solution
                  await supabase
                    .from('questions')
                    .update({
                      official_answer: answer.official_answer,
                      ai_answer: {
                        ...questionsToInsert.find(q => q.question_number === answer.question_number)?.ai_answer,
                        marks: answer.marks,
                        ai_solution: aiSolution
                      }
                    })
                    .eq('id', matchingQ.id)

                  answersExtracted++
                  console.log(`✅ Updated Q${answer.question_number} with answer + AI solution`)
                }
              }
            } catch (parseErr) {
              console.warn('Failed to parse mark scheme response:', parseErr)
            }
          } else {
            console.warn('Mark scheme Gemini API error:', msGeminiRes.status)
          }
        }
      } catch (msError) {
        console.warn('Error processing mark scheme:', msError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Extracted and saved ${questionsToInsert.length} questions`,
        questions_count: questionsToInsert.length,
        topics_matched: questionsToInsert.filter(q => q.topic_ids.length > 0).length,
        figures_detected: questionsWithFigures.length,
        figures_cropped: figuresCropped,
        answers_extracted: answersExtracted
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Unexpected error', details: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})