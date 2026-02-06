-- Add email column to user_profiles
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Function to sync email from auth.users
CREATE OR REPLACE FUNCTION public.handle_sync_user_email()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.user_profiles
  SET email = NEW.email
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_sync_user_email();

-- Backfill existing emails
UPDATE public.user_profiles up
SET email = u.email
FROM auth.users u
WHERE up.id = u.id AND up.email IS NULL;

-- Ensure new users get their email synced (if handle_new_user trigger exists, update it)
-- If not, we can add a separate trigger for insert
CREATE OR REPLACE FUNCTION public.handle_sync_user_email_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.user_profiles
  SET email = NEW.email
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_sync_email ON auth.users;
CREATE TRIGGER on_auth_user_created_sync_email
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_sync_user_email_on_insert();
