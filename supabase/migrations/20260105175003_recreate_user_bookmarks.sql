-- Recreate user_bookmarks table for question bookmarking
-- These tables were accidentally dropped during schema refactor

-- 1. user_bookmarks table
CREATE TABLE IF NOT EXISTS public.user_bookmarks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  folder_name TEXT NOT NULL DEFAULT 'My Bookmarks',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, question_id)
);

-- Create indexes for user_bookmarks
CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON public.user_bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_folder ON public.user_bookmarks(user_id, folder_name);
CREATE INDEX IF NOT EXISTS idx_bookmarks_created ON public.user_bookmarks(created_at DESC);

-- Enable RLS for user_bookmarks
ALTER TABLE public.user_bookmarks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_bookmarks
DROP POLICY IF EXISTS "Users can manage own bookmarks" ON public.user_bookmarks;
CREATE POLICY "Users can manage own bookmarks"
  ON public.user_bookmarks FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add comment for user_bookmarks
COMMENT ON TABLE public.user_bookmarks IS 'Stores user bookmarked questions organized by folders';

-- 2. question_notes table
CREATE TABLE IF NOT EXISTS public.question_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  note_text TEXT NOT NULL,
  color TEXT DEFAULT '#FFF9C4',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, question_id)
);

-- Create indexes for question_notes
CREATE INDEX IF NOT EXISTS idx_notes_user ON public.question_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_question ON public.question_notes(question_id);

-- Enable RLS for question_notes
ALTER TABLE public.question_notes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for question_notes
DROP POLICY IF EXISTS "Users can manage own notes" ON public.question_notes;
CREATE POLICY "Users can manage own notes"
  ON public.question_notes FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add comment for question_notes
COMMENT ON TABLE public.question_notes IS 'Stores user notes for questions';
