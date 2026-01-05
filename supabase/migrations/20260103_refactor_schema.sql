-- Refactor Schema for MVP
-- Created: 2026-01-03
-- Purpose: Simplify schema, remove unused features, consolidate curriculum info.

BEGIN;

-- ============================================================================
-- 1. CLEANUP - Drop unused tables
-- ============================================================================

-- Drop dependent tables first or use CASCADE
DROP TABLE IF EXISTS admin_activity_log CASCADE;
DROP TABLE IF EXISTS ai_explanations CASCADE;
DROP TABLE IF EXISTS user_subjects CASCADE;
DROP TABLE IF EXISTS question_notes CASCADE;
DROP TABLE IF EXISTS user_bookmarks CASCADE;

-- We will drop 'curriculums' later after migrating data

-- ============================================================================
-- 2. CONSOLIDATE - Subjects & Curriculums
-- ============================================================================

-- Add 'curriculum' column to subjects
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS curriculum TEXT;

-- Data Migration: 
-- Try to update subjects with curriculum name from curriculums table.
-- If no match found or if curriculum_id is null, default to 'SPM' or appropriate fallback.
DO $$
BEGIN
    -- Update existing subjects if they have a curriculum_id
    UPDATE subjects s
    SET curriculum = c.name
    FROM curriculums c
    WHERE s.curriculum_id = c.id;

    -- Fallback for any subjects that didn't get a curriculum (if any)
    UPDATE subjects
    SET curriculum = 'SPM' 
    WHERE curriculum IS NULL;
    
    RAISE NOTICE 'Data migration from curriculums to subjects completed.';
END $$;

-- Drop foreign key and column from subjects
ALTER TABLE subjects DROP COLUMN IF EXISTS curriculum_id CASCADE;

-- Now safe to drop curriculums table
DROP TABLE IF EXISTS curriculums CASCADE;


-- ============================================================================
-- 3. QUESTIONS - Add explanations
-- ============================================================================

ALTER TABLE questions ADD COLUMN IF NOT EXISTS explanation JSONB;

-- Ensure ai_answer exists (it should, but just in case)
ALTER TABLE questions ADD COLUMN IF NOT EXISTS ai_answer JSONB;


-- ============================================================================
-- 4. POLICIES - Row Level Security
-- ============================================================================

-- Enable RLS on core tables
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_question_attempts ENABLE ROW LEVEL SECURITY;

-- 4.1 READ POLICIES (Public/Authenticated read for static content)

-- Subjects
DROP POLICY IF EXISTS "Public read subjects" ON subjects;
CREATE POLICY "Public read subjects" ON subjects FOR SELECT USING (true);

-- Questions
DROP POLICY IF EXISTS "Public read questions" ON questions;
CREATE POLICY "Public read questions" ON questions FOR SELECT USING (true);

-- Papers
DROP POLICY IF EXISTS "Public read papers" ON papers;
CREATE POLICY "Public read papers" ON papers FOR SELECT USING (true);

-- Topics
DROP POLICY IF EXISTS "Public read topics" ON topics;
CREATE POLICY "Public read topics" ON topics FOR SELECT USING (true);

-- 4.2 USER DATA POLICIES

-- User Question Attempts
DROP POLICY IF EXISTS "Users view own attempts" ON user_question_attempts;
CREATE POLICY "Users view own attempts" ON user_question_attempts 
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own attempts" ON user_question_attempts;
CREATE POLICY "Users insert own attempts" ON user_question_attempts 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own attempts" ON user_question_attempts;
CREATE POLICY "Users update own attempts" ON user_question_attempts 
    FOR UPDATE USING (auth.uid() = user_id);
    
DROP POLICY IF EXISTS "Users delete own attempts" ON user_question_attempts;
CREATE POLICY "Users delete own attempts" ON user_question_attempts 
    FOR DELETE USING (auth.uid() = user_id);

-- Profiles
DROP POLICY IF EXISTS "Users view own profile" ON profiles;
CREATE POLICY "Users view own profile" ON profiles 
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own profile" ON profiles;
CREATE POLICY "Users update own profile" ON profiles 
    FOR UPDATE USING (auth.uid() = id);

COMMIT;
