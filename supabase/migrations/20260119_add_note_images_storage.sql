-- Create the note-images storage bucket for user sketches and note images
-- This bucket stores images attached to question notes

-- Insert into storage.buckets if the bucket doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload images to their own folder
CREATE POLICY IF NOT EXISTS "Users can upload note images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'note-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own images
CREATE POLICY IF NOT EXISTS "Users can update own note images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'note-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'note-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own images
CREATE POLICY IF NOT EXISTS "Users can delete own note images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'note-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow public read access (since getPublicUrl is used)
CREATE POLICY IF NOT EXISTS "Public read access for note images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'note-images');
