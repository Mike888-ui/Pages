-- RealEstateAI V7 Admin / Buyer / AI Bot / Photos Supabase Schema
-- 使用方式：Supabase → SQL Editor → 貼上全部 → Run
-- 注意：第一個註冊帳號會自動成為主權限人 admin，其餘帳號預設 buyer。

create extension if not exists "pgcrypto";

-- =========================
-- 1) profiles：帳號權限
-- =========================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  display_name text,
  role text not null default 'buyer' check (role in ('admin','buyer')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    case when not exists (select 1 from public.profiles) then 'admin' else 'buyer' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- =========================
-- 2) properties：賣屋物件
-- =========================
create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  created_by uuid default auth.uid(),
  title text not null,
  city text,
  district text,
  address text,
  price integer default 0,
  old_price integer default 0,
  ping numeric default 0,
  land_ping numeric default 0,
  rooms text,
  floor text,
  total_floor text,
  parking text,
  age integer default 0,
  building_type text,
  community text,
  status text default '銷售中' check (status in ('銷售中','已售出','保留中','草稿','暫停')),
  mrt text,
  school text,
  management_fee integer default 0,
  tags text,
  description text,
  defects text,
  owner_name text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- V6 舊表升級欄位：若原本已有 properties，就補齊新欄位
alter table public.properties add column if not exists created_by uuid default auth.uid();
alter table public.properties add column if not exists address text;
alter table public.properties add column if not exists land_ping numeric default 0;
alter table public.properties add column if not exists floor text;
alter table public.properties add column if not exists total_floor text;
alter table public.properties add column if not exists building_type text;
alter table public.properties add column if not exists community text;
alter table public.properties add column if not exists mrt text;
alter table public.properties add column if not exists school text;
alter table public.properties add column if not exists management_fee integer default 0;
alter table public.properties add column if not exists description text;
alter table public.properties add column if not exists updated_at timestamptz default now();

-- 如果 V6 舊表有 user_id，盡量搬到 created_by
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='properties' AND column_name='user_id'
  ) THEN
    EXECUTE 'update public.properties set created_by = user_id where created_by is null and user_id is not null';
  END IF;
END $$;

alter table public.properties enable row level security;

-- =========================
-- 3) property_photos：物件照片
-- 可放外部網址或前端上傳轉成 data URL
-- 大量正式圖片建議改用 Supabase Storage
-- =========================
create table if not exists public.property_photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  photo_url text not null,
  caption text,
  sort_order integer default 0,
  created_by uuid default auth.uid(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.property_photos enable row level security;

-- =========================
-- 4) buyer_questions：買方詢問 + AI BOT 回覆
-- =========================
create table if not exists public.buyer_questions (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid default auth.uid(),
  property_id uuid references public.properties(id) on delete set null,
  buyer_name text,
  contact text,
  question text not null,
  intent text,
  bot_answer text,
  status text default '新問題' check (status in ('新問題','已回覆','已預約','結案')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.buyer_questions enable row level security;

-- =========================
-- 5) V6 舊資料表保留：customers / bot_records 等
-- =========================
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  name text not null,
  phone text,
  line_id text,
  area text,
  budget_min integer default 0,
  budget_max integer default 0,
  rooms text,
  parking text,
  keywords text,
  stage text,
  score integer default 50,
  next_followup date,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.bot_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  platform text,
  user_message text,
  intent text,
  bot_reply text,
  created_at timestamptz default now()
);

alter table public.customers enable row level security;
alter table public.bot_records enable row level security;

-- =========================
-- 6) RLS Policies：先刪除舊版與新版可能重複的 policy
-- =========================
drop policy if exists "profiles_select" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;

drop policy if exists "properties_select_own" on public.properties;
drop policy if exists "properties_insert_own" on public.properties;
drop policy if exists "properties_update_own" on public.properties;
drop policy if exists "properties_delete_own" on public.properties;
drop policy if exists "properties_select_authenticated" on public.properties;
drop policy if exists "properties_insert_admin" on public.properties;
drop policy if exists "properties_update_admin" on public.properties;
drop policy if exists "properties_delete_admin" on public.properties;

drop policy if exists "property_photos_select_authenticated" on public.property_photos;
drop policy if exists "property_photos_insert_admin" on public.property_photos;
drop policy if exists "property_photos_update_admin" on public.property_photos;
drop policy if exists "property_photos_delete_admin" on public.property_photos;

drop policy if exists "buyer_questions_select" on public.buyer_questions;
drop policy if exists "buyer_questions_insert_self" on public.buyer_questions;
drop policy if exists "buyer_questions_update_admin" on public.buyer_questions;
drop policy if exists "buyer_questions_delete_admin" on public.buyer_questions;

drop policy if exists "customers_select_own" on public.customers;
drop policy if exists "customers_insert_own" on public.customers;
drop policy if exists "customers_update_own" on public.customers;
drop policy if exists "customers_delete_own" on public.customers;
drop policy if exists "bot_records_select_own" on public.bot_records;
drop policy if exists "bot_records_insert_own" on public.bot_records;
drop policy if exists "bot_records_update_own" on public.bot_records;
drop policy if exists "bot_records_delete_own" on public.bot_records;

-- profiles：每個人可看自己；admin 可看全部與調整權限
create policy "profiles_select" on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_admin());

create policy "profiles_insert_self" on public.profiles
for insert to authenticated
with check (id = auth.uid() and role = 'buyer');

create policy "profiles_update_admin" on public.profiles
for update to authenticated
using (public.is_admin())
with check (true);

-- properties：登入會員可看非草稿/非暫停物件；admin 可管理全部
create policy "properties_select_authenticated" on public.properties
for select to authenticated
using (public.is_admin() or status in ('銷售中','已售出','保留中'));

create policy "properties_insert_admin" on public.properties
for insert to authenticated
with check (public.is_admin());

create policy "properties_update_admin" on public.properties
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "properties_delete_admin" on public.properties
for delete to authenticated
using (public.is_admin());

-- property_photos：登入會員可看公開物件照片；admin 可管理
create policy "property_photos_select_authenticated" on public.property_photos
for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.properties p
    where p.id = property_photos.property_id
      and p.status in ('銷售中','已售出','保留中')
  )
);

create policy "property_photos_insert_admin" on public.property_photos
for insert to authenticated
with check (public.is_admin());

create policy "property_photos_update_admin" on public.property_photos
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "property_photos_delete_admin" on public.property_photos
for delete to authenticated
using (public.is_admin());

-- buyer_questions：買方看自己的問題；admin 看全部；買方可新增自己的問題
create policy "buyer_questions_select" on public.buyer_questions
for select to authenticated
using (public.is_admin() or buyer_id = auth.uid());

create policy "buyer_questions_insert_self" on public.buyer_questions
for insert to authenticated
with check (buyer_id = auth.uid());

create policy "buyer_questions_update_admin" on public.buyer_questions
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "buyer_questions_delete_admin" on public.buyer_questions
for delete to authenticated
using (public.is_admin());

-- V6 customers / bot_records：保留自己資料隔離
create policy "customers_select_own" on public.customers for select to authenticated using (auth.uid() = user_id or public.is_admin());
create policy "customers_insert_own" on public.customers for insert to authenticated with check (auth.uid() = user_id or public.is_admin());
create policy "customers_update_own" on public.customers for update to authenticated using (auth.uid() = user_id or public.is_admin());
create policy "customers_delete_own" on public.customers for delete to authenticated using (auth.uid() = user_id or public.is_admin());

create policy "bot_records_select_own" on public.bot_records for select to authenticated using (auth.uid() = user_id or public.is_admin());
create policy "bot_records_insert_own" on public.bot_records for insert to authenticated with check (auth.uid() = user_id or public.is_admin());
create policy "bot_records_update_own" on public.bot_records for update to authenticated using (auth.uid() = user_id or public.is_admin());
create policy "bot_records_delete_own" on public.bot_records for delete to authenticated using (auth.uid() = user_id or public.is_admin());

-- =========================
-- 7) Demo Data，可自行刪除
-- 只有 admin 登入後才可新增正式資料
-- =========================
-- 如需手動指定主權限人：
-- update public.profiles set role='admin' where email='你的信箱@example.com';
