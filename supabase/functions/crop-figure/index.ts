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
    const rawReq = await req.json()
    console.log('[Webhook] Received Payload:', JSON.stringify(rawReq, null, 2))

    // Handle Supabase Webhook Payload
    const record = rawReq.record
    if (!record) throw new Error('No record found in payload')

    const questionId = record.id
    const paperId = record.paper_id
    const aiAnswer = record.ai_answer

    // Checks
    if (!questionId || !paperId) throw new Error('Missing ID or Paper ID')

    // Check for either figure or table
    // Support new 'figures' array or legacy fields
    const hasFigures = aiAnswer.figures && aiAnswer.figures.length > 0;
    const hasLegacyFigure = aiAnswer.has_figure;
    const hasLegacyTable = aiAnswer.has_table;

    if (!hasFigures && !hasLegacyFigure && !hasLegacyTable) {
      console.log(`[Skip] Question ${questionId} has no figure or table.`)
      return new Response(JSON.stringify({ message: 'Skipped - No Figure/Table' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    let locationData;

    if (hasFigures) {
        // Use the first figure for the main image_url
        // TODO: Support multiple images in future
        locationData = aiAnswer.figures[0].boundingBox;
    } else {
        const isTable = !!aiAnswer.has_table;
        locationData = isTable ? aiAnswer.table_location : aiAnswer.figure_location;
    }

    if (!locationData) {
       console.log(`[Skip] Question ${questionId} marked as having figure/table but missing location data.`)
       return new Response(JSON.stringify({ message: 'Skipped - Missing Location Data' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Map new schema (x,y,width,height) or legacy (x_percent...)
    // locationData from analyze-paper (new) is { x, y, width, height, page, page_width, page_height } (PDF Points)
    // legacy is { x_percent, y_percent ... }

    let page, pX, pY, pW, pH, sourceW, sourceH;

    if (locationData.x !== undefined) {
        // New Schema (Points)
        page = locationData.page;
        pX = locationData.x;
        pY = locationData.y;
        pW = locationData.width;
        pH = locationData.height;
        sourceW = locationData.page_width;
        sourceH = locationData.page_height;
    } else {
        // Legacy Schema (Percent)
        page = locationData.page;
        sourceW = locationData.source_page_width || 595; // Fallback
        sourceH = locationData.source_page_height || 842;

        pX = (locationData.x_percent / 100) * sourceW;
        pY = (locationData.y_percent / 100) * sourceH;
        pW = (locationData.width_percent / 100) * sourceW;
        pH = (locationData.height_percent / 100) * sourceH;
    }

    console.log(`[Start] Processing Q${questionId} (Page ${page})`)
    console.log(`[Dims] Page: ${sourceW}x${sourceH}`)
    // console.log(`[BBox] x=${x_percent}%, y=${y_percent}%, w=${width_percent}%, h=${height_percent}%`) - Removed old log

    if (!sourceW || !sourceH) {
       throw new Error('Missing source page dimensions in metadata')
    }

    // Initialize Supabase & API Keys
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    const pdfCoApiKey = Deno.env.get('PDF_CO_API_KEY')

    if (!pdfCoApiKey) throw new Error('PDF_CO_API_KEY not set')

    // --- STEP 1: Fetch PDF URL ---
    const { data: paperData, error: paperError } = await supabase
      .from('papers')
      .select('pdf_url')
      .eq('id', paperId)
      .single()

    if (paperError || !paperData) throw new Error('Failed to fetch paper PDF URL')
    const pdfUrl = paperData.pdf_url
    console.log(`[PDF] URL: ${pdfUrl}`)

    // --- STEP 2: Calculate Rect for PDF.co ---
    // PDF.co 'rect' format: x,y,width,height string
    // Coordinates are in points (or whatever unit the source PDF uses).
    // Since we extracted dimensions via pdf-lib (points), we should map percentages back to points.

    // Safety Padding (e.g., 5% extra or fixed amount? User said "20px" in previous logic,
    // but that was pixels on a raster. Let's add a small relative buffer or stick to strict bbox if "Remove Hardcoded Dimensions" implies precision.)
    // User instruction: "Remove Hardcoded Dimensions ... stop using 595 and 842. Instead ... accept pageWidth and pageHeight"
    // User instruction: "Refine Math: Use the actual dimensions to calculate the rectString for PDF.co"

    // Dimensions are already in points (pX, pY...), no need to convert from % if using new schema.
    // Logic above unified pX/pY calculation.

    // Safety Padding (10pt)
    const PADDING = 10
    const finalX = Math.max(0, pX - PADDING)
    const finalY = Math.max(0, pY - PADDING)
    const finalW = Math.min(sourceW - finalX, pW + (PADDING * 2))
    const finalH = Math.min(sourceH - finalY, pH + (PADDING * 2))

    const rectString = `${finalX},${finalY},${finalW},${finalH}`
    console.log(`[Math] Rect Calculation:`)
    console.log(`       Raw Points: ${pX}, ${pY}, ${pW}, ${pH}`)
    console.log(`       Final Rect: ${rectString}`)

    // --- STEP 3: Render & Crop via PDF.co ---
    // PDF.co "pdf/convert/to/png" with 'rect'
    // Note: PDF.co uses 0-based page indexing
    const pageIndex = Math.max(0, page - 1)

    console.log(`[PDF.co] Requesting crop on page index ${pageIndex}...`)

    const renderPayload = {
      url: pdfUrl,
      pages: String(pageIndex),
      rect: rectString,
      async: false
    }

    const renderRes = await fetch('https://api.pdf.co/v1/pdf/convert/to/png', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': pdfCoApiKey },
      body: JSON.stringify(renderPayload)
    })

    const renderJson = await renderRes.json()
    if (!renderRes.ok || renderJson.error) {
      console.error('[PDF.co Error]', renderJson)
      throw new Error(renderJson.message || 'PDF.co crop failed')
    }

    const cropImageUrl = renderJson.urls?.[0] || renderJson.url
    if (!cropImageUrl) throw new Error('No image URL returned from PDF.co')

    console.log(`[PDF.co] Success! Image URL: ${cropImageUrl}`)

    // --- STEP 4: Download & Storage ---
    // Download the cropped image from PDF.co
    const imgRes = await fetch(cropImageUrl)
    const resultBlob = await imgRes.blob() // blob is fine for storage upload
    const resultBuffer = await resultBlob.arrayBuffer()
    const resultBytes = new Uint8Array(resultBuffer)

    console.log(`[Upload] Uploading ${resultBytes.length} bytes to storage...`)
    const fileName = `figures/${questionId}.png`

    const { error: uploadError } = await supabase.storage
        .from('exam-papers')
        .upload(fileName, resultBytes, {
            contentType: 'image/png',
            upsert: true
        })

    if (uploadError) throw uploadError

    const { data: publicUrlData } = supabase.storage
      .from('exam-papers')
      .getPublicUrl(fileName)

    const finalPublicUrl = publicUrlData.publicUrl

    // Update Question Record
    console.log(`[DB] Updating question ${questionId} with URL...`)
    await supabase.from('questions')
      .update({ image_url: finalPublicUrl })
      .eq('id', questionId)

    return new Response(
      JSON.stringify({ success: true, image_url: finalPublicUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
