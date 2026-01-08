import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// VERSION: 5.0 - Hybrid Strategy (Compact Prompt + Object Transformation)
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'

// Types for structured data
interface Topic {
  id: string
  name: string
}

interface FigureBbox {
  page: number
  x: number
  y: number
  width: number
  height: number
}

interface ExtractedQuestion {
  question_number: number
  content: string
  topic_ids: string[]
  type: 'structured' | 'mcq'
  marks?: number
  options?: { label: string; text: string }[]
  correct_answer?: string
  layout_scan?: string | null
  figure_description?: string | null
  figure?: FigureBbox
}

// Compact Response Interface (Internal)
type CompactQuestion = [
    number,             // 0: question_number
    string,             // 1: content
    string[],           // 2: topic_ids
    string,             // 3: type ("mcq" | "structured")
    number,             // 4: marks
    [string, string][], // 5: options [[label, text], ...] OR null
    string,             // 6: correct_answer
    [number, number, number, number, number] | null, // 7: figure [pg, x, y, w, h]
    string,             // 8: layout_scan
    string              // 9: figure_description
]

interface CompactResponse {
    d: CompactQuestion[]
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

    if (!paperId || !pdfUrl) {
      return new Response(JSON.stringify({ error: 'Missing paperId or pdfUrl' }), { status: 400, headers: corsHeaders })
    }

    const hasMarkScheme = !!markSchemeUrl

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) {
        return new Response(JSON.stringify({ error: 'GEMINI_API_KEY not configured' }), { status: 500, headers: corsHeaders })
    }

    // Step 1: Get paper details
    const { data: paper, error: paperError } = await supabase.from('papers').select('subject_id').eq('id', paperId).single()
    if (paperError || !paper) return new Response(JSON.stringify({ error: 'Paper not found' }), { status: 404, headers: corsHeaders })

    // Step 2: Fetch topics
    const { data: topics } = await supabase.from('topics').select('id, name').eq('subject_id', paper.subject_id)
    const topicsList: Topic[] = topics || []
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    // Step 3: Download PDF
    console.log(`Downloading PDF: ${pdfUrl}`)
    const pdfResponse = await fetch(pdfUrl)
    if (!pdfResponse.ok) return new Response(JSON.stringify({ error: 'Failed to download PDF' }), { status: 500, headers: corsHeaders })
    const pdfBlob = await pdfResponse.blob()
    const arrayBuffer = await pdfBlob.arrayBuffer()
    const pdfBytes = new Uint8Array(arrayBuffer)

    // Chunked conversion to avoid RangeError (Stack Overflow)
    let binary = ''
    const len = pdfBytes.byteLength
    for (let i = 0; i < len; i += 32768) {
      binary += String.fromCharCode(...pdfBytes.subarray(i, i + 32768))
    }
    const base64Data = btoa(binary)

    // Step 4: Prompt Engineering (COMPACT)
    // We use a compact array format to maximize question count, but we will transform strict logic later.
    const objectivePrompt = `You are a Biology MCQ exam analyzer.
CRITICAL: "The diagram shows..." = HAS IMAGE.

OUTPUT JSON (COMPACT ARRAY):
{
  "d": [ // [num, content, [topics], "mcq", marks, [[label,text]...], ans, [pg,x,y,w,h]|null, "scan", "fig_desc"]
    [99, "Which structure?", ["uuid"], "mcq", 1, [["A","Nucleus"],["B","Cell"]], "B", [1,20,30,50,40], "Found 99. Diagram above.", "Cell diagram"]
  ]
}

TOPICS: ${topicsJson}

RULES:
1. MAXIMIZE EXTRACTION (Target 40+ Qs).
2. Options: Array of arrays [["Label", "Text"]].
3. Figure: [pg, x, y, w, h] (Percentages 0-100).
4. Layout Scan: Brief text describing layout.
5. Content: Text only.
`
    const subjectivePrompt = `You are a Biology structured question analyzer.
OUTPUT JSON (COMPACT ARRAY):
{
  "d": [ // [num, content, [topics], "structured", marks, null, null, [pg,x,y,w,h]|null, "scan", "fig_desc"]
    [1, "(a) Define X. (b) Explain Y.", ["uuid"], "structured", 6, null, null, [1,20,30,50,40], "Found 1. Diagram above.", "Cell diagram"]
  ]
}
TOPICS: ${topicsJson}
RULES: 1. Maximize extraction. 2. Combine sub-parts. 3. Figure percentages.`

    const prompt = isObjective ? objectivePrompt : subjectivePrompt

    // Step 5: Gemini Call
    console.log('Sending to Gemini...')
    const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: "application/pdf", data: base64Data } }] }],
            generationConfig: { temperature: 0.1, maxOutputTokens: 16384, responseMimeType: "application/json" }
        })
    })

    if (!geminiRes.ok) throw new Error(`Gemini API Error: ${await geminiRes.text()}`)
    const geminiJson = await geminiRes.json()
    let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || ''

    // Parsing & Repair
    let rawData: any = {};
    if (rawText.includes('```')) rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()

    try {
        rawData = JSON.parse(rawText)
    } catch (e) {
        console.log('Parse failed, attempting repair...')
        // 1. Unescape
        let repaired = rawText.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (m) => m.replace(/\n/g, '\\n'))
        // 2. Stack Repair
        const stack: string[] = [];
        let inString = false;
        for (let i = 0; i < repaired.length; i++) {
            const char = repaired[i];
            if (inString) { if (char === '"' && repaired[i-1] !== '\\') inString = false; }
            else {
                if (char === '"') inString = true;
                else if (char === '{') stack.push('}');
                else if (char === '[') stack.push(']');
                else if (char === '}' || char === ']') if (stack.length) stack.pop();
            }
        }
        if (inString) repaired += '"';
        while (stack.length) repaired += stack.pop();

        try { rawData = JSON.parse(repaired) }
        catch (finalErr) {
             console.error("Critical Parse Fail:", finalErr);
             throw new Error("Failed to parse AI response.")
        }
    }

    // Step 6: Data Transformation (Compact Array -> Database Object)
    const questionsArray = (rawData.d || rawData.questions || (Array.isArray(rawData) ? rawData : [])) as CompactQuestion[];
    if (!questionsArray.length) console.warn("No questions extracted.");

    const questionsToInsert = questionsArray.map(row => {
        // Validate Row
        if (!Array.isArray(row)) return null;

        // TRANSFORM OPTIONS: [["A", "Text"], ["B", "Text"]] -> [{label:"A", text:"Text"}, {label:"B", text:"Text"}]
        let formattedOptions: {label: string, text: string}[] | null = null;
        if (Array.isArray(row[5])) {
            formattedOptions = row[5].map(opt => {
                if (Array.isArray(opt) && opt.length >= 2) return { label: opt[0], text: opt[1] };
                return { label: "?", text: String(opt) }; // Fallback
            });
        }

        // Parse Figure
        const figureData = Array.isArray(row[7]) ? {
            page: row[7][0], x: row[7][1], y: row[7][2], width: row[7][3], height: row[7][4]
        } : undefined;

        const layoutScan = row[8] || "No scan provided";
        const figDesc = row[9] || (figureData ? "Figure detected" : null);

        // Figure Metadata for AI Answer
        const figureMetadata = figureData ? {
            has_figure: true,
            layout_scan: layoutScan,
            figure_description: figDesc,
            figure_location: {
                page: figureData.page,
                x_percent: figureData.x,
                y_percent: figureData.y,
                width_percent: figureData.width,
                height_percent: figureData.height
            }
        } : { has_figure: false, layout_scan: layoutScan };

        return {
            paper_id: paperId,
            question_number: row[0],
            content: row[1],
            topic_ids: (row[2] || []).filter(id => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)),
            type: row[3] || "mcq",
            options: formattedOptions, // CORRECTLY TRANSFORMED OBJECT ARRAY
            correct_answer: row[6],
            marks: row[4] || 1,
            ai_answer: figureMetadata,
            official_answer: null,
            image_url: null
        };
    }).filter(q => q !== null);

    console.log(`Transformed ${questionsToInsert.length} questions.`);

    // Step 7: Batch Insert
    const { data: insertedQuestions, error: insertError } = await supabase.from('questions').insert(questionsToInsert).select('id, question_number');
    if (insertError) throw insertError;

    // Step 8: Crop Figures (PDF.co)
    let figsCropped = 0;
    const questionsWithFigures = questionsToInsert.filter(q => q.ai_answer.has_figure);
    if (insertedQuestions && questionsWithFigures.length) {
        console.log(`Processing ${questionsWithFigures.length} figures...`);
        for (const q of questionsWithFigures) {
            const insertedQ = insertedQuestions.find(iq => iq.question_number === q.question_number);
            if (!insertedQ) continue;

            // Fire & Forget cropping to speed up response? No, let's await for reliability.
            try {
                const cropRes = await fetch(`${supabaseUrl}/functions/v1/crop-figure`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${supabaseKey}`, 'apikey': supabaseKey },
                    body: JSON.stringify({
                        pdfUrl, questionId: insertedQ.id, page: q.ai_answer.figure_location.page,
                        bbox: {
                            x: q.ai_answer.figure_location.x_percent, y: q.ai_answer.figure_location.y_percent,
                            width: q.ai_answer.figure_location.width_percent, height: q.ai_answer.figure_location.height_percent
                        }
                    })
                });
                if (cropRes.ok) figsCropped++;
            } catch (e) { console.warn(`Crop failed Q${q.question_number}`, e); }
        }
    }

    // Step 9: Mark Scheme
    let answersExtracted = 0;
    if (hasMarkScheme && insertedQuestions) {
        console.log('Processing Mark Scheme...');
        try {
            const msRes = await fetch(markSchemeUrl);
            if (msRes.ok) {
                const msBlob = await msRes.blob()
                const msArrayBuffer = await msBlob.arrayBuffer()
                const msBytes = new Uint8Array(msArrayBuffer)
                let msBinary = ''
                for (let i = 0; i < msBytes.byteLength; i += 32768) {
                    msBinary += String.fromCharCode(...msBytes.subarray(i, i + 32768))
                }
                const msData = btoa(msBinary)

                const msPrompt = `Extract OFFICIAL ANSWERS from mark scheme.
OUTPUT JSON: { "answers": [ {"question_number": 1, "official_answer": "B", "marks": 1} ] }`

                const msGemini = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: msPrompt }, { inline_data: { mime_type: 'application/pdf', data: msData } }] }],
                        generationConfig: { temperature: 0.1, maxOutputTokens: 8192, responseMimeType: "application/json" }
                    })
                });

                if (msGemini.ok) {
                    const msJson = await msGemini.json();
                    const msText = msJson.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
                    const msParsed = JSON.parse(msText.replace(/```json|```/g, '').trim());

                    for (const ans of msParsed.answers || []) {
                        const qMatch = insertedQuestions.find(q => q.question_number === ans.question_number);
                        if (qMatch) {
                            // Solution Generation
                            const solPrompt = `Explain solution for Q${ans.question_number}. Answer: ${ans.official_answer}. Concise (3-4 sentences).`;
                            const solRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                                method: 'POST',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify({ contents: [{ parts: [{ text: solPrompt }] }] })
                            });
                            let solText = null;
                            if (solRes.ok) {
                                const solJson = await solRes.json();
                                solText = solJson.candidates?.[0]?.content?.parts?.[0]?.text;
                            }

                            // Update
                            await supabase.from('questions').update({
                                official_answer: ans.official_answer,
                                ai_answer: {
                                    ...questionsToInsert.find(q => q.question_number === ans.question_number)?.ai_answer,
                                    marks: ans.marks,
                                    ai_solution: solText
                                }
                            }).eq('id', qMatch.id);
                            answersExtracted++;
                        }
                    }
                }
            }
        } catch (e) { console.warn("Market scheme error", e); }
    }

    return new Response(JSON.stringify({
        success: true,
        message: `Extracted ${questionsToInsert.length} questions`,
        figures_cropped: figsCropped,
        answers_extracted: answersExtracted
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (error) {
    console.error('Fatal:', error)
    return new Response(JSON.stringify({ error: 'Unexpected error', details: String(error) }), { status: 500, headers: corsHeaders })
  }
})