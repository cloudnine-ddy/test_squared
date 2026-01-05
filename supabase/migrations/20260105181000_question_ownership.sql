-- Add created_by column to track ownership
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- Drop simpler policies to replace with granular ones
DROP POLICY IF EXISTS "Public read questions" ON public.questions;
DROP POLICY IF EXISTS "Users can insert generated questions" ON public.questions;

-- 1. Official questions are public
CREATE POLICY "Public read official questions"
ON public.questions FOR SELECT
USING (type IS DISTINCT FROM 'ai_generated');

-- 2. Users can see their own generated questions
CREATE POLICY "Users can see own generated questions"
ON public.questions FOR SELECT
USING (created_by = auth.uid());

-- 3. Users can insert generated questions (must set created_by to themselves)
CREATE POLICY "Users can insert generated questions"
ON public.questions FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  type = 'ai_generated' AND
  created_by = auth.uid()
);
