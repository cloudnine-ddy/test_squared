import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { handleStructuredQuestion } from './structured-handler.ts'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

interface CheckAnswerRequest {
  questionId: string
  questionContent: string
  officialAnswer: string
  studentAnswer: string
  marks?: number
  userId?: string  // Add userId for saving attempt
  timeSpent?: number  // Add time tracking
  hintsUsed?: number  // Add hints tracking
  selectedOption?: string  // For MCQ questions
  // NEW: For structured questions
  isStructured?: boolean
  structuredAnswers?: Array<{
    label: string  // e.g. "a", "b(i)"
    studentAnswer: string
    officialAnswer: string | null
    marks: number
  }>
}

interface CheckAnswerResponse {
  isCorrect: boolean
  score: number  // 0-100 percentage
  feedback: string
  hints: string[]
  strengths: string[]
  improvements: string[]
  attemptId?: string  // Return the saved attempt ID
  // NEW: For structured questions
  perPartResults?: Array<{
    label: string
    isCorrect: boolean
    score: number
    feedback: string
  }>
  totalMarks?: number
  earnedMarks?: number
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
    const {
      questionId,
      questionContent,
      officialAnswer,
      studentAnswer,
      marks,
      userId,
      timeSpent,
      hintsUsed,
      selectedOption,
      isStructured,
      structuredAnswers
    } = await req.json() as CheckAnswerRequest

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Handle structured questions differently
    if (isStructured && structuredAnswers && structuredAnswers.length > 0) {
      return await handleStructuredQuestion({
        questionId,
        structuredAnswers,
        userId,
        timeSpent,
        hintsUsed,
        supabase,
        apiKey: Deno.env.get('GEMINI_API_KEY') || '',
        corsHeaders
      })
    }

    // Validate inputs for regular questions
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

    // Call Gemini API with Retry
    let geminiRes;
    let attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
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

        if (geminiRes.status === 429) {
          console.log(`⚠️ Rate limited (429). Retrying in 1s... (Attempt ${attempts + 1}/${maxAttempts})`);
          await new Promise(resolve => setTimeout(resolve, 1000));
          attempts++;
          continue;
        }

        break;
      } catch (e) {
        console.warn(`Network error, retrying...`, e);
        attempts++;
        if (attempts >= maxAttempts) throw e;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }

    if (!geminiRes || !geminiRes.ok) {
      const errorText = geminiRes ? await geminiRes.text() : 'Unknown network error';
      const status = geminiRes ? geminiRes.status : 500;
      console.error('Gemini API error:', status, errorText)
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

    // CRITICAL: Save the attempt to database if userId provided
    if (userId) {
      try {
        const attemptData = {
          user_id: userId,
          question_id: questionId,
          answer_text: selectedOption ? null : studentAnswer,  // For structured questions
          selected_option: selectedOption || null,  // For MCQ questions
          score: result.score,
          is_correct: result.isCorrect,
          time_spent_seconds: timeSpent || 0,
          hints_used: hintsUsed || 0,
          attempted_at: new Date().toISOString()
        }

        const { data: attemptRecord, error: insertError } = await supabase
          .from('user_question_attempts')
          .insert(attemptData)
          .select()
          .single()

        if (insertError) {
          console.error('Failed to save attempt:', insertError)
          // Don't fail the whole request - return grade but log error
        } else {
          result.attemptId = attemptRecord.id
          console.log(`✅ Progress saved for user ${userId}`)
        }
      } catch (dbError) {
        console.error('Database error:', dbError)
        // Don't fail - user still gets their grade
      }
    }

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

