-- Allow authenticated users to insert questions if they are marked as 'ai_generated'

CREATE POLICY "Users can insert generated questions"
ON public.questions
FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated' AND
  type = 'ai_generated'
);
