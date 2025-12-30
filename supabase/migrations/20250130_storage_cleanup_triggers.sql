-- Storage Cleanup Triggers - Fixed Version
-- Created: 2025-01-30
-- Purpose: Automatically delete files from storage when papers or questions are deleted

-- ============================================================================
-- FUNCTION: Delete Paper PDF from Storage
-- ============================================================================

CREATE OR REPLACE FUNCTION delete_paper_storage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_file_path TEXT;
  v_bucket_name TEXT := 'exam-papers';
BEGIN
  -- Extract file path from the PDF URL
  IF OLD.pdf_url IS NOT NULL THEN
    -- Extract the path after 'exam-papers/'
    -- URL format: https://{project}.supabase.co/storage/v1/object/public/exam-papers/pdfs/...
    v_file_path := substring(OLD.pdf_url from 'exam-papers/(.*)');
    
    IF v_file_path IS NOT NULL THEN
      -- Delete from storage using the storage.objects table
      DELETE FROM storage.objects 
      WHERE bucket_id = v_bucket_name 
      AND name = v_file_path;
      
      RAISE NOTICE 'Deleted paper PDF: %', v_file_path;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$;

-- ============================================================================
-- FUNCTION: Delete Question Image from Storage
-- ============================================================================

CREATE OR REPLACE FUNCTION delete_question_storage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_file_path TEXT;
  v_bucket_name TEXT := 'question-images';
BEGIN
  -- Extract file path from the image URL
  IF OLD.image_url IS NOT NULL THEN
    -- Extract the path after the bucket name
    v_file_path := substring(OLD.image_url from 'question-images/(.*)');
    
    IF v_file_path IS NOT NULL THEN
      -- Delete from storage using the storage.objects table
      DELETE FROM storage.objects 
      WHERE bucket_id = v_bucket_name 
      AND name = v_file_path;
      
      RAISE NOTICE 'Deleted question image: %', v_file_path;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$;

-- ============================================================================
-- TRIGGER: Auto-delete paper PDF when paper is deleted
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_delete_paper_storage ON papers;

CREATE TRIGGER trigger_delete_paper_storage
  BEFORE DELETE ON papers
  FOR EACH ROW
  EXECUTE FUNCTION delete_paper_storage();

-- ============================================================================
-- TRIGGER: Auto-delete question image when question is deleted
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_delete_question_storage ON questions;

CREATE TRIGGER trigger_delete_question_storage
  BEFORE DELETE ON questions
  FOR EACH ROW
  EXECUTE FUNCTION delete_question_storage();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Storage cleanup triggers created!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Triggers added:';
  RAISE NOTICE '  - Papers: Auto-delete PDF on delete';
  RAISE NOTICE '  - Questions: Auto-delete image on delete';
  RAISE NOTICE '========================================';
END $$;
