-- Keep one NEXUS device per hotel space and remove the room-specific model.
-- The former Quarto 101 is the physical ESP32-00 test area. The existing
-- ESP32-001/Wokwi device is moved to Piscina without changing its readings or
-- credential rows.

alter table public.spaces
  drop constraint if exists spaces_type_check;

update public.spaces as s
set name = 'Sala de Testes', type = 'test'
from public.hotels as h
where s.hotel_id = h.id
  and h.name = 'Hotel Vista Real'
  and s.name = 'Quarto 101';

alter table public.spaces
  alter column type set default 'other';

alter table public.spaces
  add constraint spaces_type_check
  check (type in (
    'test', 'pool', 'lobby', 'reception', 'restaurant', 'corridor',
    'gym', 'conference', 'storage', 'garden', 'spa', 'laundry',
    'kitchen', 'outdoor', 'parking', 'other'
  ));

insert into public.spaces (hotel_id, name, type)
select id, 'Piscina', 'pool'
from public.hotels
where name = 'Hotel Vista Real'
on conflict (hotel_id, name) do update
  set type = excluded.type;

update public.devices as d
set space_id = s.id,
    name = 'Sensor Piscina'
from public.hotels as h
join public.spaces as s on s.hotel_id = h.id and s.name = 'Piscina'
where d.hotel_id = h.id
  and h.name = 'Hotel Vista Real'
  and d.device_id = 'ESP32-001';

update public.devices as d
set name = 'ESP32-00 físico'
from public.hotels as h
where d.hotel_id = h.id
  and h.name = 'Hotel Vista Real'
  and d.device_id = 'ESP32-00';

create unique index if not exists devices_one_per_space_idx
  on public.devices (hotel_id, space_id);
