-- Add Free Checks Remaining to Profiles
-- Created: 2026-01-07
-- Purpose: Track remaining free answer checks for non-premium users

BEGIN;

-- ============================================================================
-- 1. ADD free_checks_remaining COLUMN TO PROFILES
-- ============================================================================

-- Add column with default of 5 for new users
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS free_checks_remaining INTEGER DEFAULT 5 NOT NULL;

-- ============================================================================
-- 2. SET EXISTING FREE USERS TO 5 CHECKS
-- ============================================================================

-- Give all existing free users 5 free checks
UPDATE profiles 
SET free_checks_remaining = 5 
WHERE subscription_tier = 'free' AND free_checks_remaining IS NULL;

-- ============================================================================
-- 3. ADD CHECK CONSTRAINT
-- ============================================================================

-- Ensure free_checks_remaining is never negative
ALTER TABLE profiles 
ADD CONSTRAINT check_free_checks_remaining 
CHECK (free_checks_remaining >= 0);

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Free Checks Migration Complete!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added column to profiles:';
  RAISE NOTICE '  - free_checks_remaining (INTEGER, default: 5)';
  RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- 4. RPC FUNCTION TO DECREMENT FREE CHECKS
-- ============================================================================

CREATE OR REPLACE FUNCTION decrement_free_checks(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles 
  SET free_checks_remaining = GREATEST(0, free_checks_remaining - 1)
  WHERE id = user_id;
END;
$$;

COMMIT;
