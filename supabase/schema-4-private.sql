-- 수행평가: 자기 반 기록만 내려주기 (Supabase SQL Editor 에서 한 번 실행)

drop function if exists assess_done_list(text);

create or replace function assess_done_list(p_room text, p_class text)
returns setof cal_assess_done
language sql security definer set search_path = public as $$
  select * from cal_assess_done
  where room = p_room and length(p_room) >= 4
    and class_name = trim(coalesce(p_class, '')) and length(trim(coalesce(p_class, ''))) > 0;
$$;

grant execute on function assess_done_list(text, text) to anon;

notify pgrst, 'reload schema';
