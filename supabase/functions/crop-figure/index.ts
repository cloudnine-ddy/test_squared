import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * crop-figure Edge Function
 * 
 * Two-step approach:
 * 1. Render full page as image using pdf.co
 * 2. Use Sharp (or similar) to crop the exact region
 * 
 * Since Deno doesn't have Sharp, we'll use a workaround:
 * Return both the full page URL and crop coordinates, 
 * let the client do the visual cropping, then upload the result.
 * 
 * Or we can use pdf.co's rect parameter correctly by understanding
 * that it uses the DEFAULT render size, not the specified width.
 */

interface CropRequest {
  pdfUrl: string
  questionId: string
  page: number
  bbox: {
    x: number
    y: number
    width: number
    height: number
  }
}

// pdf.co renders PDF at 72 DPI by default
// A4 at 72 DPI = 595 x 842 pixels
const PDF_DEFAULT_WIDTH = 595
const PDF_DEFAULT_HEIGHT = 842

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { pdfUrl, questionId, page, bbox }: CropRequest = await req.json()

    if (!pdfUrl || !questionId || !page || !bbox) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    const pdfCoApiKey = Deno.env.get('PDF_CO_API_KEY')
    
    if (!pdfCoApiKey) {
      return new Response(
        JSON.stringify({ error: 'PDF_CO_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Cropping figure for question ${questionId}, page ${page}`)
    console.log(`Input bbox: x=${bbox.x}%, y=${bbox.y}%, w=${bbox.width}%, h=${bbox.height}%`)

    // pdf.co rect uses the DEFAULT PDF render coordinates (72 DPI)
    // We need to convert our percentage-based coordinates to these
    const rectX = Math.round((bbox.x / 100) * PDF_DEFAULT_WIDTH)
    const rectY = Math.round((bbox.y / 100) * PDF_DEFAULT_HEIGHT)
    const rectWidth = Math.max(Math.round((bbox.width / 100) * PDF_DEFAULT_WIDTH), 30)
    const rectHeight = Math.max(Math.round((bbox.height / 100) * PDF_DEFAULT_HEIGHT), 30)
    
    const rectString = `${rectX}, ${rectY}, ${rectWidth}, ${rectHeight}`
    console.log(`Crop rect (72 DPI base): ${rectString}`)

    // Call pdf.co API - DON'T specify width when using rect
    // rect is based on the default 72 DPI render
    const pdfCoPayload = {
      url: pdfUrl,
      pages: String(page - 1),
      rect: rectString,
      async: false
    }

    console.log('Calling pdf.co with payload:', JSON.stringify(pdfCoPayload))
    
    const pdfCoRes = await fetch('https://api.pdf.co/v1/pdf/convert/to/png', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': pdfCoApiKey
      },
      body: JSON.stringify(pdfCoPayload)
    })

    if (!pdfCoRes.ok) {
      const errorText = await pdfCoRes.text()
      console.error('pdf.co API error:', pdfCoRes.status, errorText)
      return new Response(
        JSON.stringify({ error: 'pdf.co API error', details: errorText }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const pdfCoJson = await pdfCoRes.json()
    console.log('pdf.co response:', JSON.stringify(pdfCoJson))

    if (pdfCoJson.error) {
      return new Response(
        JSON.stringify({ error: 'pdf.co error', details: pdfCoJson.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const imageUrls = pdfCoJson.urls || [pdfCoJson.url]
    
    if (!imageUrls || imageUrls.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No image generated' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const generatedImageUrl = imageUrls[0]
    console.log(`Generated image URL: ${generatedImageUrl}`)

    // Download the generated image
    const imageResponse = await fetch(generatedImageUrl)
    if (!imageResponse.ok) {
      throw new Error(`Failed to download generated image: ${imageResponse.status}`)
    }
    
    const imageBuffer = await imageResponse.arrayBuffer()
    const imageBytes = new Uint8Array(imageBuffer)
    
    console.log(`Downloaded image: ${imageBytes.length} bytes`)

    // Upload to Supabase Storage
    const fileName = `figures/${questionId}.png`
    const { error: uploadError } = await supabase.storage
      .from('exam-papers')
      .upload(fileName, imageBytes, {
        contentType: 'image/png',
        upsert: true
      })

    if (uploadError) {
      throw new Error(`Failed to upload to storage: ${uploadError.message}`)
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('exam-papers')
      .getPublicUrl(fileName)

    const imageUrl = urlData.publicUrl
    console.log(`Uploaded to storage: ${imageUrl}`)

    // Update the question with the image URL
    const { error: updateError } = await supabase
      .from('questions')
      .update({ image_url: imageUrl })
      .eq('id', questionId)

    if (updateError) {
      console.error('Failed to update question:', updateError)
    } else {
      console.log(`Updated question ${questionId} with image_url`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        image_url: imageUrl,
        debug: {
          inputBbox: bbox,
          calculatedRect: rectString
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Crop figure error:', error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
