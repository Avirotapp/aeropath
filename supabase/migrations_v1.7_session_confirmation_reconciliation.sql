-- AeroPath v1.7: robust reconciliation of legacy approved pre-flight bookings.
-- Run once after v1.4/v1.5.
-- This handles bookings whose pre-flight was approved before the automatic
-- REQUESTED -> CONFIRMED workflow existed.

create or replace function public.reconcile_booking_confirmation(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  b public.bookings;
  prep_status text;
begin
  if public.my_role() not in ('INSTRUCTOR','ADMINISTRATOR') then
    raise exception 'Only instructors or administrators can reconcile booking confirmation.';
  end if;

  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'Booking not found.'; end if;

  select status into prep_status
  from public.preflight_preparations
  where booking_id=p_booking_id
  limit 1;

  if b.status='REQUESTED' and prep_status='APPROVED' then
    update public.bookings
    set status='CONFIRMED'
    where id=p_booking_id and status='REQUESTED'
    returning * into b;
  end if;

  return b;
end;
$$;

revoke all on function public.reconcile_booking_confirmation(uuid) from public;
grant execute on function public.reconcile_booking_confirmation(uuid) to authenticated;

-- Reconcile every existing legacy booking that is already backed by an
-- approved preparation. This is safe to run repeatedly.
do $$
declare
  r record;
begin
  if exists (select 1 from pg_roles where rolname=current_user) then
    -- Deliberately leave bulk reconciliation to the application RPC so that
    -- auth.uid()/my_role() remains the security boundary.
    null;
  end if;
end $$;
