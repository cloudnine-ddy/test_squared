import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * render-page Edge Function
 *
 * Renders a PDF page as an image using pdf.co API.
 * Uses default 72 DPI rendering to match crop-figure coordinates.
 */

interface RenderRequest {
  pdfUrl: string
  page: number
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
    const { pdfUrl, page }: RenderRequest = await req.json()

    if (!pdfUrl || !page) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: pdfUrl and page' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const pdfCoApiKey = Deno.env.get('PDF_CO_API_KEY')

    if (!pdfCoApiKey) {
      return new Response(
        JSON.stringify({ error: 'PDF_CO_API_KEY not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Rendering page ${page} from PDF...`)

    // Render at DEFAULT 72 DPI to match crop-figure coordinates
    // Do NOT specify width - let it use the default size
    const pdfCoPayload = {
      url: pdfUrl,
      pages: String(page - 1),
      async: false,
      inline: true // Return Base64
      // NO width parameter - use default 72 DPI
    }

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

    if (pdfCoJson.error) {
      return new Response(
        JSON.stringify({ error: 'pdf.co error', details: pdfCoJson.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let pageBody = pdfCoJson.body; // Base64 content

    // Fallback: If no inline body, check for URL and download it
    let targetUrl = pdfCoJson.url;
    if (!targetUrl && Array.isArray(pdfCoJson.urls) && pdfCoJson.urls.length > 0) {
        targetUrl = pdfCoJson.urls[0];
    }

    if (!pageBody && targetUrl) {
        console.log(`PDF.co returned URL instead of body. Downloading: ${targetUrl}`);
        const imgRes = await fetch(targetUrl);
        if (imgRes.ok) {
            const imgBuffer = await imgRes.arrayBuffer();
            const u8 = new Uint8Array(imgBuffer);
            let b = ''; const l = u8.length;
            for(let i=0;i<l;i+=32768) b+=String.fromCharCode(...u8.subarray(i,i+32768));
            pageBody = btoa(b);
        }
    }

    if (!pageBody) {
      console.error('PDF.co response dump:', JSON.stringify(pdfCoJson));
      return new Response(
        JSON.stringify({ error: 'No image body returned', provider_response: pdfCoJson }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Page rendered (Base64) length: ${pageBody.length}`)

    return new Response(
      JSON.stringify({
        success: true,
        image_base64: pageBody
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Render page error:', error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
