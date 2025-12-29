import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

interface CheckAnswerRequest {
  questionId: string
  questionContent: string
  officialAnswer: string
  studentAnswer: string
  marks?: number
}

interface CheckAnswerResponse {
  isCorrect: boolean
  score: number  // 0-100 percentage
  feedback: string
  hints: string[]
  strengths: string[]
  improvements: string[]
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
    const { questionId, questionContent, officialAnswer, studentAnswer, marks } = await req.json() as CheckAnswerRequest

    // Validate inputs
    if (!studentAnswer || studentAnswer.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Student answer is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
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

    // Build the prompt for Gemini
    const prompt = `You are an expert IGCSE/GCSE examiner. Compare a student's answer to the official mark scheme and provide detailed feedback.

QUESTION:
${questionContent}

OFFICIAL ANSWER/MARK SCHEME:
${officialAnswer || 'Not available - use your knowledge to evaluate'}

STUDENT'S ANSWER:
${studentAnswer}

${marks ? `TOTAL MARKS: ${marks}` : ''}

Evaluate the student's answer and return a JSON response with:
1. "isCorrect": boolean - true if the answer is substantially correct (>70% accurate)
2. "score": number 0-100 - percentage score based on how complete/accurate the answer is
3. "feedback": string - overall feedback paragraph (2-3 sentences, encouraging tone)
4. "hints": array of strings - 1-3 hints if answer is wrong/incomplete (empty if correct)
5. "strengths": array of strings - 1-3 things the student did well
6. "improvements": array of strings - 1-3 specific improvements needed (empty if perfect)

IMPORTANT:
- Be encouraging but honest
- For MCQs, just check if the letter matches
- For structured questions, check key concepts and terminology
- Give partial credit where applicable
- Use simple, student-friendly language

Return ONLY valid JSON, no markdown.`

    // Call Gemini API
    const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 2048,
        }
      })
    })

    if (!geminiRes.ok) {
      const errorText = await geminiRes.text()
      console.error('Gemini API error:', geminiRes.status, errorText)
      return new Response(
        JSON.stringify({ error: 'AI evaluation failed', details: errorText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const geminiJson = await geminiRes.json()
    
    // Parse response
    let result: CheckAnswerResponse
    try {
      let rawText = geminiJson.candidates[0].content.parts[0].text
      
      // Remove markdown if present
      if (rawText.includes('```')) {
        rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
      }
      
      result = JSON.parse(rawText)
      
      // Validate and ensure all fields exist
      result = {
        isCorrect: result.isCorrect ?? false,
        score: Math.min(100, Math.max(0, result.score ?? 0)),
        feedback: result.feedback ?? 'Unable to evaluate answer.',
        hints: Array.isArray(result.hints) ? result.hints : [],
        strengths: Array.isArray(result.strengths) ? result.strengths : [],
        improvements: Array.isArray(result.improvements) ? result.improvements : [],
      }
      
    } catch (parseError) {
      console.error('Failed to parse Gemini response:', parseError)
      console.error('Raw:', geminiJson.candidates?.[0]?.content?.parts?.[0]?.text)
      
      // Return a fallback response
      result = {
        isCorrect: false,
        score: 0,
        feedback: 'Unable to evaluate your answer. Please try again.',
        hints: [],
        strengths: [],
        improvements: ['Try again with a clearer answer'],
      }
    }

    console.log(`✅ Answer checked for question ${questionId}: ${result.score}%`)

    return new Response(
      JSON.stringify(result),
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
