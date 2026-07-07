-- Username login helper for admin0.html
--
-- Supabase Auth signs in with email/password, not arbitrary usernames.
-- This function lets the static admin page resolve admin_users.username
-- to the matching auth.users.email, then call signInWithPassword.

ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS username TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS admin_users_username_unique
  ON public.admin_users (lower(username))
  WHERE username IS NOT NULL AND length(trim(username)) > 0;

CREATE OR REPLACE FUNCTION public.admin_email_for_username(login_username TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT u.email
  FROM public.admin_users au
  JOIN auth.users u ON u.id = au.user_id
  WHERE lower(trim(au.username)) = lower(trim(login_username))
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.admin_email_for_username(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_email_for_username(TEXT) TO anon, authenticated;

-- Tell Supabase/PostgREST to refresh its schema cache immediately.
NOTIFY pgrst, 'reload schema';

-- Example:
-- update public.admin_users
-- set username = 'admin'
-- where user_id = '<auth-user-uuid>';
