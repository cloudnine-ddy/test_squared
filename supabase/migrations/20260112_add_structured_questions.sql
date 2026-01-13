-- Add support for structured questions with JSONB blocks
-- Created: 2026-01-12
-- Purpose: Add structure_data column for multi-part questions with flexible block system

BEGIN;

-- Add structure_data column for structured questions
ALTER TABLE questions 
ADD COLUMN IF NOT EXISTS structure_data JSONB;

-- Add comment explaining the schema
COMMENT ON COLUMN questions.structure_data IS 
'JSONB array of blocks for structured questions. Schema:
[
  {"type": "text", "content": "Figure 6.1 shows..."},
  {"type": "image", "url": "https://..."},
  {"type": "sub_question", "id": "part_i", "text": "Complete the sentences...", "input_type": "fill_in_blanks", "correct_answer": [...], "marks": 1}
]
Only used when type = ''structured''. For MCQ questions, this remains NULL.';

-- Create an index on structure_data for faster queries (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_questions_structure_data 
ON questions USING GIN (structure_data);

COMMIT;
