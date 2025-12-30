-- Complete SPM Migration - Correct Schema Version
-- Created: 2025-01-30
-- Purpose: Remove all existing content and add SPM subjects with Biology topics

-- ============================================================================
-- STEP 1: DELETE ALL EXISTING CONTENT (Clean slate)
-- ============================================================================

-- Delete in correct order to respect foreign key constraints
DELETE FROM user_question_attempts;
DELETE FROM question_notes;
DELETE FROM user_bookmarks;
DELETE FROM ai_explanations;
DELETE FROM questions;
DELETE FROM papers;
DELETE FROM topics;
DELETE FROM user_subjects;
DELETE FROM subjects;

-- Delete existing curriculums if any
DELETE FROM curriculums;

DO $$
BEGIN
  RAISE NOTICE 'All existing content deleted successfully';
END $$;

-- ============================================================================
-- STEP 2: INSERT SPM CURRICULUM
-- ============================================================================

INSERT INTO curriculums (id, name) VALUES ('SPM', 'SPM');

DO $$
BEGIN
  RAISE NOTICE 'SPM curriculum inserted';
END $$;

-- ============================================================================
-- STEP 3: INSERT SPM SUBJECTS
-- ============================================================================

INSERT INTO subjects (name, curriculum_id, icon_url) VALUES
  ('Additional Mathematics', 'SPM', NULL),
  ('Physics', 'SPM', NULL),
  ('Chemistry', 'SPM', NULL),
  ('Biology', 'SPM', NULL);

DO $$
BEGIN
  RAISE NOTICE 'SPM subjects inserted successfully';
END $$;

-- ============================================================================
-- STEP 4: INSERT SPM BIOLOGY TOPICS
-- ============================================================================

DO $$
DECLARE
  v_biology_id UUID;
BEGIN
  -- Get Biology subject ID
  SELECT id INTO v_biology_id FROM subjects WHERE name = 'Biology' AND curriculum_id = 'SPM';
  
  IF v_biology_id IS NULL THEN
    RAISE EXCEPTION 'Biology subject not found';
  END IF;
  
  -- Form 4 Topics (15 topics)
  INSERT INTO topics (name, subject_id) VALUES
    ('Fundamentals of Biology', v_biology_id),
    ('Cell Biology and Organisation', v_biology_id),
    ('Movement of Substances across a Plasma Membrane', v_biology_id),
    ('Chemical Compositions in a Cell', v_biology_id),
    ('Metabolism and Enzymes', v_biology_id),
    ('Cell Division', v_biology_id),
    ('Cellular Respiration', v_biology_id),
    ('Respiratory Systems in Humans and Animals', v_biology_id),
    ('Nutrition and the Human Digestive System', v_biology_id),
    ('Transport in Humans and Animals', v_biology_id),
    ('Immunity in Humans', v_biology_id),
    ('Coordination and Response in Humans', v_biology_id),
    ('Homeostasis and the Human Urinary System', v_biology_id),
    ('Support and Movement in Humans and Animals', v_biology_id),
    ('Sexual Reproduction, Development and Growth in Humans and Animals', v_biology_id);
  
  -- Form 5 Topics (13 topics)
  INSERT INTO topics (name, subject_id) VALUES
    ('Organisation of Plant Tissues and Growth', v_biology_id),
    ('Leaf Structure and Function', v_biology_id),
    ('Nutrition in Plants', v_biology_id),
    ('Transport in Plants', v_biology_id),
    ('Response in Plants', v_biology_id),
    ('Sexual Reproduction in Flowering Plants', v_biology_id),
    ('Adaptations of Plants in Different Habitats', v_biology_id),
    ('Biodiversity', v_biology_id),
    ('Ecosystem', v_biology_id),
    ('Environmental Sustainability', v_biology_id),
    ('Inheritance', v_biology_id),
    ('Variation', v_biology_id),
    ('Genetic Technology', v_biology_id);
  
  RAISE NOTICE 'SPM Biology topics (28 total) inserted successfully';
END $$;

-- ============================================================================
-- STEP 5: ADD PROGRESS TRACKING FUNCTIONS
-- ============================================================================

-- Function to calculate topic progress for a user
CREATE OR REPLACE FUNCTION get_topic_progress(
  p_user_id UUID,
  p_topic_id UUID
)
RETURNS TABLE (
  topic_id UUID,
  total_questions BIGINT,
  completed_questions BIGINT,
  progress_percentage NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p_topic_id as topic_id,
    COUNT(DISTINCT q.id)::BIGINT as total_questions,
    COUNT(DISTINCT CASE WHEN uqa.is_correct = true THEN q.id END)::BIGINT as completed_questions,
    ROUND(
      (COUNT(DISTINCT CASE WHEN uqa.is_correct = true THEN q.id END)::NUMERIC / 
       NULLIF(COUNT(DISTINCT q.id), 0) * 100)::NUMERIC,
      2
    ) as progress_percentage
  FROM questions q
  LEFT JOIN user_question_attempts uqa 
    ON q.id = uqa.question_id 
    AND uqa.user_id = p_user_id
  WHERE p_topic_id = ANY(q.topic_ids)
  GROUP BY p_topic_id;
END;
$$;

-- Function to get daily question solving stats
CREATE OR REPLACE FUNCTION get_daily_question_stats(
  p_user_id UUID,
  p_days INTEGER DEFAULT 30
)
RETURNS TABLE (
  date DATE,
  questions_solved BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    DATE(attempted_at) as date,
    COUNT(DISTINCT question_id)::BIGINT as questions_solved
  FROM user_question_attempts
  WHERE user_id = p_user_id
    AND attempted_at >= CURRENT_DATE - p_days
    AND is_correct = true
  GROUP BY DATE(attempted_at)
  ORDER BY date DESC;
END;
$$;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
DECLARE
  v_subject_count INTEGER;
  v_topic_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_subject_count FROM subjects WHERE curriculum_id = 'SPM';
  SELECT COUNT(*) INTO v_topic_count FROM topics WHERE subject_id IN (
    SELECT id FROM subjects WHERE curriculum_id = 'SPM'
  );
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SPM Migration completed successfully!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Database now contains:';
  RAISE NOTICE '  - % SPM subjects', v_subject_count;
  RAISE NOTICE '  - % Biology topics', v_topic_count;
  RAISE NOTICE '  - Progress tracking functions added';
  RAISE NOTICE '  - Daily stats function added';
  RAISE NOTICE '========================================';
END $$;
