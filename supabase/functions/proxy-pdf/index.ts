import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const targetUrl = url.searchParams.get('url')

    if (!targetUrl) {
      return new Response('Missing url parameter', { status: 400, headers: corsHeaders })
    }

    console.log(`Proxying PDF: ${targetUrl}`)

    const response = await fetch(targetUrl)

    // Copy headers from original response but override CORS
    const newHeaders = new Headers(response.headers)
    newHeaders.set('Access-Control-Allow-Origin', '*')

    // Ensure content type is PDF
    if (!newHeaders.has('Content-Type')) {
        newHeaders.set('Content-Type', 'application/pdf')
    }

    return new Response(response.body, {
      status: response.status,
      headers: newHeaders,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
