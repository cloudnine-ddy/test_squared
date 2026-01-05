import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request
    const { user_id, question_id, user_answer_text, time_spent, hints_count } = await req.json()

    // Validate input
    if (!user_id || !question_id || !user_answer_text) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id, question_id, user_answer_text' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch the question from database
    const { data: question, error: questionError } = await supabase
      .from('questions')
      .select('id, official_answer, marks')
      .eq('id', question_id)
      .single()

    if (questionError || !question) {
      return new Response(
        JSON.stringify({ error: 'Question not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Grade the answer (placeholder implementation)
    const gradeResult = gradeAnswer(
      user_answer_text,
      question.official_answer,
      question.marks || 1
    )

    // Insert attempt record
    const { data: attemptRecord, error: insertError } = await supabase
      .from('user_question_attempts')
      .insert({
        user_id,
        question_id,
        answer_text: user_answer_text,
        score: gradeResult.calculatedScore,
        is_correct: gradeResult.isCorrect,
        time_spent_seconds: time_spent || 0,
        hints_used: hints_count || 0,
        attempted_at: new Date().toISOString()
      })
      .select()
      .single()

    if (insertError) {
      console.error('Failed to insert attempt:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to save attempt', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        attempt_id: attemptRecord.id,
        score: gradeResult.calculatedScore,
        is_correct: gradeResult.isCorrect,
        max_marks: question.marks,
        feedback: generateFeedback(gradeResult)
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Placeholder grading function
 * TODO: Replace with actual AI/regex-based grading logic
 */
function gradeAnswer(
  userAnswer: string,
  officialAnswer: string | null,
  maxMarks: number
): { calculatedScore: number; isCorrect: boolean } {

  // If no official answer exists, can't grade
  if (!officialAnswer) {
    return {
      calculatedScore: 0,
      isCorrect: false
    }
  }

  // Normalize answers for comparison
  const normalizedUser = userAnswer.trim().toLowerCase()
  const normalizedOfficial = officialAnswer.trim().toLowerCase()

  // Simple exact match for now
  if (normalizedUser === normalizedOfficial) {
    return {
      calculatedScore: maxMarks,
      isCorrect: true
    }
  }

  // Partial credit: check if user answer contains key terms
  const officialWords = normalizedOfficial.split(/\s+/).filter(w => w.length > 3)
  const userWords = new Set(normalizedUser.split(/\s+/))

  const matchedWords = officialWords.filter(word => userWords.has(word))
  const matchPercentage = officialWords.length > 0
    ? matchedWords.length / officialWords.length
    : 0

  // Award partial marks based on match percentage
  const partialScore = Math.floor(maxMarks * matchPercentage)

  // Consider correct if >= 70% match
  const isCorrect = matchPercentage >= 0.7

  return {
    calculatedScore: partialScore,
    isCorrect
  }
}

/**
 * Generate user-facing feedback based on grade result
 */
function generateFeedback(gradeResult: { calculatedScore: number; isCorrect: boolean }): string {
  if (gradeResult.isCorrect) {
    return "Great job! Your answer is correct."
  } else if (gradeResult.calculatedScore > 0) {
    return "Partially correct. Review the official answer for more details."
  } else {
    return "Incorrect. Try reviewing the relevant topic and attempt again."
  }
}
