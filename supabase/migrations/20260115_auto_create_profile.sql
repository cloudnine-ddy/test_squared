-- Fix: Auto-create profile when user signs up
-- Created: 2026-01-15
-- Purpose: Automatically create a profile record when a new user is created in auth.users

-- Create a trigger function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, subscription_tier, free_checks_remaining)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'student',
    'free',
    5
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verification
DO $$
BEGIN
  RAISE NOTICE 'Profile auto-creation trigger installed!';
  RAISE NOTICE 'New users will automatically get a profile created.';
END $$;
