-- ══════════════════════════════════════════════
-- BetIQ Pro - Supabase Database Schema
-- Run this entire file in your Supabase SQL editor
-- ══════════════════════════════════════════════

-- PROFILES table (extends Supabase auth.users)
create table if not exists profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  plan text default 'free' check (plan in ('free', 'pro', 'sharp')),
  analyses_today integer default 0,
  analyses_reset_date date default current_date,
  stripe_customer_id text,
  stripe_subscription_id text,
  plan_source text check (plan_source in ('stripe', 'apple')),
  created_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ANALYSES table (history)
create table if not exists analyses (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  sport text,
  result jsonb,
  created_at timestamptz default now()
);

-- TRACKER table (saved bets)
create table if not exists tracker (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  title text,
  sport text,
  grade text,
  probability integer,
  bet_line text,
  outcome text default 'pending' check (outcome in ('pending', 'win', 'loss')),
  created_at timestamptz default now()
);

-- Row Level Security (users only see their own data)
alter table profiles enable row level security;
alter table analyses enable row level security;
alter table tracker enable row level security;

create policy "Users see own profile" on profiles for all using (auth.uid() = id);
create policy "Users see own analyses" on analyses for all using (auth.uid() = user_id);
create policy "Users see own tracker" on tracker for all using (auth.uid() = user_id);

-- Service role bypasses RLS (your backend uses service key)
-- No additional policy needed for service role


-- ══════════════════════════════════════════════
-- MIGRATION: Apple IAP plan_source column
-- Run this if your profiles table was created before this column existed.
-- (Safe to also run on a fresh table — IF NOT EXISTS guards it.)
-- ══════════════════════════════════════════════
alter table profiles add column if not exists plan_source text check (plan_source in ('stripe', 'apple'));
