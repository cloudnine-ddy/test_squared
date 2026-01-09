import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument } from 'https://esm.sh/pdf-lib@1.17.1'

// VERSION: 8.0 - BATCH PROCESSING (10 Pages/Chunk) + Compact Array Strategy
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent'
const BATCH_SIZE = 10; // Pages per batch

// Types for structured data
interface Topic {
  id: string
  name: string
}

// Compact Response Interface (Internal)
// [num, content, [topics], type, marks, [[lbl,txt]...], ans, rational, scan, fig_desc, [pg,x,y,w,h]]
type CompactQuestion = [
    number,             // 0: question_number
    string,             // 1: content
    string[],           // 2: topic_ids
    string,             // 3: type ("mcq" | "structured")
    number,             // 4: marks
    [string, string][], // 5: options [[label, text], ...] OR null
    string,             // 6: correct_answer
    string,             // 7: ai_rational (Solution explanation)
    string,             // 8: layout_scan
    string,             // 9: figure_description
    [number, number, number, number, number] | null // 10: figure [pg, x, y, w, h]
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

    console.log(`[DEBUG] Version 8.0 (Batching) - Paper type: "${paperType}"`)

    if (!paperId || !pdfUrl) {
      return new Response(JSON.stringify({ error: 'Missing paperId or pdfUrl' }), { status: 400, headers: corsHeaders })
    }

    const hasMarkScheme = !!markSchemeUrl

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const apiKey = Deno.env.get('GEMINI_API_KEY')

    if (!apiKey) return new Response(JSON.stringify({ error: 'GEMINI_API_KEY not configured' }), { status: 500, headers: corsHeaders })

    // Step 1: Get paper details
    const { data: paper, error: paperError } = await supabase.from('papers').select('subject_id').eq('id', paperId).single()
    if (paperError || !paper) return new Response(JSON.stringify({ error: 'Paper not found' }), { status: 404, headers: corsHeaders })

    // Step 2: Fetch topics
    const { data: topics } = await supabase.from('topics').select('id, name').eq('subject_id', paper.subject_id)
    const topicsList: Topic[] = topics || []
    const topicsJson = JSON.stringify(topicsList.map(t => ({ id: t.id, name: t.name })))

    // Step 3: Download PDF & Prepare Batches
    console.log(`Downloading PDF: ${pdfUrl}`)
    const pdfResponse = await fetch(pdfUrl)
    if (!pdfResponse.ok) return new Response(JSON.stringify({ error: 'Failed to download PDF' }), { status: 500, headers: corsHeaders })
    const pdfArrayBuffer = await pdfResponse.arrayBuffer()

    // Load PDF with pdf-lib
    const srcDoc = await PDFDocument.load(pdfArrayBuffer)
    const totalPages = srcDoc.getPageCount()
    console.log(`Total Pages: ${totalPages}. processing in batches of ${BATCH_SIZE}...`)

    let allQuestions: CompactQuestion[] = []

    // BATCH LOOP
    for (let i = 0; i < totalPages; i += BATCH_SIZE) {
        const startPage = i + 1;
        const endPage = Math.min(i + BATCH_SIZE, totalPages);
        console.log(`Processing Batch: Pages ${startPage}-${endPage}...`);

        // Create Sub-PDF
        const subDoc = await PDFDocument.create();
        const pageIndices = [];
        for (let j = 0; j < (endPage - startPage + 1); j++) pageIndices.push(i + j);

        const copiedPages = await subDoc.copyPages(srcDoc, pageIndices);
        copiedPages.forEach(p => subDoc.addPage(p));
        const subPdfBytes = await subDoc.saveAsBase64();

        // Prompt Logic (Same as V7, but aware of batching)
        const objectivePrompt = `You are a Biology MCQ exam analyzer (Batch ${startPage}-${endPage}).
CRITICAL: "The diagram shows..." = HAS IMAGE.
OUTPUT JSON (COMPACT ARRAY):
{ "d": [ [1, "Content", ["uuid"], "mcq", 1, [["A","Txt"]], "B", "Rationale", "Scan", "FigDesc", [1,20,30,50,40]] ] }
TOPICS: ${topicsJson}
RULES: 1. Extract questions ONLY from these pages. 2. Compact Arrays. 3. Solve (ans+rational). 4. Figure% relative to these pages.`

        const subjectivePrompt = `You are a Biology structured question analyzer (Batch ${startPage}-${endPage}).
OUTPUT JSON (COMPACT ARRAY):
{ "d": [ [1, "Content", ["uuid"], "structured", 6, null, null, null, "Scan", "FigDesc", [1,20,30,50,40]] ] }
TOPICS: ${topicsJson}
RULES: 1. Extract max questions. 2. Compact Arrays.`

        const prompt = isObjective ? objectivePrompt : subjectivePrompt

        // Gemini Call
        try {
            const geminiRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: "application/pdf", data: subPdfBytes } }] }],
                    generationConfig: { temperature: 0.1, maxOutputTokens: 16384, responseMimeType: "application/json" }
                })
            })

            if (!geminiRes.ok) throw new Error(`Gemini Error Batch ${startPage}-${endPage}: ${await geminiRes.text()}`)
            const geminiJson = await geminiRes.json()
            let rawText = geminiJson.candidates?.[0]?.content?.parts?.[0]?.text || ''
            if (rawText.includes('```')) rawText = rawText.replace(/```json/g, '').replace(/```/g, '').trim()

            // Basic Repair Logic if needed (same as V7)
            let rawData: any = {};
            try { rawData = JSON.parse(rawText) } catch(e) {
                 // Minimal repair try
                 let repaired = rawText.replace(/"([^"\\]*(\\.[^"\\]*)*)"/g, (m) => m.replace(/\n/g, '\\n'));
                 try { rawData = JSON.parse(repaired) } catch(err) { console.warn(`Batch ${startPage}-${endPage} parse fail`, err); }
            }

            const batchQs = (rawData.d || rawData.questions || (Array.isArray(rawData) ? rawData : [])) as CompactQuestion[];
            if (batchQs.length) {
                console.log(`Batch ${startPage}-${endPage}: Extracted ${batchQs.length} questions`);

                // ADJUST PAGE NUMBERS
                // Gemini sees a 5-page PDF (pages 1-5). But they are actually Pages 11-15 of the original.
                // We must Offset: RealPage = GeminiPage + (startPage - 1)
                const offsetQs = batchQs.map(q => {
                   // Clone row to avoid mutation side effects if any
                   const newQ: CompactQuestion = [...q];
                   // Fix Figure Page if it exists
                   // Index 10 is [pg, x, y, w, h]
                   if (Array.isArray(newQ[10]) && newQ[10].length >= 1) {
                        newQ[10][0] = newQ[10][0] + (startPage - 1);
                   }
                   return newQ;
                }) as CompactQuestion[];

                allQuestions = [...allQuestions, ...offsetQs];
            }
        } catch (batchErr) {
            console.error(`Error processing batch ${startPage}-${endPage}:`, batchErr);
            // Continue to next batch, don't fail whole request
        }
    }

    console.log(`Total Extracted Questions: ${allQuestions.length}`);

    // Step 6: Data Transformation (Compact Array -> Database Object)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    const questionsToInsert = allQuestions.map(row => {
        if (!Array.isArray(row)) return null;

        // TRANSFORM OPTIONS
        let formattedOptions: {label: string, text: string}[] | null = null;
        if (Array.isArray(row[5])) {
            formattedOptions = row[5].map(opt => {
                if (Array.isArray(opt) && opt.length >= 2) return { label: opt[0], text: opt[1] };
                return { label: "?", text: String(opt) };
            });
        }

        // Parse Figure (Index 10)
        const figArr = row[10];
        const figureData = (Array.isArray(figArr) && figArr.length >= 5) ? {
            page: figArr[0], x: figArr[1], y: figArr[2], width: figArr[3], height: figArr[4]
        } : undefined;

        const layoutScan = row[8] || "No scan provided";
        const figDesc = row[9] || (figureData ? "Figure detected" : null);
        const aiRational = row[7] || null;

        // Figure Metadata
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
            },
            ai_solution: aiRational
        } : {
            has_figure: false,
            layout_scan: layoutScan,
            ai_solution: aiRational
        };

        return {
            paper_id: paperId,
            question_number: row[0],
            content: row[1],
            topic_ids: (row[2] || []).filter(id => uuidRegex.test(id)),
            type: row[3] || "mcq",
            options: formattedOptions,
            correct_answer: row[6],
            marks: row[4] || 1,
            ai_answer: figureMetadata,
            official_answer: null,
            image_url: null
        };
    }).filter(q => q !== null);

    // UNIQUE FILTER: In case overlap causes duplicates or hallucinations
    // Filter by question_number
    const uniqueQuestions = [];
    const seenNumbers = new Set();
    for (const q of questionsToInsert) {
        if (!seenNumbers.has(q.question_number)) {
            seenNumbers.add(q.question_number);
            uniqueQuestions.push(q);
        }
    }

    console.log(`Transformed ${uniqueQuestions.length} unique questions.`);

    // Step 7: Batch Insert
    const { data: insertedQuestions, error: insertError } = await supabase.from('questions').insert(uniqueQuestions).select('id, question_number');
    if (insertError) throw insertError;

    // Step 8: Crop Figures
    let figsCropped = 0;
    const questionsWithFigures = uniqueQuestions.filter(q => q.ai_answer.has_figure);
    if (insertedQuestions && questionsWithFigures.length) {
        console.log(`Processing ${questionsWithFigures.length} figures...`);
        for (const q of questionsWithFigures) {
            const insertedQ = insertedQuestions.find(iq => iq.question_number === q.question_number);
            if (!insertedQ) continue;

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

                // Convert to Base64 (Standard chunking helper)
                function toBase64(u8: Uint8Array) {
                   let b = ''; const l=u8.length;
                   for(let i=0;i<l;i+=32768) b+=String.fromCharCode(...u8.subarray(i,i+32768));
                   return btoa(b);
                }
                const msBase64 = toBase64(new Uint8Array(msArrayBuffer));

                const msPrompt = `Extract OFFICIAL ANSWERS from mark scheme.
OUTPUT JSON: { "answers": [ {"question_number": 1, "official_answer": "B", "marks": 1} ] }`

                const msGemini = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: msPrompt }, { inline_data: { mime_type: 'application/pdf', data: msBase64 } }] }],
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
                            const solPrompt = `You are a helpful tutor. A student asked Q${ans.question_number}.
Question: ${uniqueQuestions.find(q => q.question_number === ans.question_number)?.content || 'See paper'}
Official Answer: ${ans.official_answer}

Create a clear 3-4 sentence explanation/solution explaining WHY this answer is correct.
STRICTLY NO CONVERSATIONAL FILLER. Start directly with the explanation.`;

                            const solRes = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
                                method: 'POST',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify({ contents: [{ parts: [{ text: solPrompt }] }] })
                            });

                            let solText = null;
                            if (solRes.ok) {
                                const solJson = await solRes.json();
                                solText = solJson.candidates?.[0]?.content?.parts?.[0]?.text;
                            } else {
                                console.warn(`Solution generation failed for Q${ans.question_number}: ${solRes.status}`);
                            }

                            // Get existing AI rational to fallback if solText is null
                            const existingRational = uniqueQuestions.find(q => q.question_number === ans.question_number)?.ai_answer?.ai_solution;

                            // Update
                            await supabase.from('questions').update({
                                official_answer: ans.official_answer,
                                marks: ans.marks,
                                ai_answer: {
                                    ...uniqueQuestions.find(q => q.question_number === ans.question_number)?.ai_answer,
                                    marks: ans.marks,
                                    ai_solution: solText || existingRational // Prefer new solution, fallback to batch rational
                                }
                            }).eq('id', qMatch.id);
                            answersExtracted++;

                            // Rate Limit Delay (500ms) to avoid hitting Gemini limits during loop
                            await new Promise(resolve => setTimeout(resolve, 500));
                        }
                    }
                }
            }
        } catch (e) { console.warn("Market scheme error", e); }
    }

    return new Response(JSON.stringify({
        success: true,
        message: `Extracted ${uniqueQuestions.length} questions`,
        figures_cropped: figsCropped,
        answers_extracted: answersExtracted
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (error) {
    console.error('Fatal:', error)
    return new Response(JSON.stringify({ error: 'Unexpected error', details: String(error) }), { status: 500, headers: corsHeaders })
  }
})