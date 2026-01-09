import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { paperId } = await req.json()
    if (!paperId) throw new Error('Missing paperId')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log(`[Delete] Deleting paper ${paperId}...`)

    // 1. Get Paper Details (PDF URL)
    const { data: paper, error: paperError } = await supabase
      .from('papers')
      .select('pdf_url')
      .eq('id', paperId)
      .single()

    if (paperError) throw paperError

    // 2. Get Questions (Image URLs)
    const { data: questions, error: qError } = await supabase
      .from('questions')
      .select('image_url')
      .eq('paper_id', paperId)

    if (qError) throw qError

    // 3. Collect File Paths to Delete
    const filesToDelete: string[] = []

    // Helper to extract path from URL
    const extractPath = (url: string) => {
      try {
        const uri = new URL(url)
        // Storage URL format: .../storage/v1/object/public/BUCKET/PATH...
        // We need 'PATH...'
        const parts = uri.pathname.split('/exam-papers/')
        if (parts.length > 1) return decodeURIComponent(parts[1])
        return null
      } catch (e) {
        return null
      }
    }

    if (paper?.pdf_url) {
      const path = extractPath(paper.pdf_url)
      if (path) filesToDelete.push(path)
    }

    questions?.forEach(q => {
      if (q.image_url) {
        const path = extractPath(q.image_url)
        if (path) filesToDelete.push(path)
      }
    })

    console.log(`[Delete] Found ${filesToDelete.length} files to delete from storage.`)

    // 4. Delete From Storage (Batch)
    if (filesToDelete.length > 0) {
      const { error: storageError } = await supabase
        .storage
        .from('exam-papers')
        .remove(filesToDelete)

      if (storageError) {
        console.warn('[Delete] Storage delete warning:', storageError)
        // Continue to delete DB record anyway
      }
    }

    // 5. Delete From DB (Cascade should handle questions, but explicit is safer/clearer)
    // Delete questions first
    await supabase.from('questions').delete().eq('paper_id', paperId)

    // Delete paper
    const { error: deleteError } = await supabase
      .from('papers')
      .delete()
      .eq('id', paperId)

    if (deleteError) throw deleteError

    return new Response(
      JSON.stringify({ success: true, deletedFiles: filesToDelete.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
