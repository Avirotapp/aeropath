-- AeroPath v1.4: controlled instructor session lifecycle
-- Run once after v1.3.

alter table public.bookings
  add column if not exists session_status text not null default 'NOT_STARTED',
  add column if not exists session_started_at timestamptz,
  add column if not exists session_completed_at timestamptz;

alter table public.bookings drop constraint if exists bookings_session_status_check;
alter table public.bookings add constraint bookings_session_status_check
  check (session_status in ('NOT_STARTED','IN_PROGRESS','COMPLETED'));

create index if not exists bookings_instructor_active_idx
  on public.bookings(instructor_id, session_status)
  where session_status='IN_PROGRESS';

-- Prevent clients from bypassing the lifecycle with a direct bookings UPDATE.
create or replace function public.enforce_session_lifecycle()
returns trigger language plpgsql as $$
begin
  if old.session_status <> new.session_status
     and new.session_status in ('IN_PROGRESS','COMPLETED')
     and coalesce(current_setting('aeropath.session_workflow', true),'off') <> 'on' then
    raise exception 'Session status can only be changed through the AeroPath session workflow.';
  end if;
  return new;
end;
$$;

drop trigger if exists booking_session_lifecycle on public.bookings;
create trigger booking_session_lifecycle
before update on public.bookings
for each row execute function public.enforce_session_lifecycle();

-- Atomic start: only a confirmed booking can be started, and one instructor
-- cannot have more than one active session at a time.
create or replace function public.start_simulator_session(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  b public.bookings;
  active_count integer;
begin
  if public.my_role() not in ('INSTRUCTOR','ADMINISTRATOR') then
    raise exception 'Only instructors or administrators can start simulator sessions.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found.'; end if;
  if b.status <> 'CONFIRMED' then
    raise exception 'Only a confirmed booking can be started. Current booking status: %', b.status;
  end if;
  if b.session_status <> 'NOT_STARTED' then
    raise exception 'This simulator session has already been started or completed.';
  end if;

  select count(*) into active_count
  from public.bookings
  where instructor_id=auth.uid() and session_status='IN_PROGRESS';

  if active_count > 0 then
    raise exception 'You already have an active simulator session. Submit it before starting another session.';
  end if;

  perform set_config('aeropath.session_workflow','on',true);
  update public.bookings
  set session_status='IN_PROGRESS', instructor_id=auth.uid(),
      session_started_at=coalesce(session_started_at,now()), session_completed_at=null
  where id=p_booking_id
  returning * into b;

  return b;
end;
$$;

revoke all on function public.start_simulator_session(uuid) from public;
grant execute on function public.start_simulator_session(uuid) to authenticated;

-- The official training record is append-only. Creation is performed by the
-- submit RPC; instructors cannot edit or delete a submitted record.
drop policy if exists "training staff update" on public.training_records;
drop policy if exists "training staff insert" on public.training_records;
create policy "training workflow insert only" on public.training_records for insert to authenticated
with check (
  public.my_role() in ('INSTRUCTOR','ADMINISTRATOR')
  and instructor_id=auth.uid()
  and exists(
    select 1 from public.bookings b
    where b.id=booking_id and b.session_status='IN_PROGRESS' and b.instructor_id=auth.uid()
  )
);

-- Atomic finalization: create the official training record and lock the booking.
create or replace function public.submit_simulator_session(
  p_booking_id uuid,
  p_lesson_title text,
  p_duration_minutes integer,
  p_grade integer default null,
  p_comments text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  b public.bookings;
  record_id uuid;
begin
  if public.my_role() not in ('INSTRUCTOR','ADMINISTRATOR') then
    raise exception 'Only instructors or administrators can submit simulator sessions.';
  end if;
  if nullif(trim(p_lesson_title),'') is null then raise exception 'Training activity / lesson is required.'; end if;
  if p_duration_minutes is null or p_duration_minutes < 0 then raise exception 'Duration must be zero or greater.'; end if;
  if p_grade is not null and (p_grade < 1 or p_grade > 5) then raise exception 'Grade must be between 1 and 5.'; end if;

  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found.'; end if;
  if b.session_status <> 'IN_PROGRESS' then raise exception 'Only an in-progress session can be submitted.'; end if;
  if b.instructor_id <> auth.uid() and public.my_role() <> 'ADMINISTRATOR' then
    raise exception 'This session is assigned to another instructor.';
  end if;
  if exists(select 1 from public.training_records where booking_id=p_booking_id) then
    raise exception 'A training record already exists for this booking.';
  end if;

  insert into public.training_records(
    student_id,instructor_id,booking_id,simulator_id,session_date,
    lesson_title,duration_minutes,grade,comments
  )
  values(
    b.student_id,coalesce(b.instructor_id,auth.uid()),b.id,b.simulator_id,
    (coalesce(b.session_started_at,now()))::date,trim(p_lesson_title),
    p_duration_minutes,p_grade,nullif(trim(p_comments),'')
  )
  returning id into record_id;

  perform set_config('aeropath.session_workflow','on',true);
  update public.bookings
  set session_status='COMPLETED', status='COMPLETED', session_completed_at=now()
  where id=p_booking_id;

  return record_id;
end;
$$;

revoke all on function public.submit_simulator_session(uuid,text,integer,integer,text) from public;
grant execute on function public.submit_simulator_session(uuid,text,integer,integer,text) to authenticated;
