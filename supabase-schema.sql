-- =============================================================================
-- NutriCheck · Esquema Supabase
-- =============================================================================
-- Pega este script en: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Es idempotente en RLS/policies, pero las tablas solo se crean una vez.
-- =============================================================================

-- 1. Tabla de perfiles (1 fila por usuario, vinculada a auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{
    "prohibido": ["lactosa","gluten","frutos secos"],
    "permitido": [],
    "limitado": ["azúcar"],
    "soloTrazas": [],
    "permitirTrazas": false
  }'::jsonb,
  updated_at timestamptz not null default now()
);

-- 2. Tabla de análisis (historial)
create table if not exists public.analyses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists analyses_user_created_idx
  on public.analyses(user_id, created_at desc);

-- 3. Row-Level Security (RLS): cada usuario solo ve / toca lo suyo
alter table public.profiles enable row level security;
alter table public.analyses enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

drop policy if exists "analyses_select_own" on public.analyses;
drop policy if exists "analyses_insert_own" on public.analyses;
drop policy if exists "analyses_delete_own" on public.analyses;
create policy "analyses_select_own" on public.analyses for select using (auth.uid() = user_id);
create policy "analyses_insert_own" on public.analyses for insert with check (auth.uid() = user_id);
create policy "analyses_delete_own" on public.analyses for delete using (auth.uid() = user_id);

-- 4. Trigger: auto-crear fila en profiles al registrarse un usuario nuevo
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
