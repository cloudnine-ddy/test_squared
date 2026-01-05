import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

interface AIChatRequest {
  questionId: string
  userMessage: string
  conversationHistory?: Array<{ message: string; isAI: boolean }>
  userAnswer?: string  // User's submitted answer
  userScore?: number   // Score received (0-100 percentage)
  intent?: 'chat' | 'generate_question'
}

interface AIChatResponse {
  message: string
  error?: string
  generated_question?: any
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
    const { questionId, userMessage, conversationHistory, userAnswer, userScore, intent } = await req.json() as AIChatRequest

    // Validate inputs
    if (!userMessage || userMessage.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Message is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!questionId) {
      return new Response(
        JSON.stringify({ error: 'Question ID is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch the question from database
    console.log(`🔍 Fetching question ${questionId}...`)

    const { data: question, error: questionError } = await supabaseClient
      .from('questions')
      .select('content, official_answer, marks, type')
      .eq('id', questionId)
      .single()

    console.log('Question data:', question)
    console.log('Question error:', questionError)

    if (questionError || !question) {
      console.error('Question not found:', questionId, questionError)
      return new Response(
        JSON.stringify({ error: 'Question not found', questionId, details: questionError?.message }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get API key
    const apiKey = Deno.env.get('GEMINI_API_KEY')
    if (!apiKey) {
      console.error('GEMINI_API_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'AI service not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build context
    const historyContext = conversationHistory && conversationHistory.length > 0
      ? '\n\nCONVERSATION HISTORY:\n' + conversationHistory
          .slice(-6) // Last 6 messages for context
          .map(msg => `${msg.isAI ? 'AI' : 'Student'}: ${msg.message}`)
          .join('\n')
      : ''

    let systemPrompt = '';

    if (intent === 'generate_question') {
      systemPrompt = `You are an expert exam setter for SPM (Form 4 and Form 5 KSSM syllabus).
Your task: Create a NEW, high-quality exam question similar to the one provided below.
The new question must test similar concepts but use different values, context, or scenarios.

ORIGINAL QUESTION:
${question.content}
 MARKS: ${question.marks}

INSTRUCTIONS:
1. Create a NEW question text using standard Markdown (**bold**, *italic*).
2. Provide valid marks.
3. Provide a clear Official Answer Key.
4. Provide a brief explanation.
5. Identify the Topic and Syllabus Level (Form 4 or Form 5).
6. Return ONLY a JSON object. Do not include markdown formatting like \`\`\`json.

JSON Structure:
{
  "is_structured_question": true,
  "content": "The question text here with **bold keywords**.",
  "marks": number,
  "official_answer": "The suggested answer key.",
  "explanation": "Brief explanation of the answer.",
  "topic": "Topic Name",
  "syllabus_level": "SPM Form 4 or 5"
}

Verify the output is valid JSON.`
    } else {
      // Standard Chat Prompt
      systemPrompt = `You are a helpful, encouraging AI study assistant for IGCSE/GCSE students. Your role is to:
- Help students understand questions
- Provide hints without giving direct answers
- Explain concepts in simple, student-friendly language
- Check understanding through thoughtful questions
- Encourage critical thinking

QUESTION:
${question.content}

${question.official_answer ? `OFFICIAL ANSWER/KEY CONCEPTS:\n${question.official_answer}` : ''}

${question.marks ? `MARKS: ${question.marks}` : ''}

${userAnswer ? `
USER'S SUBMITTED ANSWER:
${userAnswer}
${userScore !== undefined ? `Score received: ${userScore}%` : ''}

NOTE: The student has already attempted this question. They may ask:
- Why their answer was wrong or incomplete
- What they missed
- How to improve their answer
When answering, compare their answer to the official answer and provide specific, constructive feedback.
` : ''}

${historyContext}

STUDENT'S MESSAGE:
${userMessage}

GUIDELINES:
- Be warm, encouraging, and supportive
- If asked for explanation, break down concepts step-by-step
- If asked for hints, give progressive hints without revealing the answer
- If checking understanding, ask targeted questions
- Use analogies and examples when helpful
- Keep responses concise (2-3 paragraphs max)
- Use emojis sparingly to make it friendly 😊

Respond naturally to the student's message:`
    }

    // Call Gemini API
    const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: systemPrompt }] }],
        generationConfig: {
          temperature: intent === 'generate_question' ? 0.3 : 0.7, // Lower temperature for structured generation
          maxOutputTokens: 1024,
        }
      })
    })

    if (!geminiRes.ok) {
      const errorText = await geminiRes.text()
      console.error('Gemini API error:', geminiRes.status, errorText)
      return new Response(
        JSON.stringify({ error: 'AI service unavailable', details: errorText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const geminiJson = await geminiRes.json()

    // Extract the AI's response
    let aiMessage: string = ''
    let generatedQuestion = null

    try {
      let rawContent = geminiJson.candidates[0].content.parts[0].text

      if (intent === 'generate_question') {
        // Clean markdown code blocks if present
        rawContent = rawContent.replace(/```json/g, '').replace(/```/g, '').trim()
        try {
          generatedQuestion = JSON.parse(rawContent)
          aiMessage = "Sure, I can generate a similar question for you. Here is one based on the topic:"
        } catch (e) {
          console.error("Failed to parse JSON for generated question:", e)
          aiMessage = "I tried to generate a similar question, but I encountered an error formatting it. Let me try explaining the concept instead."
        }
      } else {
        aiMessage = rawContent

        if (!aiMessage || aiMessage.trim().length === 0) {
          throw new Error('Empty response from AI')
        }

        console.log(`✅ AI chat response generated for question ${questionId}`)
      }
    } catch (e) {
      console.error('Error parsing Gemini response:', e)
      // Return a fallback response
      aiMessage = "I'm having trouble processing that right now. Could you try rephrasing your question, or ask me to explain a specific part of the question?"
    }

    return new Response(
      JSON.stringify({ message: aiMessage, generated_question: generatedQuestion } as AIChatResponse),
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
