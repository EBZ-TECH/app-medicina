-- Tabla de perfil para usuarios de la app.
-- Se asume que ya tienes Supabase Auth habilitado.

-- 1) Enum de rol
do $$
begin
  create type public.user_role as enum ('Paciente', 'Especialista');
exception when duplicate_object then null;
end $$;

-- 2) Tabla profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null,

  first_name text not null,
  last_name text not null,
  age integer,
  phone text,

  professional_title text,
  professional_specialty text,
  professional_card_path text,

  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 3) Políticas mínimas: el usuario puede ver su propio perfil.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

-- Notas:
-- Este backend usa el "service role" para insertar/actualizar perfiles.
-- Por eso las políticas para insert/update son opcionales para el flujo actual.

-- 4) Bucket para tarjetas profesionales (privado por defecto)
-- En Supabase se crea insertando en storage.buckets.
do $$
begin
  insert into storage.buckets (id, name, public)
  values ('professional_cards', 'professional_cards', false)
  on conflict (id) do nothing;
exception
  when others then null;
end $$;

