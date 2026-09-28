-- Revoke Supabase's broad schema defaults, including TRUNCATE (which RLS
-- does not govern), then grant each client role only the required operations.
revoke all on table
  public.profiles,
  public.hotels,
  public.hotel_members,
  public.spaces,
  public.devices,
  public.sensor_readings
from public, anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, update on public.hotels to authenticated;
grant select, insert, update, delete on public.hotel_members to authenticated;
grant select, insert, update, delete on public.spaces to authenticated;
grant select, insert, update, delete on public.devices to authenticated;
grant select on public.sensor_readings to authenticated;

grant all on public.profiles, public.hotels, public.hotel_members,
  public.spaces, public.devices, public.sensor_readings to service_role;

revoke all on sequence public.sensor_readings_id_seq
  from public, anon, authenticated, service_role;
grant usage, select on sequence public.sensor_readings_id_seq to service_role;
