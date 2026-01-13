import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const apiKey = Deno.env.get('GEMINI_API_KEY')
  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'No API Key' }), { headers: { 'Content-Type': 'application/json' } })
  }

  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`)
  const data = await res.json()

  return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } })
})
