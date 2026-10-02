-- Viroh Automation portfolio: Supabase setup
-- Run the whole file once in Supabase → SQL Editor → New query → Run.
-- Safe to re-run: it updates policies and settings without deleting your data.
-- Create your admin user first (README step 3) so the last statement can register it.

-- ---------- Admins ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security; -- no policies: never readable through the API
revoke all on public.admins from anon, authenticated;

-- true only for a listed admin who has also passed the authenticator (MFA) check
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce(auth.jwt()->>'aal', '') = 'aal2'
     and exists (select 1 from public.admins a where a.user_id = auth.uid())
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- Dashboards ----------
create table if not exists public.dashboards (
  id           bigint generated always as identity primary key,
  name         text not null check (char_length(name) between 1 and 80),
  tool         text not null default 'Interactive HTML' check (char_length(tool) between 1 and 30),
  status       text not null default 'dr' check (status in ('pub', 'dr')),
  description  text not null default '' check (char_length(description) <= 200),
  metric       text not null default '' check (char_length(metric) <= 12),
  metric_label text not null default '' check (char_length(metric_label) <= 40),
  kpis         jsonb,
  color        text not null default '#5a9b78' check (color ~ '^#[0-9a-fA-F]{6}$'),
  bg           text not null default '#dcebe2' check (bg ~ '^#[0-9a-fA-F]{6}$'),
  file_path    text unique,
  sort         int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists dashboards_touch on public.dashboards;
create trigger dashboards_touch before update on public.dashboards
  for each row execute function public.touch_updated_at();

alter table public.dashboards enable row level security;
drop policy if exists "public reads published" on public.dashboards;
drop policy if exists "admin reads all"        on public.dashboards;
drop policy if exists "admin inserts"          on public.dashboards;
drop policy if exists "admin updates"          on public.dashboards;
drop policy if exists "admin deletes"          on public.dashboards;
create policy "public reads published" on public.dashboards for select to anon, authenticated using (status = 'pub');
create policy "admin reads all"        on public.dashboards for select to authenticated using (public.is_admin());
create policy "admin inserts"          on public.dashboards for insert to authenticated with check (public.is_admin());
create policy "admin updates"          on public.dashboards for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes"          on public.dashboards for delete to authenticated using (public.is_admin());

grant select on public.dashboards to anon, authenticated;
grant insert, update, delete on public.dashboards to authenticated;

-- ---------- Site settings (contact details, single row) ----------
create table if not exists public.site_settings (
  id         int primary key default 1 check (id = 1),
  phone      text not null default '' check (char_length(phone) <= 20),
  email      text not null default '' check (char_length(email) <= 120),
  updated_at timestamptz not null default now()
);

drop trigger if exists site_settings_touch on public.site_settings;
create trigger site_settings_touch before update on public.site_settings
  for each row execute function public.touch_updated_at();

alter table public.site_settings enable row level security;
drop policy if exists "public reads settings" on public.site_settings;
drop policy if exists "admin updates settings" on public.site_settings;
create policy "public reads settings"  on public.site_settings for select to anon, authenticated using (true);
create policy "admin updates settings" on public.site_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

grant select on public.site_settings to anon, authenticated;
grant update on public.site_settings to authenticated;

insert into public.site_settings (id, phone, email)
values (1, '+91 81085 08781', 'padavepranay01@gmail.com')
on conflict (id) do nothing;

-- ---------- Storage bucket for uploaded HTML dashboards ----------
-- Private bucket: files are only readable when their dashboard row is published (or by the admin).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dashboards', 'dashboards', false, 2000000, array['text/html'])
on conflict (id) do update set public = false, file_size_limit = 2000000, allowed_mime_types = array['text/html'];

drop policy if exists "public reads published dashboard files" on storage.objects;
drop policy if exists "admin reads dashboard files"            on storage.objects;
drop policy if exists "admin uploads dashboard files"          on storage.objects;
drop policy if exists "admin updates dashboard files"          on storage.objects;
drop policy if exists "admin deletes dashboard files"          on storage.objects;
create policy "public reads published dashboard files" on storage.objects for select to anon, authenticated
  using (bucket_id = 'dashboards' and exists (
    select 1 from public.dashboards d where d.file_path = objects.name and d.status = 'pub'));
create policy "admin reads dashboard files"   on storage.objects for select to authenticated using (bucket_id = 'dashboards' and public.is_admin());
create policy "admin uploads dashboard files" on storage.objects for insert to authenticated with check (bucket_id = 'dashboards' and public.is_admin());
create policy "admin updates dashboard files" on storage.objects for update to authenticated using (bucket_id = 'dashboards' and public.is_admin()) with check (bucket_id = 'dashboards' and public.is_admin());
create policy "admin deletes dashboard files" on storage.objects for delete to authenticated using (bucket_id = 'dashboards' and public.is_admin());

-- ---------- Sample dashboards (only added when the table is empty) ----------
insert into public.dashboards (name, tool, status, description, metric, metric_label, kpis, color, bg, sort)
select * from (values
  ('Fulfillment Control Tower', 'Power BI', 'pub',
   'Live visibility into order flow, SLA risk, carrier performance, and fulfillment bottlenecks.',
   '28%', 'faster issue detection',
   '["Orders shipped",18492,"","On-time rate",96.8,"%","Avg cycle",8.4,"h","Open exceptions",127,""]'::jsonb,
   '#e9946a', '#f6e5da', 10),
  ('Inventory Health Monitor', 'Tableau', 'pub',
   'A single view of aging stock, sell-through, cover days, and replenishment opportunities.',
   '$184K', 'working capital identified',
   '["Stock value",184,"K","Cover days",34,"d","Sell-through",72,"%","Aged 90d+",9,"%"]'::jsonb,
   '#6f98c9', '#e0e8f3', 20),
  ('Warehouse Productivity', 'Advanced Excel', 'dr',
   'Shift-level labor planning and productivity tracking across pick, pack, and dispatch.',
   '16%', 'productivity improvement',
   '["Units / hour",112,"","Utilization",87,"%","Labor cost",41,"K","Pick accuracy",99.2,"%"]'::jsonb,
   '#5a9b78', '#dcebe2', 30)
) as v(name, tool, status, description, metric, metric_label, kpis, color, bg, sort)
where not exists (select 1 from public.dashboards);

-- ---------- Register your admin account ----------
-- Inserts nothing if the user doesn't exist yet; create it, then re-run just this statement.
insert into public.admins (user_id)
select id from auth.users where email = 'padavepranay01@gmail.com'
on conflict do nothing;

-- Check: this should return one row with your email.
select u.email from public.admins a join auth.users u on u.id = a.user_id;
