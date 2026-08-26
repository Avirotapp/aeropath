-- AeroPath v1.2: instructor reference library + training records
-- Run this ONCE in Supabase SQL Editor after the v1.1 schema is already installed.

alter table public.documents
  add column if not exists uploaded_by uuid references public.profiles(id) on delete set null,
  add column if not exists audience text not null default 'OWNER',
  add column if not exists mime_type text,
  add column if not exists file_size bigint;

create table if not exists public.training_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  instructor_id uuid references public.profiles(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  simulator_id uuid references public.simulators(id) on delete set null,
  session_date date not null default current_date,
  lesson_title text not null,
  duration_minutes integer not null default 0 check(duration_minutes >= 0),
  grade integer check(grade between 1 and 5),
  comments text,
  created_at timestamptz not null default now()
);

alter table public.training_records enable row level security;

drop policy if exists "training read student staff" on public.training_records;
create policy "training read student staff" on public.training_records for select to authenticated
using(student_id=auth.uid() or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));

drop policy if exists "training staff insert" on public.training_records;
create policy "training staff insert" on public.training_records for insert to authenticated
with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and instructor_id=auth.uid());

drop policy if exists "training staff update" on public.training_records;
create policy "training staff update" on public.training_records for update to authenticated
using(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'))
with check(public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'));

-- Instructor/admin reference documents are visible to all instructors/admins.
drop policy if exists "documents read" on public.documents;
create policy "documents read" on public.documents for select to authenticated
using(
  owner_id=auth.uid()
  or (audience='INSTRUCTOR_REFERENCE' and public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'))
  or public.my_role()='ADMINISTRATOR'
);

drop policy if exists "documents insert own" on public.documents;
create policy "documents insert own" on public.documents for insert to authenticated
with check(
  owner_id=auth.uid()
  and (
    public.my_role()='STUDENT'
    or (public.my_role() in ('INSTRUCTOR','ADMINISTRATOR') and audience='INSTRUCTOR_REFERENCE')
  )
);

-- Allow staff to upload reference files under their own storage folder.
drop policy if exists "storage own upload" on storage.objects;
create policy "storage own upload" on storage.objects for insert to authenticated
with check(
  bucket_id='aeropath-documents'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "storage own/staff read" on storage.objects;
create policy "storage own/staff read" on storage.objects for select to authenticated
using(
  bucket_id='aeropath-documents'
  and ((storage.foldername(name))[1]=auth.uid()::text or public.my_role() in ('INSTRUCTOR','ADMINISTRATOR'))
);

create index if not exists training_records_student_date_idx
  on public.training_records(student_id, session_date desc);
create index if not exists documents_audience_idx
  on public.documents(audience, created_at desc);

-- Keep the profile's simulator-hour total in sync with training records.
create or replace function public.recalculate_student_sim_hours(p_student uuid)
returns void language sql security definer set search_path=public as $$
  update public.profiles
  set total_sim_hours = coalesce((
    select round(sum(duration_minutes)::numeric / 60, 2)
    from public.training_records
    where student_id=p_student
  ), 0)
  where id=p_student;
$$;

create or replace function public.training_record_hours_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='DELETE' then
    perform public.recalculate_student_sim_hours(old.student_id);
    return old;
  end if;
  perform public.recalculate_student_sim_hours(new.student_id);
  if tg_op='UPDATE' and old.student_id<>new.student_id then
    perform public.recalculate_student_sim_hours(old.student_id);
  end if;
  return new;
end $$;

drop trigger if exists training_record_hours on public.training_records;
create trigger training_record_hours
after insert or update or delete on public.training_records
for each row execute function public.training_record_hours_trigger();
