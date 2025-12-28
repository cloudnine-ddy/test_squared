import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// VERSION: 2.0 - Added topic_ids validation
// Use gemini-2.0-flash-exp which supports PDF analysis
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
  options?: { label: string; text: string }[]
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
    const { paperId, pdfUrl } = await req.json()
    
    if (!paperId || !pdfUrl) {
      return new Response(
        JSON.stringify({ error: 'Missing paperId or pdfUrl' }), 
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
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

    // Step 4: Build the prompt for Gemini
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))
    
    const prompt = `You are an expert exam paper analyzer for IGCSE/GCSE papers.

AVAILABLE TOPICS (use the "id" field for topic_ids, NOT the name):
${topicsJson}

TASK: Analyze this PDF exam paper and extract all questions.

For EACH question, provide:
1. question_number: The main question number (1, 2, 3, etc.) as an integer
2. content: The COMPLETE question text, including ALL sub-parts (a, b, c, i, ii, etc.)
3. topic_ids: Array of topic UUIDs (the "id" values from the AVAILABLE TOPICS list above, like "abc123-def456-..."). MUST be valid UUIDs from the list, NOT topic names!
4. type: Either "structured" (written answer) or "mcq" (multiple choice)
5. options: If MCQ, provide array of options like [{"label": "A", "text": "option text"}, ...]
6. figure: If the question includes a diagram/figure/graph/table/image, provide its location:
   - page: page number (1-indexed)
   - x: percentage from left edge (0-100) - START 15% BEFORE the actual figure
   - y: percentage from top edge (0-100) - START 15% ABOVE the actual figure  
   - width: percentage of page width (0-100) - ADD 30% extra width to ensure full capture
   - height: percentage of page height (0-100) - ADD 30% extra height to ensure full capture

CRITICAL RULES:
- topic_ids MUST contain UUID values from the topics list (like "abc123-def456-789..."), NOT topic names
- Combine all sub-parts (a, b, i, ii) into ONE question entry
- Match to topics as accurately as possible
- FIGURE BOUNDING BOX: Be VERY GENEROUS! Always add extra padding around figures. It's better to include too much than too little. Include the figure label (e.g., "Fig. 1") in the bounding box.
- If no figure, omit the "figure" field entirely
- If no matching topic, use empty array []

Return ONLY valid JSON in this exact format:
{
  "questions": [
    {
      "question_number": 1,
      "content": "Full text of question 1 including all parts...",
      "topic_ids": ["uuid-1", "uuid-2"],
      "type": "structured",
      "figure": {
        "page": 1,
        "x": 10,
        "y": 30,
        "width": 40,
        "height": 25
      }
    },
    {
      "question_number": 2,
      "content": "Question 2 text...",
      "topic_ids": ["uuid-3"],
      "type": "mcq",
      "options": [
        {"label": "A", "text": "First option"},
        {"label": "B", "text": "Second option"},
        {"label": "C", "text": "Third option"},
        {"label": "D", "text": "Fourth option"}
      ]
    }
  ]
}`

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
        maxOutputTokens: 8192,
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
      const rawText = geminiJson.candidates[0].content.parts[0].text
      const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
      extractedData = JSON.parse(cleanJson)
      console.log(`Gemini extracted ${extractedData.questions.length} questions`)
    } catch (parseError) {
      console.error('Failed to parse Gemini response:', parseError)
      console.error('Raw response:', JSON.stringify(geminiJson, null, 2))
      return new Response(
        JSON.stringify({ error: 'Failed to parse AI response' }), 
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
        figure_location: {
          page: question.figure.page,
          x_percent: question.figure.x,
          y_percent: question.figure.y,
          width_percent: question.figure.width,
          height_percent: question.figure.height
        }
      } : null

      questionsToInsert.push({
        paper_id: paperId,
        question_number: question.question_number,
        content: question.content,
        topic_ids: filteredTopicIds,
        type: question.type,
        options: question.options || null,
        image_url: null, // TODO: Implement PDF cropping with different library
        official_answer: null,
        ai_answer: figureMetadata, // Store figure info here
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
          const cropResponse = await supabase.functions.invoke('crop-figure', {
            body: {
              pdfUrl,
              questionId: insertedQ.id,
              page: question.figure.page,
              bbox: {
                x: question.figure.x,
                y: question.figure.y,
                width: question.figure.width,
                height: question.figure.height
              }
            }
          })

          if (cropResponse.error) {
            console.warn(`Failed to crop figure for Q${question.question_number}:`, cropResponse.error)
          } else {
            figuresCropped++
            console.log(`✅ Cropped and stored figure for Q${question.question_number}`)
          }
        } catch (cropError) {
          console.warn(`Error cropping figure for Q${question.question_number}:`, cropError)
        }
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Extracted and saved ${questionsToInsert.length} questions`,
        questions_count: questionsToInsert.length,
        topics_matched: questionsToInsert.filter(q => q.topic_ids.length > 0).length,
        figures_detected: questionsWithFigures.length,
        figures_cropped: figuresCropped
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