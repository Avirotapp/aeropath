create extension if not exists "pgcrypto";
create type public.app_role as enum ('STUDENT','INSTRUCTOR','SAFETY_MANAGER','ADMINISTRATOR');
create type public.booking_status as enum ('REQUESTED','CONFIRMED','CANCELLED','COMPLETED','NO_SHOW');
create type public.sim_status as enum ('AVAILABLE','MAINTENANCE','INACTIVE');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, email text, role public.app_role not null default 'STUDENT',
 total_sim_hours numeric(8,2) not null default 0, created_at timestamptz not null default now()
);
create table public.simulators (
 id uuid primary key default gen_random_uuid(), name text not null,
 simulator_type text not null, status public.sim_status not null default 'AVAILABLE',
 notes text, created_at timestamptz not null default now()
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.profiles(id) on delete cascade,
 instructor_id uuid references public.profiles(id) on delete set null,
 simulator_id uuid not null references public.simulators(id) on delete restrict,
 starts_at timestamptz not null, ends_at timestamptz not null,
 status public.booking_status not null default 'REQUESTED',
 notes text, created_at timestamptz not null default now(),
 constraint booking_time_valid check (ends_at > starts_at)
);
create table public.courses (
 id uuid primary key default gen_random_uuid(), name text not null,
 description text, active boolean not null default true, created_at timestamptz not null default now()
);
create table public.lessons (
 id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses(id) on delete cascade,
 name text not null, sort_order integer not null default 0
);
create table public.student_progress (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.profiles(id) on delete cascade,
 lesson_id uuid not null references public.lessons(id) on delete cascade,
 status text not null default 'NOT_STARTED', grade integer, instructor_comment text,
 updated_at timestamptz not null default now(), unique(student_id,lesson_id)
);
create table public.documents (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, storage_path text not null, category text, created_at timestamptz not null default now()
);
create table public.safety_notices (
 id uuid primary key default gen_random_uuid(), title text not null, body text not null,
 severity text not null default 'INFO', published boolean not null default true,
 created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now()
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id) on delete set null,
 action text not null, entity_type text, entity_id uuid, details jsonb, created_at timestamptz not null default now()
);
create table public.system_modules (key text primary key, name text not null, enabled boolean not null default true);

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,email,full_name)
 values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',''));
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.my_role() returns public.app_role
language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() $$;

alter table public.profiles enable row level security;
alter table public.simulators enable row level security;
alter table public.bookings enable row level security;
alter table public.courses enable row level security;
alter table public.lessons enable row level security;
alter table public.student_progress enable row level security;
alter table public.documents enable row level security;
alter table public.safety_notices enable row level security;
alter table public.audit_logs enable row level security;
alter table public.system_modules enable row level security;

create policy "profiles read own staff" on public.profiles for select using
(id=auth.uid() or public.my_role() in ('INSTRUCTOR','SAFETY_MANAGER','ADMINISTRATOR'));
create policy "profiles update own admin" on public.profiles for update using
(id=auth.uid() or public.my_role()='ADMINISTRATOR');

create policy "sim read authenticated" on public.simulators for select to authenticated using(true);
create policy "sim admin write" on public.simulators for all to authenticated
using(public.my_role()='ADMINISTRATOR') with check(public.my_role()='ADMINISTRATOR');

create policy "booking read scoped" on public.bookings for select to authenticated using
(student_id=auth.uid() or instructor_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "booking student insert" on public.bookings for insert to authenticated with check(student_id=auth.uid());
create policy "booking update scoped" on public.bookings for update to authenticated
using(student_id=auth.uid() or instructor_id=auth.uid() or public.my_role()='ADMINISTRATOR');

create policy "course read" on public.courses for select to authenticated using(true);
create policy "lesson read" on public.lessons for select to authenticated using(true);
create policy "progress read" on public.student_progress for select to authenticated
using(student_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "progress insert own" on public.student_progress for insert to authenticated with check(student_id=auth.uid());
create policy "progress update" on public.student_progress for update to authenticated
using(student_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));

create policy "documents read" on public.documents for select to authenticated
using(owner_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "documents insert own" on public.documents for insert to authenticated with check(owner_id=auth.uid());
create policy "documents delete" on public.documents for delete to authenticated
using(owner_id=auth.uid() or public.my_role()='ADMINISTRATOR');

create policy "safety read" on public.safety_notices for select to authenticated
using(published=true or public.my_role() in ('SAFETY_MANAGER','ADMINISTRATOR'));
create policy "safety staff write" on public.safety_notices for all to authenticated
using(public.my_role() in ('SAFETY_MANAGER','ADMINISTRATOR'))
with check(public.my_role() in ('SAFETY_MANAGER','ADMINISTRATOR'));

create policy "audit admin read" on public.audit_logs for select to authenticated using(public.my_role()='ADMINISTRATOR');
create policy "audit insert own" on public.audit_logs for insert to authenticated with check(actor_id=auth.uid());

create policy "modules read" on public.system_modules for select to authenticated using(true);
create policy "modules admin write" on public.system_modules for all to authenticated
using(public.my_role()='ADMINISTRATOR') with check(public.my_role()='ADMINISTRATOR');

insert into storage.buckets(id,name,public) values('aeropath-documents','aeropath-documents',false)
on conflict(id) do nothing;
create policy "storage own upload" on storage.objects for insert to authenticated
with check(bucket_id='aeropath-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "storage own/staff read" on storage.objects for select to authenticated
using(bucket_id='aeropath-documents' and ((storage.foldername(name))[1]=auth.uid()::text or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR')));

create or replace function public.prevent_booking_overlap() returns trigger language plpgsql as $$
begin
 if new.status in ('REQUESTED','CONFIRMED') and exists(
   select 1 from public.bookings b where b.simulator_id=new.simulator_id
   and b.status in ('REQUESTED','CONFIRMED') and b.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
   and new.starts_at < b.ends_at and new.ends_at > b.starts_at
 ) then raise exception 'Simulator is already booked during this time.'; end if;
 return new;
end $$;
drop trigger if exists booking_overlap on public.bookings;
create trigger booking_overlap before insert or update on public.bookings
for each row execute function public.prevent_booking_overlap();
