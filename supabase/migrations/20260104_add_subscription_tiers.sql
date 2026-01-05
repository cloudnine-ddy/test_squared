-- Add Subscription Tiers to Profiles
-- Created: 2026-01-04
-- Purpose: Add subscription management fields to support premium features

BEGIN;

-- ============================================================================
-- 1. ADD SUBSCRIPTION COLUMNS TO PROFILES
-- ============================================================================

-- Add subscription_tier column (default: 'free')
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free' NOT NULL;

-- Add premium_until column (nullable - null means lifetime or not applicable)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS premium_until TIMESTAMP WITH TIME ZONE;

-- ============================================================================
-- 2. UPDATE EXISTING PROFILES
-- ============================================================================

-- Set all existing profiles to 'free' tier if not already set
UPDATE profiles 
SET subscription_tier = 'free' 
WHERE subscription_tier IS NULL;

-- ============================================================================
-- 3. ADD INDEXES FOR PERFORMANCE
-- ============================================================================

-- Index on subscription_tier for filtering premium users
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_tier 
ON profiles(subscription_tier);

-- Index on premium_until for expiry checks
CREATE INDEX IF NOT EXISTS idx_profiles_premium_until 
ON profiles(premium_until) 
WHERE premium_until IS NOT NULL;

-- ============================================================================
-- 4. ADD CHECK CONSTRAINT
-- ============================================================================

-- Ensure subscription_tier is one of valid values
ALTER TABLE profiles 
ADD CONSTRAINT check_subscription_tier 
CHECK (subscription_tier IN ('free', 'premium', 'lifetime'));

-- ============================================================================
-- 5. HELPER FUNCTION - Check if user has active premium
-- ============================================================================

CREATE OR REPLACE FUNCTION is_user_premium(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tier TEXT;
  v_premium_until TIMESTAMP WITH TIME ZONE;
  v_role TEXT;
BEGIN
  -- Get user's subscription info and role
  SELECT subscription_tier, premium_until, role 
  INTO v_tier, v_premium_until, v_role
  FROM profiles
  WHERE id = p_user_id;
  
  -- Admin users always have premium access
  IF v_role = 'admin' THEN
    RETURN TRUE;
  END IF;
  
  -- Check if user has premium tier
  IF v_tier = 'free' THEN
    RETURN FALSE;
  END IF;
  
  -- For lifetime tier
  IF v_tier = 'lifetime' THEN
    RETURN TRUE;
  END IF;
  
  -- For premium tier, check expiry
  IF v_tier = 'premium' THEN
    -- If premium_until is NULL, treat as lifetime
    IF v_premium_until IS NULL THEN
      RETURN TRUE;
    END IF;
    
    -- Check if not expired
    RETURN v_premium_until > NOW();
  END IF;
  
  -- Default to false
  RETURN FALSE;
END;
$$;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Subscription Tiers Migration Complete!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added columns to profiles:';
  RAISE NOTICE '  - subscription_tier (TEXT, default: free)';
  RAISE NOTICE '  - premium_until (TIMESTAMP WITH TIME ZONE)';
  RAISE NOTICE 'Created function:';
  RAISE NOTICE '  - is_user_premium(user_id) → boolean';
  RAISE NOTICE 'Valid tiers: free, premium, lifetime';
  RAISE NOTICE '========================================';
END $$;

COMMIT;
