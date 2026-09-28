-- NEXUS's first tenant-aware data model. User-generated IoT readings are
-- written by a trusted server ingestion path; browser users can only read them.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hotels (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.hotel_members (
  hotel_id uuid not null references public.hotels (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('admin', 'operator', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (hotel_id, user_id)
);

create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  type text not null default 'room'
    check (type in ('room', 'reception', 'restaurant', 'corridor', 'other')),
  floor text,
  created_at timestamptz not null default now(),
  unique (hotel_id, id),
  unique (hotel_id, name)
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels (id) on delete cascade,
  space_id uuid not null,
  device_id text not null unique check (length(trim(device_id)) > 0),
  name text not null check (length(trim(name)) > 0),
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  unique (hotel_id, id),
  foreign key (hotel_id, space_id)
    references public.spaces (hotel_id, id) on delete cascade
);

-- Boolean states stay boolean (presence=true, door=true means open), while
-- measurements stay numeric. This avoids ambiguous string/number coercion.
create table public.sensor_readings (
  id bigint generated always as identity primary key,
  device_id uuid not null references public.devices (id) on delete cascade,
  sensor_type text not null
    check (sensor_type in ('temperature', 'humidity', 'presence', 'light', 'door')),
  value_numeric numeric,
  value_boolean boolean,
  unit text,
  recorded_at timestamptz not null default now(),
  constraint sensor_readings_typed_value_check check (
    (sensor_type = 'temperature' and value_numeric between -80 and 150 and value_boolean is null and unit = '°C') or
    (sensor_type = 'humidity' and value_numeric between 0 and 100 and value_boolean is null and unit = '%') or
    (sensor_type = 'light' and value_numeric >= 0 and value_boolean is null and unit in ('lux', 'raw')) or
    (sensor_type in ('presence', 'door') and value_numeric is null and value_boolean is not null and unit is null)
  )
);

create index hotel_members_user_id_hotel_id_idx
  on public.hotel_members (user_id, hotel_id);
create index spaces_hotel_id_idx on public.spaces (hotel_id);
create index devices_space_id_idx on public.devices (space_id);
create index sensor_readings_device_recorded_at_idx
  on public.sensor_readings (device_id, recorded_at desc);
create index sensor_readings_device_type_recorded_at_idx
  on public.sensor_readings (device_id, sensor_type, recorded_at desc);

-- A private SECURITY DEFINER lookup avoids recursive RLS when policies check
-- hotel_members. It is not in an exposed API schema and only trusts auth.uid().
create function private.has_hotel_role(_hotel_id uuid, _roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.hotel_members as hm
    where hm.hotel_id = _hotel_id
      and hm.user_id = (select auth.uid())
      and hm.role = any (_roles)
  );
$$;

revoke all on function private.has_hotel_role(uuid, text[]) from public, anon;
grant execute on function private.has_hotel_role(uuid, text[]) to authenticated;

alter table public.profiles enable row level security;
alter table public.hotels enable row level security;
alter table public.hotel_members enable row level security;
alter table public.spaces enable row level security;
alter table public.devices enable row level security;
alter table public.sensor_readings enable row level security;

create policy "Profiles: read own profile"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy "Profiles: insert own profile"
  on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy "Profiles: update own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "Hotels: members can read their hotels"
  on public.hotels for select to authenticated
  using ((select private.has_hotel_role(id, array['admin', 'operator', 'viewer']::text[])));
create policy "Hotels: admins can update their hotels"
  on public.hotels for update to authenticated
  using ((select private.has_hotel_role(id, array['admin']::text[])))
  with check ((select private.has_hotel_role(id, array['admin']::text[])));

create policy "Hotel members: self or hotel admins can read memberships"
  on public.hotel_members for select to authenticated
  using (
    user_id = (select auth.uid()) or
    (select private.has_hotel_role(hotel_id, array['admin']::text[]))
  );
create policy "Hotel members: admins can add members"
  on public.hotel_members for insert to authenticated
  with check ((select private.has_hotel_role(hotel_id, array['admin']::text[])));
create policy "Hotel members: admins can change roles"
  on public.hotel_members for update to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin']::text[])))
  with check ((select private.has_hotel_role(hotel_id, array['admin']::text[])));
create policy "Hotel members: admins can remove members"
  on public.hotel_members for delete to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin']::text[])));

create policy "Spaces: hotel members can read spaces"
  on public.spaces for select to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin', 'operator', 'viewer']::text[])));
create policy "Spaces: admins and operators can add spaces"
  on public.spaces for insert to authenticated
  with check ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])));
create policy "Spaces: admins and operators can update spaces"
  on public.spaces for update to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])))
  with check ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])));
create policy "Spaces: admins can delete spaces"
  on public.spaces for delete to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin']::text[])));

create policy "Devices: hotel members can read devices"
  on public.devices for select to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin', 'operator', 'viewer']::text[])));
create policy "Devices: admins and operators can add devices"
  on public.devices for insert to authenticated
  with check ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])));
create policy "Devices: admins and operators can update devices"
  on public.devices for update to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])))
  with check ((select private.has_hotel_role(hotel_id, array['admin', 'operator']::text[])));
create policy "Devices: admins can delete devices"
  on public.devices for delete to authenticated
  using ((select private.has_hotel_role(hotel_id, array['admin']::text[])));

create policy "Readings: hotel members can read device readings"
  on public.sensor_readings for select to authenticated
  using (
    exists (
      select 1 from public.devices as d
      where d.id = sensor_readings.device_id
        and (select private.has_hotel_role(d.hotel_id, array['admin', 'operator', 'viewer']::text[]))
    )
  );

grant select, insert, update on public.profiles to authenticated;
grant select, update on public.hotels to authenticated;
grant select, insert, update, delete on public.hotel_members to authenticated;
grant select, insert, update, delete on public.spaces to authenticated;
grant select, insert, update, delete on public.devices to authenticated;
grant select on public.sensor_readings to authenticated;
grant all on public.profiles, public.hotels, public.hotel_members,
  public.spaces, public.devices, public.sensor_readings to service_role;
grant usage, select on sequence public.sensor_readings_id_seq to service_role;
