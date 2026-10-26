-- 학급 선생님 공유 캘린더 (Supabase SQL Editor 에서 한 번 실행)
-- 표는 잠가 두고(정책 없음), 공유 코드를 아는 사람만 함수로 읽고 쓰게 합니다.

create table if not exists cal_events (
  id uuid primary key default gen_random_uuid(),
  room text not null,
  title text not null,
  start_date date not null,
  end_date date not null,
  all_day boolean not null default true,
  start_time time,
  end_time time,
  place text not null default '',
  memo text not null default '',
  category text not null default '기타',
  author text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists cal_events_room_idx on cal_events(room, start_date);
alter table cal_events enable row level security;

create or replace function cal_list(p_room text)
returns setof cal_events
language sql security definer set search_path = public as $$
  select * from cal_events
  where room = p_room and length(p_room) >= 4
  order by start_date, start_time nulls first;
$$;

create or replace function cal_save(p_room text, p_ev jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid := nullif(p_ev->>'id','')::uuid;
begin
  if length(p_room) < 4 then raise exception 'bad room'; end if;
  if v_id is not null and exists (select 1 from cal_events where id = v_id and room = p_room) then
    update cal_events set
      title = p_ev->>'title',
      start_date = (p_ev->>'start_date')::date,
      end_date = (p_ev->>'end_date')::date,
      all_day = (p_ev->>'all_day')::boolean,
      start_time = nullif(p_ev->>'start_time','')::time,
      end_time = nullif(p_ev->>'end_time','')::time,
      place = coalesce(p_ev->>'place',''),
      memo = coalesce(p_ev->>'memo',''),
      category = coalesce(p_ev->>'category','기타'),
      author = coalesce(p_ev->>'author',''),
      updated_at = now()
    where id = v_id and room = p_room;
    return v_id;
  end if;
  insert into cal_events (room, title, start_date, end_date, all_day, start_time, end_time, place, memo, category, author)
  values (p_room, p_ev->>'title', (p_ev->>'start_date')::date, (p_ev->>'end_date')::date,
          (p_ev->>'all_day')::boolean, nullif(p_ev->>'start_time','')::time, nullif(p_ev->>'end_time','')::time,
          coalesce(p_ev->>'place',''), coalesce(p_ev->>'memo',''), coalesce(p_ev->>'category','기타'), coalesce(p_ev->>'author',''))
  returning id into v_id;
  return v_id;
end $$;

create or replace function cal_delete(p_room text, p_id uuid)
returns void
language sql security definer set search_path = public as $$
  delete from cal_events where id = p_id and room = p_room;
$$;

grant execute on function cal_list(text), cal_save(text, jsonb), cal_delete(text, uuid) to anon;
