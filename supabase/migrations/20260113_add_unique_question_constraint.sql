-- Add unique constraint to allow UPSERT on (paper_id, question_number)
-- This ensures we don't accidentally create duplicate questions when re-processing batches
ALTER TABLE questions 
ADD CONSTRAINT questions_paper_id_question_number_key 
UNIQUE (paper_id, question_number);
