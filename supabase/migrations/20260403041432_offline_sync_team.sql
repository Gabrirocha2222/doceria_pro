-- Block 15 - Offline-first real, sync e equipe
-- Copy and paste this file into the Supabase SQL Editor.
-- This baseline is intentionally simple so the app can sync snapshots before
-- the authentication block is wired. Tighten the policies before production.

create extension if not exists pgcrypto;

create table if not exists public.app_teams (
  id text primary key,
  name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.app_team_members (
  id text primary key,
  team_id text not null references public.app_teams(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('owner', 'employee')),
  auth_user_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists app_team_members_team_id_idx
  on public.app_team_members (team_id);

create unique index if not exists app_team_members_auth_user_id_idx
  on public.app_team_members (auth_user_id)
  where auth_user_id is not null;

create table if not exists public.sync_entity_snapshots (
  team_id text not null references public.app_teams(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  payload jsonb not null default '{}'::jsonb,
  payload_schema integer not null default 1,
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  updated_by_member_id text not null references public.app_team_members(id),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (team_id, entity_type, entity_id)
);

create index if not exists sync_entity_snapshots_team_updated_idx
  on public.sync_entity_snapshots (team_id, updated_at desc);

create index if not exists sync_entity_snapshots_entity_idx
  on public.sync_entity_snapshots (entity_type, entity_id);

grant select, insert, update, delete on public.app_teams to anon, authenticated;
grant select, insert, update, delete on public.app_team_members to anon, authenticated;
grant select, insert, update, delete on public.sync_entity_snapshots to anon, authenticated;

alter table public.app_teams enable row level security;
alter table public.app_team_members enable row level security;
alter table public.sync_entity_snapshots enable row level security;

drop policy if exists block15_temp_app_teams on public.app_teams;
create policy block15_temp_app_teams
on public.app_teams
for all
using (true)
with check (true);

drop policy if exists block15_temp_app_team_members on public.app_team_members;
create policy block15_temp_app_team_members
on public.app_team_members
for all
using (true)
with check (true);

drop policy if exists block15_temp_sync_entity_snapshots on public.sync_entity_snapshots;
create policy block15_temp_sync_entity_snapshots
on public.sync_entity_snapshots
for all
using (true)
with check (true);

comment on table public.sync_entity_snapshots is
'Block 15 baseline. Stores one JSON snapshot per root entity for offline-first sync.';

comment on column public.sync_entity_snapshots.payload is
'Root snapshot payload used by the Flutter app. Child records are embedded inside the root JSON.';

comment on policy block15_temp_app_teams on public.app_teams is
'Temporary baseline while auth is still out of scope. Replace with membership-aware policies before production.';

comment on policy block15_temp_app_team_members on public.app_team_members is
'Temporary baseline while auth is still out of scope. Replace with membership-aware policies before production.';

comment on policy block15_temp_sync_entity_snapshots on public.sync_entity_snapshots is
'Temporary baseline while auth is still out of scope. Replace with policies that restrict rows to the user team.';

-- Suggested next policy strategy after auth is available:
-- 1. Keep app_team_members.auth_user_id filled with auth.uid().
-- 2. Allow reads and writes only when a row exists in app_team_members for auth.uid().
-- 3. Restrict sync_entity_snapshots.team_id to the team linked to auth.uid().
-- 4. Limit destructive operations to owner rows or explicit admin roles.
