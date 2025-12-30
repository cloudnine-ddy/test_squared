-- SPM Exam System Migration
-- Created: 2025-01-30
-- Purpose: Add SPM curriculum support with 4 subjects, focusing on Biology topics

-- ============================================================================
-- 1. ADD SPM SUBJECTS
-- ============================================================================

-- Insert SPM subjects
INSERT INTO subjects (name, curriculum, icon_url) VALUES
  ('Additional Mathematics', 'SPM', NULL),
  ('Physics', 'SPM', NULL),
  ('Chemistry', 'SPM', NULL),
  ('Biology', 'SPM', NULL)
ON CONFLICT (name, curriculum) DO NOTHING;

-- ============================================================================
-- 2. ADD SPM BIOLOGY TOPICS - FORM 4
-- ============================================================================

-- Get Biology subject ID for SPM
DO $$
DECLARE
  v_biology_id UUID;
BEGIN
  SELECT id INTO v_biology_id FROM subjects WHERE name = 'Biology' AND curriculum = 'SPM';
  
  -- Form 4 Topics
  INSERT INTO topics (name, description, subject_id, color, question_count) VALUES
    ('Fundamentals of Biology', 'Introduction to biology, scientific methods, and basic concepts', v_biology_id, 4280391936, 0),
    ('Cell Biology and Organisation', 'Cell structure, organelles, and levels of organisation', v_biology_id, 4287137928, 0),
    ('Movement of Substances across a Plasma Membrane', 'Diffusion, osmosis, and active transport', v_biology_id, 4294198070, 0),
    ('Chemical Compositions in a Cell', 'Carbohydrates, proteins, lipids, and nucleic acids', v_biology_id, 4291611852, 0),
    ('Metabolism and Enzymes', 'Metabolic processes and enzyme functions', v_biology_id, 4288423856, 0),
    ('Cell Division', 'Mitosis and meiosis processes', v_biology_id, 4285315326, 0),
    ('Cellular Respiration', 'Aerobic and anaerobic respiration', v_biology_id, 4282469022, 0),
    ('Respiratory Systems in Humans and Animals', 'Gas exchange and breathing mechanisms', v_biology_id, 4279622878, 0),
    ('Nutrition and the Human Digestive System', 'Nutrients, digestion, and absorption', v_biology_id, 4293776734, 0),
    ('Transport in Humans and Animals', 'Circulatory system and blood', v_biology_id, 4290930590, 0),
    ('Immunity in Humans', 'Immune system and disease defense', v_biology_id, 4288084446, 0),
    ('Coordination and Response in Humans', 'Nervous system and hormones', v_biology_id, 4285238302, 0),
    ('Homeostasis and the Human Urinary System', 'Body regulation and excretion', v_biology_id, 4282392158, 0),
    ('Support and Movement in Humans and Animals', 'Skeletal and muscular systems', v_biology_id, 4279546014, 0),
    ('Sexual Reproduction, Development and Growth in Humans and Animals', 'Reproductive systems and development', v_biology_id, 4294961870, 0)
  ON CONFLICT (name, subject_id) DO NOTHING;
  
  -- Form 5 Topics
  INSERT INTO topics (name, description, subject_id, color, question_count) VALUES
    ('Organisation of Plant Tissues and Growth', 'Plant tissue types and growth patterns', v_biology_id, 4280391936, 0),
    ('Leaf Structure and Function', 'Leaf anatomy and photosynthesis', v_biology_id, 4287137928, 0),
    ('Nutrition in Plants', 'Photosynthesis and mineral nutrition', v_biology_id, 4294198070, 0),
    ('Transport in Plants', 'Xylem, phloem, and transpiration', v_biology_id, 4291611852, 0),
    ('Response in Plants', 'Tropisms and plant hormones', v_biology_id, 4288423856, 0),
    ('Sexual Reproduction in Flowering Plants', 'Flower structure, pollination, and fertilization', v_biology_id, 4285315326, 0),
    ('Adaptations of Plants in Different Habitats', 'Xerophytes, hydrophytes, and epiphytes', v_biology_id, 4282469022, 0),
    ('Biodiversity', 'Classification and species diversity', v_biology_id, 4279622878, 0),
    ('Ecosystem', 'Energy flow and nutrient cycling', v_biology_id, 4293776734, 0),
    ('Environmental Sustainability', 'Conservation and environmental issues', v_biology_id, 4290930590, 0),
    ('Inheritance', 'Genetics and heredity', v_biology_id, 4288084446, 0),
    ('Variation', 'Genetic and environmental variation', v_biology_id, 4285238302, 0),
    ('Genetic Technology', 'Biotechnology and genetic engineering', v_biology_id, 4282392158, 0)
  ON CONFLICT (name, subject_id) DO NOTHING;
  
  RAISE NOTICE 'SPM Biology topics created successfully!';
END $$;

-- ============================================================================
-- 3. ADD TOPIC PROGRESS TRACKING SUPPORT
-- ============================================================================

-- Add index for better performance on topic queries
CREATE INDEX IF NOT EXISTS idx_topics_subject_id ON topics(subject_id);

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
-- 4. ENHANCE SEARCH AND FILTER CAPABILITIES
-- ============================================================================

-- Add index for year-based filtering
CREATE INDEX IF NOT EXISTS idx_questions_year ON questions(year);

-- Add index for topic-based filtering (GIN index for array)
CREATE INDEX IF NOT EXISTS idx_questions_topic_ids ON questions USING GIN(topic_ids);

-- Enhanced search function with all filters
CREATE OR REPLACE FUNCTION search_questions_enhanced(
  p_query TEXT DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_topic_ids UUID[] DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_question_type TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  question_number INTEGER,
  type TEXT,
  year INTEGER,
  season TEXT,
  subject_id UUID,
  topic_ids UUID[],
  marks INTEGER,
  official_answer TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    q.id,
    q.content,
    q.question_number,
    q.type,
    q.year,
    q.season,
    q.subject_id,
    q.topic_ids,
    q.marks,
    q.official_answer
  FROM questions q
  WHERE 
    (p_query IS NULL OR q.search_vector @@ plainto_tsquery('english', p_query))
    AND (p_subject_id IS NULL OR q.subject_id = p_subject_id)
    AND (p_topic_ids IS NULL OR q.topic_ids && p_topic_ids)
    AND (p_year IS NULL OR q.year = p_year)
    AND (p_question_type IS NULL OR q.type = p_question_type)
  ORDER BY 
    CASE WHEN p_query IS NOT NULL 
      THEN ts_rank(q.search_vector, plainto_tsquery('english', p_query)) 
      ELSE 0 
    END DESC,
    q.year DESC,
    q.question_number ASC
  LIMIT p_limit;
END;
$$;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'SPM Migration completed successfully!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added:';
  RAISE NOTICE '  - 4 SPM subjects';
  RAISE NOTICE '  - 28 SPM Biology topics (15 Form 4 + 13 Form 5)';
  RAISE NOTICE '  - Topic progress tracking functions';
  RAISE NOTICE '  - Daily question stats function';
  RAISE NOTICE '  - Enhanced search with filters';
  RAISE NOTICE '========================================';
END $$;
