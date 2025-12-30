-- Remove IGCSE Content Migration
-- Created: 2025-01-30
-- Purpose: Remove all IGCSE subjects and topics, keeping only SPM content

-- ============================================================================
-- 1. DELETE IGCSE TOPICS
-- ============================================================================

-- Delete all topics associated with IGCSE subjects
DELETE FROM topics 
WHERE subject_id IN (
  SELECT id FROM subjects WHERE curriculum = 'IGCSE'
);

-- ============================================================================
-- 2. DELETE IGCSE SUBJECTS
-- ============================================================================

-- Delete all IGCSE subjects
DELETE FROM subjects WHERE curriculum = 'IGCSE';

-- ============================================================================
-- 3. ADD CURRICULUM FIELD TO PAPERS TABLE (for future use)
-- ============================================================================

-- Add curriculum column to papers table if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'papers' AND column_name = 'curriculum'
  ) THEN
    ALTER TABLE papers ADD COLUMN curriculum TEXT DEFAULT 'SPM';
  END IF;
END $$;

-- Update existing papers to have SPM curriculum (based on their subject)
UPDATE papers 
SET curriculum = s.curriculum
FROM subjects s
WHERE papers.subject_id = s.id
AND papers.curriculum IS NULL;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'IGCSE Removal completed successfully!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Removed:';
  RAISE NOTICE '  - All IGCSE subjects';
  RAISE NOTICE '  - All IGCSE topics';
  RAISE NOTICE 'Added:';
  RAISE NOTICE '  - curriculum field to papers table';
  RAISE NOTICE '========================================';
END $$;
