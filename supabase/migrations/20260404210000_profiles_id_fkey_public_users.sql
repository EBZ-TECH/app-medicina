-- profiles.id apuntaba a auth.users (plantilla Supabase); el API usa solo public.users.
-- Sin esto, INSERT en registro falla: el UUID no existe en auth.users.

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES public.users(id) ON DELETE CASCADE;
