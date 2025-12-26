import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent'

Deno.serve(async (req) => {
  const { paperId, pdfUrl } = await req.json()
  
  if (!paperId || !pdfUrl) {
    return new Response("Missing paperId or pdfUrl", { status: 400 })
  }

  // 初始化 Supabase
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const supabase = createClient(supabaseUrl, supabaseKey)
  const apiKey = Deno.env.get('GEMINI_API_KEY')

  console.log(`Analyzing Paper (Merged Mode): ${paperId}`)

  // --- 关键修改：新的 Prompt 指令 ---
  const prompt = `
    You are an exam paper parser.
    Analyze the attached PDF exam paper.
    
    GOAL: Extract the MAIN questions (1, 2, 3, 4...).
    
    RULES:
    1. If a question has sub-parts (like a, b, i, ii), DO NOT split them.
    2. Combine all sub-parts text into a SINGLE "content" field for that main question number.
    3. Example: If Question 1 has part (a) and (b), the output should be ONE object for "1", containing the text for both (a) and (b).
    4. Return ONLY a valid JSON array.
    
    Target JSON Structure:
    [
      {
        "question_number": "1",
        "content": "Full text of question 1, including part a and b...",
        "max_marks": 10
      },
      {
        "question_number": "2",
        "content": "Full text of question 2...",
        "max_marks": 5
      }
    ]
  `

  // 下载 PDF 转 Base64
  const pdfResponse = await fetch(pdfUrl)
  const pdfBlob = await pdfResponse.blob()
  const arrayBuffer = await pdfBlob.arrayBuffer()
  const base64Data = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)))

  // 发送给 Gemini
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
    }]
  }

  console.log("Sending to Gemini (Grouped Mode)...")
  const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(geminiPayload)
  })

  const geminiJson = await geminiRes.json()
  
  try {
    const rawText = geminiJson.candidates[0].content.parts[0].text
    const cleanJson = rawText.replace(/```json/g, '').replace(/```/g, '').trim()
    const questionsData = JSON.parse(cleanJson)

    console.log(`Extracted ${questionsData.length} MAIN questions. Inserting...`)

    const rowsToInsert = questionsData.map((q: any) => ({
      paper_id: paperId,
      // 强制把题号转成字符串，防止数据库报错
      question_number: String(q.question_number), 
      content: q.content,
      // 如果你的表里没有 max_marks 列，把下面这行删掉！
      // max_marks: q.max_marks 
    }))

    const { error: insertError } = await supabase
      .from('questions')
      .insert(rowsToInsert)

    if (insertError) throw insertError

    return new Response(JSON.stringify({ success: true, count: questionsData.length }), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (err) {
    console.error("Error:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})