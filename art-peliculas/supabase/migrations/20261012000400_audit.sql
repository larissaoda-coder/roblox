-- =====================================================================
-- Art Películas — histórico de alterações relevantes
-- =====================================================================

create table public.audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id text,
  record_label text,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  changed_by uuid references public.profiles (id) on delete set null,
  changed_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb
);

create index audit_log_changed_at_idx on public.audit_log (changed_at desc);
create index audit_log_record_idx on public.audit_log (table_name, record_id);
create index audit_log_changed_by_idx on public.audit_log (changed_by);

comment on table public.audit_log is 'Histórico de alterações. Escrito somente por gatilhos; leitura exige a permissão historico.ver.';

create or replace function public.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_changed jsonb;
  v_label text;
  v_record_id text;
  v_actor uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_row := v_new;
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_row := to_jsonb(new);
    -- Guarda somente os campos alterados (exceto carimbos de data automáticos).
    select jsonb_object_agg(n.key, n.value) into v_changed
    from jsonb_each(v_row) n
    where n.key not in ('updated_at', 'updated_by')
      and (v_old -> n.key) is distinct from n.value;
    if v_changed is null then
      return new;
    end if;
    select jsonb_object_agg(k, v_old -> k) into v_old from jsonb_object_keys(v_changed) k;
    v_new := v_changed;
  else
    v_old := to_jsonb(old);
    v_row := v_old;
  end if;

  v_record_id := case tg_table_name
    when 'role_permissions' then (v_row ->> 'role') || ':' || (v_row ->> 'permission')
    when 'vehicle_films' then (v_row ->> 'vehicle_id') || ':' || (v_row ->> 'film_id')
    else v_row ->> 'id'
  end;

  v_label := case tg_table_name
    when 'customers' then v_row ->> 'name'
    when 'quotes' then 'ORC-' || lpad(v_row ->> 'number', 5, '0')
    when 'service_orders' then 'OS-' || lpad(v_row ->> 'number', 5, '0')
    when 'vehicles' then concat_ws(' ', v_row ->> 'brand', v_row ->> 'model', nullif(v_row ->> 'generation', ''))
    when 'films' then concat_ws(' ', v_row ->> 'manufacturer', v_row ->> 'name', nullif(v_row ->> 'product_line', ''))
    when 'profiles' then coalesce(nullif(v_row ->> 'full_name', ''), v_row ->> 'email')
    when 'service_types' then v_row ->> 'name'
    when 'settings' then 'Configurações gerais'
    when 'role_permissions' then (v_row ->> 'role') || ' · ' || (v_row ->> 'permission')
    when 'vehicle_images' then (
      select concat_ws(' ', v.brand, v.model, nullif(v.generation, '')) from public.vehicles v where v.id = (v_row ->> 'vehicle_id')::uuid)
    when 'vehicle_films' then (
      select concat_ws(' ', v.brand, v.model, nullif(v.generation, '')) || ' · ' || f.name
      from public.vehicles v, public.films f
      where v.id = (v_row ->> 'vehicle_id')::uuid and f.id = (v_row ->> 'film_id')::uuid)
    else null
  end;

  insert into public.audit_log (table_name, record_id, record_label, action, changed_by, old_data, new_data)
  values (
    tg_table_name,
    v_record_id,
    v_label,
    tg_op,
    case when v_actor is not null and exists (select 1 from public.profiles p where p.id = v_actor) then v_actor end,
    v_old,
    v_new
  );

  return coalesce(new, old);
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'role_permissions', 'settings', 'vehicles', 'vehicle_images', 'films',
    'vehicle_films', 'service_types', 'customers', 'quotes', 'service_orders'
  ] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_trigger()',
      t || '_audit', t
    );
  end loop;
end;
$$;
