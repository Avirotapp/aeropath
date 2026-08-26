-- AeroPath v1.3: booking-linked preparation, session files, programmes and staff history
-- Run once AFTER v1.2.

create table if not exists public.training_programs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.student_programs (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  comment text,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  unique(student_id, program_id)
);

insert into public.training_programs(name) values ('RPC'),('JAP'),('YAP')
on conflict(name) do nothing;

alter table public.student_programs enable row level security;
create policy "student programs read own staff" on public.student_programs for select to authenticated
using(student_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "student programs staff insert" on public.student_programs for insert to authenticated
with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and assigned_by=auth.uid());
create policy "student programs staff update" on public.student_programs for update to authenticated
using(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR')) with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));

alter table public.training_programs enable row level security;
create policy "programs read active staff" on public.training_programs for select to authenticated
using(active=true or public.my_role()='ADMINISTRATOR');
create policy "programs admin write" on public.training_programs for all to authenticated
using(public.my_role()='ADMINISTRATOR') with check(public.my_role()='ADMINISTRATOR');

create table if not exists public.preflight_preparations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  departure_icao text,
  arrival_icao text,
  sunrise text,
  sunset text,
  notam text,
  metar text,
  taf text,
  weight_balance text,
  departure_takeoff_run text,
  departure_takeoff_distance text,
  departure_tora text,
  departure_lda text,
  arrival_landing_run text,
  arrival_tora text,
  arrival_lda text,
  status text not null default 'DRAFT' check(status in ('DRAFT','SUBMITTED','CHANGES_REQUESTED','APPROVED')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.preflight_reviews (
  id uuid primary key default gen_random_uuid(),
  preparation_id uuid not null references public.preflight_preparations(id) on delete cascade,
  instructor_id uuid not null references public.profiles(id) on delete restrict,
  decision text not null check(decision in ('CHANGES_REQUESTED','APPROVED')),
  comment text,
  created_at timestamptz not null default now()
);

alter table public.preflight_preparations enable row level security;
alter table public.preflight_reviews enable row level security;
create policy "preflight student staff read" on public.preflight_preparations for select to authenticated
using(student_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "preflight student insert" on public.preflight_preparations for insert to authenticated
with check(student_id=auth.uid());
create policy "preflight student update" on public.preflight_preparations for update to authenticated
using(student_id=auth.uid() and status in ('DRAFT','CHANGES_REQUESTED'))
with check(student_id=auth.uid());
create policy "preflight staff update" on public.preflight_preparations for update to authenticated
using(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'))
with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "preflight reviews staff only" on public.preflight_reviews for select to authenticated
using(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));
create policy "preflight reviews staff insert" on public.preflight_reviews for insert to authenticated
with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and instructor_id=auth.uid());

alter table public.documents add column if not exists booking_id uuid references public.bookings(id) on delete cascade;
alter table public.documents add column if not exists document_scope text not null default 'GENERAL';

-- Replace the broad v1.2 document policy with session-aware permissions.
drop policy if exists "documents read" on public.documents;
create policy "documents read session aware" on public.documents for select to authenticated
using(
  owner_id=auth.uid()
  or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR')
);

drop policy if exists "documents insert own" on public.documents;
create policy "documents insert session aware" on public.documents for insert to authenticated
with check(
  owner_id=auth.uid()
  and (
    public.my_role()='STUDENT'
    or (public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and audience='INSTRUCTOR_REFERENCE')
    or (public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and document_scope='INSTRUCTOR_SESSION')
  )
);

-- Students must not be able to read internal training records or instructor comments.
drop policy if exists "training read student staff" on public.training_records;
create policy "training staff read only" on public.training_records for select to authenticated
using(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));

create index if not exists preflight_booking_idx on public.preflight_preparations(booking_id);
create index if not exists preflight_student_idx on public.preflight_preparations(student_id, created_at desc);
create index if not exists session_documents_booking_idx on public.documents(booking_id, created_at desc);

-- Touch updated_at whenever a preparation is edited.
create or replace function public.touch_preflight_updated_at() returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end $$;
drop trigger if exists preflight_updated_at on public.preflight_preparations;
create trigger preflight_updated_at before update on public.preflight_preparations for each row execute function public.touch_preflight_updated_at();
