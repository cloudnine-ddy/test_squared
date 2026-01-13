-- Update comment to reflect the new SmartQuestion schema
COMMENT ON COLUMN questions.structure_data IS 
'JSONB array of ExamContentBlocks. 
Schema variants:
1. TextBlock: {"type": "text", "content": "..."}
2. FigureBlock: {"type": "figure", "figure_label": "Figure 1", "description": "...", "url": "..."}
3. QuestionPartBlock: {"type": "question_part", "label": "a)", "content": "...", "marks": 2, "input_type": "...", "correct_answer": "..."}

Ordered list preserving the flow of text -> figure -> question parts.';
