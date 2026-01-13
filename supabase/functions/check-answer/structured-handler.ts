// Handler for structured questions with multiple sub-parts

export async function handleStructuredQuestion(params: {
  questionId: string
  structuredAnswers: Array<{
    label: string
    studentAnswer: string
    officialAnswer: string | null
    marks: number
  }>
  userId?: string
  timeSpent?: number
  hintsUsed?: number
  supabase: any
  apiKey: string
  corsHeaders: any
}) {
  const { questionId, structuredAnswers, userId, timeSpent, hintsUsed, supabase, apiKey, corsHeaders } = params

  const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

  console.log(`🎯 Handling structured question: ${questionId}`)
  console.log(`📝 Total sub-parts to grade: ${structuredAnswers.length}`)
  for (const part of structuredAnswers) {
    console.log(`  - Part ${part.label}: ${part.marks} marks`)
  }

  // Get the question's ACTUAL total marks from the database
  const { data: questionData, error: questionError } = await supabase
    .from('questions')
    .select('marks')
    .eq('id', questionId)
    .single()

  if (questionError) {
    console.error('Error fetching question:', questionError)
    throw questionError
  }

  const questionTotalMarks = questionData?.marks || structuredAnswers.reduce((sum, p) => sum + p.marks, 0)
  console.log(`📊 Question total marks: ${questionTotalMarks}`)

  // Grade each sub-part
  const perPartResults = []
  let earnedMarks = 0

  for (const part of structuredAnswers) {
    if (!part.studentAnswer || part.studentAnswer.trim().length === 0) {
      perPartResults.push({
        label: part.label,
        isCorrect: false,
        score: 0,
        feedback: 'No answer provided'
      })
      continue
    }

    // Build prompt for this sub-part
    const prompt = `You are grading a student's answer for an exam question.

Question: ${part.label}
Official Answer: ${part.officialAnswer || 'Not provided'}
Student Answer: ${part.studentAnswer}
Maximum Marks: ${part.marks}

Grade the student's answer and provide constructive feedback. Your feedback should:
1. Explain WHY the answer is correct or incorrect
2. If incorrect, provide HINTS to help them understand (don't just give the answer)
3. Highlight what they got right (if partial credit applies)
4. Guide them toward the correct understanding

Return JSON in this exact format:
{
  "score": number (0-${part.marks}),
  "isCorrect": boolean (true if score >= 70% of max marks),
  "feedback": "Educational feedback explaining the reasoning, providing hints, and guiding understanding (2-3 sentences)"
}

Be fair, give partial credit, and focus on helping the student learn. Return ONLY valid JSON.`

    try {
      const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 512,
          }
        })
      })

      if (!geminiRes.ok) {
        throw new Error(`Gemini API error: ${geminiRes.status}`)
      }

      const geminiJson = await geminiRes.json()
      let rawText = geminiJson.candidates[0].content.parts[0].text

      // Clean markdown
      if (rawText.includes('```')) {
        rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
      }

      const result = JSON.parse(rawText)

      perPartResults.push({
        label: part.label,
        isCorrect: result.isCorrect ?? false,
        score: Math.min(part.marks, Math.max(0, result.score ?? 0)),
        feedback: result.feedback || 'Graded'
      })
      earnedMarks += result.score

    } catch (error) {
      console.error(`Error grading part ${part.label}:`, error)
      perPartResults.push({
        label: part.label,
        isCorrect: false,
        score: 0,
        feedback: 'Unable to grade this part'
      })
    }
  }

  // Calculate overall results using the QUESTION'S total marks, not just submitted parts
  const overallScore = questionTotalMarks > 0 ? Math.round((earnedMarks / questionTotalMarks) * 100) : 0
  const isCorrect = overallScore >= 70

  const response = {
    isCorrect,
    score: overallScore,
    feedback: `You scored ${earnedMarks}/${questionTotalMarks} marks (${overallScore}%)`,
    hints: [],
    strengths: perPartResults.filter(p => p.isCorrect).map(p => `Part ${p.label}: Correct!`),
    improvements: perPartResults.filter(p => !p.isCorrect).map(p => `Part ${p.label}: ${p.feedback}`),
    perPartResults,
    totalMarks: questionTotalMarks,
    earnedMarks
  }

  // Save attempt if userId provided
  if (userId) {
    try {
      const attemptData = {
        user_id: userId,
        question_id: questionId,
        answer_text: JSON.stringify(structuredAnswers.map(a => ({ [a.label]: a.studentAnswer }))),
        selected_option: null,
        score: overallScore,
        is_correct: isCorrect,
        time_spent_seconds: timeSpent || 0,
        hints_used: hintsUsed || 0,
        attempted_at: new Date().toISOString()
      }

      const { data: attemptRecord, error: insertError } = await supabase
        .from('user_question_attempts')
        .insert(attemptData)
        .select()
        .single()

      if (!insertError && attemptRecord) {
        response.attemptId = attemptRecord.id
        console.log(`✅ Structured question progress saved for user ${userId}`)
      }
    } catch (dbError) {
      console.error('Database error:', dbError)
    }
  }

  console.log(`✅ Structured grading complete:`)
  console.log(`   Total: ${earnedMarks}/${questionTotalMarks} marks (${overallScore}%)`)
  console.log(`   Per-part results:`, JSON.stringify(perPartResults, null, 2))

  return new Response(
    JSON.stringify(response),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
