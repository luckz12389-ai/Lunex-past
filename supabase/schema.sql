create extension if not exists pgcrypto;

create table if not exists public.pastes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content text not null,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.pastes enable row level security;

drop policy if exists "Read own or public pastes" on public.pastes;
create policy "Read own or public pastes" on public.pastes
for select to authenticated
using (auth.uid() = user_id or is_public = true);

drop policy if exists "Create own pastes" on public.pastes;
create policy "Create own pastes" on public.pastes
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Update own pastes" on public.pastes;
create policy "Update own pastes" on public.pastes
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Delete own pastes" on public.pastes;
create policy "Delete own pastes" on public.pastes
for delete to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.pastes to authenticated;
