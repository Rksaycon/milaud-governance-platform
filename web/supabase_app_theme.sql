-- Live mobile-app color customization.
--
-- The admin panel's "App Customization" page (src/AppCustomizationPage.jsx)
-- writes a brand + accent color here; the Maylaud mobile app loads this row at
-- launch and subscribes to Postgres Changes on it, then repaints itself through
-- AppColors.applyBrand() (see lib/providers/app_theme_provider.dart) — so a
-- color saved here shows up on every resident's phone within a second, with no
-- app update and no manual refresh.
--
-- HOW TO RUN: Supabase Dashboard -> SQL Editor -> New query -> paste this whole
-- file -> Run. Safe to re-run.

-- ─────────────────────────────────────────────────────────
-- TABLE — a single row (id = 1) holds the active palette.
-- ─────────────────────────────────────────────────────────
create table if not exists public.app_theme (
  id           int primary key default 1,
  brand_color  text not null default '#4C229C',  -- heritagePurple (headers, FAB, accents)
  accent_color text not null default '#0056A3',  -- milaorBlue (links, focused inputs, buttons)
  updated_at   timestamptz not null default now(),
  constraint app_theme_singleton check (id = 1)
);

-- Keep updated_at fresh on every publish from the admin panel.
create or replace function public.touch_app_theme()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists app_theme_touch_updated_at on public.app_theme;
create trigger app_theme_touch_updated_at
  before update on public.app_theme
  for each row execute function public.touch_app_theme();

-- ─────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- Residents (even signed-out, so the theme applies on the very first launch)
-- may READ the palette. Only authenticated admins may change it.
-- ─────────────────────────────────────────────────────────
alter table public.app_theme enable row level security;

drop policy if exists "Anyone can view app theme" on public.app_theme;
create policy "Anyone can view app theme"
  on public.app_theme for select
  using (true);

drop policy if exists "Authenticated users can insert app theme" on public.app_theme;
create policy "Authenticated users can insert app theme"
  on public.app_theme for insert to authenticated
  with check (true);

drop policy if exists "Authenticated users can update app theme" on public.app_theme;
create policy "Authenticated users can update app theme"
  on public.app_theme for update to authenticated
  using (true);

-- ─────────────────────────────────────────────────────────
-- SEED — the shipped Maylaud palette, so the app has something to read.
-- ─────────────────────────────────────────────────────────
insert into public.app_theme (id, brand_color, accent_color)
values (1, '#4C229C', '#0056A3')
on conflict (id) do nothing;

-- ─────────────────────────────────────────────────────────
-- REALTIME — the mobile app subscribes to changes on this table.
-- REPLICA IDENTITY FULL makes UPDATE payloads carry the whole row.
-- ─────────────────────────────────────────────────────────
alter table public.app_theme replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_theme'
  ) then
    alter publication supabase_realtime add table public.app_theme;
  end if;
end $$;
