import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

interface AIChatRequest {
  questionId: string
  userMessage: string
  conversationHistory?: Array<{ message: string; isAI: boolean }>
}

interface AIChatResponse {
  message: string
  error?: string
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
    const { questionId, userMessage, conversationHistory } = await req.json() as AIChatRequest

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

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch the question from database
    console.log(`🔍 Fetching question ${questionId}...`)

    const { data: question, error: questionError } = await supabase
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

    // Build context from conversation history
    const historyContext = conversationHistory && conversationHistory.length > 0
      ? '\n\nCONVERSATION HISTORY:\n' + conversationHistory
          .slice(-6) // Last 6 messages for context
          .map(msg => `${msg.isAI ? 'AI' : 'Student'}: ${msg.message}`)
          .join('\n')
      : ''

    // Build the prompt for Gemini
    const systemPrompt = `You are a helpful, encouraging AI study assistant for IGCSE/GCSE students. Your role is to:
- Help students understand questions
- Provide hints without giving direct answers
- Explain concepts in simple, student-friendly language
- Check understanding through thoughtful questions
- Encourage critical thinking

QUESTION:
${question.content}

${question.official_answer ? `OFFICIAL ANSWER/KEY CONCEPTS:\n${question.official_answer}` : ''}

${question.marks ? `MARKS: ${question.marks}` : ''}

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

    // Call Gemini API
    const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: systemPrompt }] }],
        generationConfig: {
          temperature: 0.7,
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
    let aiMessage: string
    try {
      aiMessage = geminiJson.candidates[0].content.parts[0].text

      if (!aiMessage || aiMessage.trim().length === 0) {
        throw new Error('Empty response from AI')
      }

      console.log(`✅ AI chat response generated for question ${questionId}`)

    } catch (parseError) {
      console.error('Failed to parse Gemini response:', parseError)
      console.error('Raw:', geminiJson)

      // Return a fallback response
      aiMessage = "I'm having trouble processing that right now. Could you try rephrasing your question, or ask me to explain a specific part of the question?"
    }

    return new Response(
      JSON.stringify({ message: aiMessage } as AIChatResponse),
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
