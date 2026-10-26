-- 놀이교실 신청 + 조퇴 기록 (Supabase SQL Editor 에서 한 번 실행)

create table if not exists cal_play (
  id uuid primary key default gen_random_uuid(),
  room text not null,
  day date not null,
  class_name text not null,
  author text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists cal_play_room_idx on cal_play(room, day);
alter table cal_play enable row level security;

create table if not exists cal_leave (
  id uuid primary key default gen_random_uuid(),
  room text not null,
  day date not null,
  teacher text not null,
  leave_time time not null,
  reason text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists cal_leave_room_idx on cal_leave(room, day);
alter table cal_leave enable row level security;

create or replace function play_list(p_room text)
returns setof cal_play
language sql security definer set search_path = public as $$
  select * from cal_play where room = p_room and length(p_room) >= 4 order by day, created_at;
$$;

create or replace function play_save(p_room text, p_day date, p_class text, p_author text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if length(p_room) < 4 or length(trim(p_class)) = 0 then raise exception 'bad input'; end if;
  select id into v_id from cal_play where room = p_room and day = p_day and class_name = trim(p_class);
  if v_id is not null then return v_id; end if;
  insert into cal_play (room, day, class_name, author) values (p_room, p_day, trim(p_class), coalesce(p_author,''))
  returning id into v_id;
  return v_id;
end $$;

create or replace function play_delete(p_room text, p_id uuid)
returns void
language sql security definer set search_path = public as $$
  delete from cal_play where id = p_id and room = p_room;
$$;

create or replace function leave_list(p_room text)
returns setof cal_leave
language sql security definer set search_path = public as $$
  select * from cal_leave where room = p_room and length(p_room) >= 4 order by day, leave_time;
$$;

create or replace function leave_save(p_room text, p_day date, p_teacher text, p_time time, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if length(p_room) < 4 or length(trim(p_teacher)) = 0 then raise exception 'bad input'; end if;
  insert into cal_leave (room, day, teacher, leave_time, reason)
  values (p_room, p_day, trim(p_teacher), p_time, coalesce(p_reason,''))
  returning id into v_id;
  return v_id;
end $$;

create or replace function leave_delete(p_room text, p_id uuid)
returns void
language sql security definer set search_path = public as $$
  delete from cal_leave where id = p_id and room = p_room;
$$;

grant execute on function
  play_list(text), play_save(text, date, text, text), play_delete(text, uuid),
  leave_list(text), leave_save(text, date, text, time, text), leave_delete(text, uuid)
to anon;

notify pgrst, 'reload schema';
