import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent'

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

    // Fetch the question from database with ALL context
    console.log(`🔍 Fetching question ${questionId}...`)

    const { data: question, error: questionError } = await supabaseClient
      .from('questions')
      .select('content, official_answer, ai_answer, marks, type, image_url, options, correct_answer, structure_data')
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
      // Build context based on question type
      let generationPrompt = '';

      if (question.type === 'mcq') {
        // MCQ Generation
        generationPrompt = `You are an expert IGCSE/GCSE exam setter.
Your task: Create a NEW Multiple Choice Question similar to the one provided below.
The new question must test similar concepts but use different values, context, or scenarios.

ORIGINAL MCQ QUESTION:
${question.content}
${question.image_url ? `\nIMAGE: ${question.image_url}` : ''}

ORIGINAL OPTIONS:
${question.options ? question.options.map((opt: any) => `${opt.label}) ${opt.text}`).join('\n') : ''}

CORRECT ANSWER: ${question.correct_answer}
MARKS: ${question.marks}

INSTRUCTIONS:
1. Create a NEW question text using standard Markdown (**bold**, *italic*).
2. DO NOT reference figures, diagrams, or images (e.g., "Fig 1.1 shows...") - make questions text-only
3. Generate 4 plausible options (A, B, C, D) - make distractors realistic
4. Clearly identify the correct answer (A, B, C, or D)
5. Provide a brief explanation of why the answer is correct
6. Match the difficulty level and topic of the original
7. Return ONLY a JSON object. Do not include markdown formatting like \`\`\`json.

JSON Structure:
{
  "type": "mcq",
  "content": "The question text here with **bold keywords**.",
  "options": [
    {"text": "Option A text", "label": "A"},
    {"text": "Option B text", "label": "B"},
    {"text": "Option C text", "label": "C"},
    {"text": "Option D text", "label": "D"}
  ],
  "correct_answer": "A",
  "marks": ${question.marks || 1},
  "explanation": "Brief explanation of the correct answer.",
  "topic": "Topic Name",
  "syllabus_level": "IGCSE"
}

Verify the output is valid JSON.`;
      } else {
        // Structured Question Generation
        const structuredParts = question.structure_data
          ? question.structure_data.filter((block: any) => block.type === 'question_part')
          : [];

        generationPrompt = `You are an expert IGCSE/GCSE exam setter.
Your task: Create a NEW Structured Question similar to the one provided below.
The new question must test similar concepts but use different values, context, or scenarios.

ORIGINAL STRUCTURED QUESTION:
${question.content}
${question.image_url ? `\nIMAGE: ${question.image_url}` : ''}

ORIGINAL PARTS:
${structuredParts.map((part: any) => `Part ${part.label}: ${part.content} [${part.marks} marks]`).join('\n')}

TOTAL MARKS: ${question.marks}

INSTRUCTIONS:
1. Create a NEW question with the SAME STRUCTURE (same number of parts, similar labels)
2. DO NOT reference figures, diagrams, or images (e.g., "Fig 1.1 shows...") - make questions text-only
3. Each part should test similar concepts but with different context
4. Maintain the same marks allocation per part
5. Use standard Markdown (**bold**, *italic*)
6. Provide official answers for each part
7. Return ONLY a JSON object. Do not include markdown formatting like \`\`\`json.

JSON Structure:
{
  "type": "structured",
  "content": "Main question text/context here.",
  "structure_data": [
    {
      "type": "text",
      "content": "Introduction or context text"
    },
    {
      "type": "question_part",
      "label": "(a)",
      "content": "Part (a) question text",
      "marks": 2,
      "official_answer": "Expected answer for part (a)"
    },
    {
      "type": "question_part",
      "label": "(b)(i)",
      "content": "Part (b)(i) question text",
      "marks": 3,
      "official_answer": "Expected answer for part (b)(i)"
    }
  ],
  "marks": ${question.marks},
  "topic": "Topic Name",
  "syllabus_level": "IGCSE"
}

CRITICAL: Match the structure of the original question - if it has parts (a), (b)(i), (b)(ii), your generated question should have the same structure.

Verify the output is valid JSON.`;
      }

      systemPrompt = generationPrompt;
    } else {
      // Build comprehensive question context
      let questionContext = `QUESTION:\n${question.content}\n`;

      // Add image if exists
      if (question.image_url) {
        questionContext += `\nIMAGE/DIAGRAM: ${question.image_url}\n(Student can see this image - refer to it in your explanations)\n`;
      }

      // Add MCQ options if it's an MCQ
      if (question.type === 'mcq' && question.options && Array.isArray(question.options)) {
        questionContext += `\nOPTIONS:\n`;
        question.options.forEach((opt: any) => {
          questionContext += `${opt.label}) ${opt.text}\n`;
        });
        questionContext += `\nCORRECT ANSWER: ${question.correct_answer}\n(Use this to guide your hints, but DO NOT reveal directly)\n`;
      }

      // Add structured parts if it's a structured question
      if (question.structure_data && Array.isArray(question.structure_data)) {
        questionContext += `\nQUESTION PARTS:\n`;
        const parts = question.structure_data.filter((block: any) => block.type === 'question_part');
        parts.forEach((part: any) => {
          questionContext += `\nPart ${part.label}: ${part.content} [${part.marks} mark${part.marks > 1 ? 's' : ''}]\n`;
          if (part.official_answer) {
            questionContext += `  Official Answer: ${part.official_answer}\n`;
          }
          if (part.ai_answer) {
            questionContext += `  AI Explanation: ${part.ai_answer}\n`;
          }
        });
        questionContext += `\n(Use these reference answers to ensure accuracy, but guide students to discover answers themselves)\n`;
      } else if (question.official_answer) {
        // Regular question with single official answer
        questionContext += `\nOFFICIAL ANSWER/KEY CONCEPTS:\n${question.official_answer}\n`;
        if (question.ai_answer) {
          questionContext += `\nAI EXPLANATION:\n${question.ai_answer}\n`;
        }
        questionContext += `(Use these as reference, but DO NOT reveal directly - guide students to discover)\n`;
      }

      if (question.marks) {
        questionContext += `\nTOTAL MARKS: ${question.marks}\n`;
      }

      // Standard Chat Prompt with enhanced context
      systemPrompt = `You are a helpful, encouraging AI tutor for IGCSE/GCSE students. Your role is to GUIDE learning, not give direct answers.

${questionContext}

${userAnswer ? `
STUDENT'S SUBMITTED ANSWER:
${userAnswer}
${userScore !== undefined ? `Score received: ${userScore}%` : ''}

NOTE: The student has already attempted this question. They may ask:
- Why their answer was wrong or incomplete
- What they missed
- How to improve their answer
When answering, compare their answer to the reference answers and provide specific, constructive feedback.
` : ''}

CRITICAL RULES:
1. NEVER give direct answers - guide students to discover them
2. If asked directly for the answer, politely refuse and offer hints instead
3. Use Socratic questioning to develop critical thinking
4. Break down complex concepts into simpler parts
5. Provide relevant examples and analogies
6. Check understanding with follow-up questions
7. Stay focused on the question topic - redirect if student gets off-track
8. Be encouraging and supportive
9. Use the reference answers to ensure your guidance is accurate
10. For MCQs, help eliminate wrong options through reasoning
11. For structured questions, help with specific parts the student asks about

APPROACH:
- Identify what the student is struggling with
- Ask guiding questions
- Explain underlying concepts
- Suggest problem-solving strategies
- Provide hints that lead to discovery
- Celebrate progress and understanding

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
