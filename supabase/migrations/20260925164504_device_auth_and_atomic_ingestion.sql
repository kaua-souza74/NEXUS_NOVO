-- Device credentials are never readable by browser roles. The API stores only
-- a SHA-256 hash of a high-entropy random token.
create table public.device_credentials (
  device_id uuid primary key references public.devices (id) on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

alter table public.device_credentials enable row level security;
revoke all on table public.device_credentials from public, anon, authenticated;
grant all on public.device_credentials to service_role;

-- Called only by the server's secret-key client. One function call makes the
-- last_seen update and all five readings one database transaction.
create or replace function public.ingest_device_readings(
  p_device_uuid uuid,
  p_temperature numeric,
  p_humidity numeric,
  p_presence boolean,
  p_light numeric,
  p_door_open boolean
)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_recorded_at timestamptz := clock_timestamp();
begin
  if p_temperature is null or p_temperature < -40 or p_temperature > 80
    or p_humidity is null or p_humidity < 0 or p_humidity > 100
    or p_presence is null
    or p_light is null or p_light < 0
    or p_door_open is null then
    raise exception using errcode = '22023', message = 'invalid_sensor_values';
  end if;

  update public.devices
  set last_seen_at = v_recorded_at
  where id = p_device_uuid;

  if not found then
    raise exception using errcode = 'P0002', message = 'device_not_found';
  end if;

  insert into public.sensor_readings
    (device_id, sensor_type, value_numeric, value_boolean, unit, recorded_at)
  values
    (p_device_uuid, 'temperature', p_temperature, null, '°C', v_recorded_at),
    (p_device_uuid, 'humidity', p_humidity, null, '%', v_recorded_at),
    (p_device_uuid, 'presence', null, p_presence, null, v_recorded_at),
    (p_device_uuid, 'light', p_light, null, 'raw', v_recorded_at),
    (p_device_uuid, 'door', null, p_door_open, null, v_recorded_at);

  return v_recorded_at;
end;
$$;

revoke all on function public.ingest_device_readings(uuid, numeric, numeric, boolean, numeric, boolean)
  from public, anon, authenticated;
grant execute on function public.ingest_device_readings(uuid, numeric, numeric, boolean, numeric, boolean)
  to service_role;
