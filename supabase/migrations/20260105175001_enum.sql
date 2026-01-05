-- Allow 'ai_generated' as a valid question type
ALTER TYPE public.question_type ADD VALUE IF NOT EXISTS 'ai_generated';
