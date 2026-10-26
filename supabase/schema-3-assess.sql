-- 수행평가 진행 체크 (Supabase SQL Editor 에서 한 번 실행)

create table if not exists cal_assess (
  id uuid primary key default gen_random_uuid(),
  room text not null,
  subject text not null,
  unit text not null default '',
  title text not null,
  method text not null default '',
  month int not null check (month between 1 and 12),
  created_at timestamptz not null default now()
);
create index if not exists cal_assess_room_idx on cal_assess(room, month);
alter table cal_assess enable row level security;

create table if not exists cal_assess_done (
  assess_id uuid not null references cal_assess(id) on delete cascade,
  room text not null,
  class_name text not null,
  author text not null default '',
  done_at timestamptz not null default now(),
  primary key (assess_id, class_name)
);
alter table cal_assess_done enable row level security;

create table if not exists cal_meta (
  room text primary key,
  classes text not null default ''
);
alter table cal_meta enable row level security;

create or replace function assess_list(p_room text)
returns setof cal_assess
language sql security definer set search_path = public as $$
  select * from cal_assess where room = p_room and length(p_room) >= 4 order by month, subject, created_at;
$$;

create or replace function assess_done_list(p_room text)
returns setof cal_assess_done
language sql security definer set search_path = public as $$
  select * from cal_assess_done where room = p_room and length(p_room) >= 4;
$$;

create or replace function assess_save(p_room text, p_item jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if length(p_room) < 4 or length(trim(coalesce(p_item->>'title',''))) = 0 then raise exception 'bad input'; end if;
  insert into cal_assess (room, subject, unit, title, method, month)
  values (p_room, p_item->>'subject', coalesce(p_item->>'unit',''), trim(p_item->>'title'),
          coalesce(p_item->>'method',''), (p_item->>'month')::int)
  returning id into v_id;
  return v_id;
end $$;

create or replace function assess_seed(p_room text, p_items jsonb)
returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if length(p_room) < 4 then raise exception 'bad room'; end if;
  if exists (select 1 from cal_assess where room = p_room) then return 0; end if;
  insert into cal_assess (room, subject, unit, title, method, month)
  select p_room, x->>'subject', coalesce(x->>'unit',''), x->>'title', coalesce(x->>'method',''), (x->>'month')::int
  from jsonb_array_elements(p_items) x;
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function assess_delete(p_room text, p_id uuid)
returns void
language sql security definer set search_path = public as $$
  delete from cal_assess where id = p_id and room = p_room;
$$;

create or replace function assess_toggle(p_room text, p_id uuid, p_class text, p_done boolean, p_author text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from cal_assess where id = p_id and room = p_room) or length(trim(p_class)) = 0 then
    raise exception 'bad input';
  end if;
  if p_done then
    insert into cal_assess_done (assess_id, room, class_name, author)
    values (p_id, p_room, trim(p_class), coalesce(p_author,'')) on conflict do nothing;
  else
    delete from cal_assess_done where assess_id = p_id and class_name = trim(p_class);
  end if;
end $$;

create or replace function meta_get(p_room text)
returns text
language sql security definer set search_path = public as $$
  select coalesce((select classes from cal_meta where room = p_room), '');
$$;

create or replace function meta_set(p_room text, p_classes text)
returns void
language sql security definer set search_path = public as $$
  insert into cal_meta (room, classes) values (p_room, p_classes)
  on conflict (room) do update set classes = excluded.classes;
$$;

grant execute on function
  assess_list(text), assess_done_list(text), assess_save(text, jsonb), assess_seed(text, jsonb),
  assess_delete(text, uuid), assess_toggle(text, uuid, text, boolean, text), meta_get(text), meta_set(text, text)
to anon;

notify pgrst, 'reload schema';
