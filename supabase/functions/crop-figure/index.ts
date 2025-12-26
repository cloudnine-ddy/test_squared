import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * crop-figure Edge Function - Uses pdf.co API
 * 
 * This function crops a specific region from a PDF page and uploads it to Storage.
 * 
 * Input:
 * - pdfUrl: URL of the PDF in storage
 * - questionId: ID of the question to update with image_url
 * - page: Page number (1-indexed)
 * - bbox: { x, y, width, height } as percentages (0-100)
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

const PDF_CO_API_URL = 'https://api.pdf.co/v1/pdf/convert/to/png'

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
    
    // Get pdf.co API key
    const pdfCoApiKey = Deno.env.get('PDF_CO_API_KEY')
    
    if (!pdfCoApiKey) {
      console.error('PDF_CO_API_KEY not set')
      return new Response(
        JSON.stringify({ error: 'PDF_CO_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Cropping figure for question ${questionId}, page ${page}`)
    console.log(`Bounding box: x=${bbox.x}%, y=${bbox.y}%, w=${bbox.width}%, h=${bbox.height}%`)

    // PDF.co uses absolute pixel coordinates
    // A4 PDF at 150 DPI is approximately 1240 x 1754 pixels
    // We'll use these as reference dimensions
    const PDF_WIDTH = 1240
    const PDF_HEIGHT = 1754
    
    const rectX = Math.round((bbox.x / 100) * PDF_WIDTH)
    const rectY = Math.round((bbox.y / 100) * PDF_HEIGHT)
    const rectWidth = Math.round((bbox.width / 100) * PDF_WIDTH)
    const rectHeight = Math.round((bbox.height / 100) * PDF_HEIGHT)
    
    const rectString = `${rectX}, ${rectY}, ${rectWidth}, ${rectHeight}`
    console.log(`Crop rect: ${rectString}`)

    // Call pdf.co API to convert PDF region to PNG
    const pdfCoPayload = {
      url: pdfUrl,
      pages: String(page - 1), // pdf.co uses 0-indexed pages
      rect: rectString,
      async: false
    }

    console.log('Calling pdf.co API...')
    
    const pdfCoRes = await fetch(PDF_CO_API_URL, {
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
      console.error('pdf.co error:', pdfCoJson.message)
      return new Response(
        JSON.stringify({ error: 'pdf.co error', details: pdfCoJson.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // pdf.co returns an array of URLs for the generated images
    const imageUrls = pdfCoJson.urls || [pdfCoJson.url]
    
    if (!imageUrls || imageUrls.length === 0) {
      console.error('No image URLs returned from pdf.co')
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
    const { data: uploadData, error: uploadError } = await supabase.storage
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
      // Image is uploaded, just log the error
    } else {
      console.log(`Updated question ${questionId} with image_url`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        image_url: imageUrl 
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
