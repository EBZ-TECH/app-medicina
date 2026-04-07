-- Alinea public.profiles con el backend MediConnect cuando la tabla ya existía
-- sin user_id ni columnas extra (evita 500 en POST /api/auth/register).

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
    UPDATE public.profiles SET user_id = id WHERE user_id IS NULL;
    ALTER TABLE public.profiles ALTER COLUMN user_id SET NOT NULL;
    CREATE UNIQUE INDEX profiles_user_id_key ON public.profiles(user_id);
  END IF;
END $$;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS payment_plan VARCHAR(40);
UPDATE public.profiles SET payment_plan = 'pay_per_consult' WHERE payment_plan IS NULL;
ALTER TABLE public.profiles ALTER COLUMN payment_plan SET DEFAULT 'pay_per_consult';
ALTER TABLE public.profiles ALTER COLUMN payment_plan SET NOT NULL;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_payment_plan_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_payment_plan_check
  CHECK (payment_plan IN ('pay_per_consult','monthly_subscription'));

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio_short VARCHAR(600);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_photo_path VARCHAR(512);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3,2);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS years_experience INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS available_for_assignments BOOLEAN NOT NULL DEFAULT TRUE;
