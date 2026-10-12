-- =====================================================================
-- Art Películas — clientes, simulações, orçamentos e ordens de serviço
-- =====================================================================

create type public.simulation_mode as enum ('imagem', 'modelo_3d', 'referencia');
create type public.quote_status as enum ('rascunho', 'enviado', 'aprovado', 'recusado', 'concluido');
create type public.quote_item_kind as enum ('pelicula', 'servico', 'outro');
create type public.service_order_status as enum ('agendado', 'em_andamento', 'concluido', 'cancelado');

-- Placa no padrão antigo (AAA9999) ou Mercosul (AAA9A99), sem hífen.
create or replace function public.normalize_plate(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(upper(coalesce(p, '')), '[^0-9A-Z]', '', 'g'), '');
$$;

create or replace function public.format_brl_percent(v numeric)
returns text
language sql
immutable
set search_path = ''
as $$
  select replace(to_char(v, 'FM990.00'), '.', ',') || '%';
$$;

-- ---------------------------------------------------------------------
-- Clientes
-- ---------------------------------------------------------------------

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  document text check (document is null or public.is_valid_cpf_cnpj(document)),
  email text check (email is null or (char_length(email) <= 160 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')),
  phone text check (phone is null or phone ~ '^[0-9]{10,13}$'),
  zip_code text check (zip_code is null or zip_code ~ '^[0-9]{8}$'),
  street text not null default '' check (char_length(street) <= 160),
  address_number text not null default '' check (char_length(address_number) <= 20),
  complement text not null default '' check (char_length(complement) <= 80),
  district text not null default '' check (char_length(district) <= 80),
  city text not null default '' check (char_length(city) <= 80),
  state text check (state is null or state ~ '^[A-Z]{2}$'),
  notes text not null default '' check (char_length(notes) <= 2000),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index customers_document_key on public.customers (document) where document is not null;
create index customers_name_idx on public.customers (lower(name));

create or replace function public.customers_normalize()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := trim(regexp_replace(coalesce(new.name, ''), '\s+', ' ', 'g'));
  new.document := public.normalize_document(new.document);
  new.phone := nullif(regexp_replace(coalesce(new.phone, ''), '\D', '', 'g'), '');
  new.zip_code := nullif(regexp_replace(coalesce(new.zip_code, ''), '\D', '', 'g'), '');
  new.email := nullif(lower(trim(coalesce(new.email, ''))), '');
  new.state := nullif(upper(trim(coalesce(new.state, ''))), '');
  return new;
end;
$$;

create trigger customers_normalize before insert or update on public.customers
  for each row execute function public.customers_normalize();
create trigger customers_set_updated_at before update on public.customers
  for each row execute function public.set_updated_at();
create trigger customers_set_created_by before insert on public.customers
  for each row execute function public.set_created_by();

-- ---------------------------------------------------------------------
-- Simulações
-- ---------------------------------------------------------------------

-- { "<zona>": { "vlt": 0-100, "film_id": "<uuid>" | null } }
create or replace function public.is_valid_simulation_config(c jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  k text;
  v jsonb;
begin
  if c is null or jsonb_typeof(c) <> 'object' then
    return false;
  end if;
  for k, v in select * from jsonb_each(c) loop
    if k not in ('para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro') or jsonb_typeof(v) <> 'object' then
      return false;
    end if;
    if jsonb_typeof(v -> 'vlt') <> 'number' or (v ->> 'vlt')::numeric < 0 or (v ->> 'vlt')::numeric > 100 then
      return false;
    end if;
    if v ? 'film_id' and jsonb_typeof(v -> 'film_id') not in ('string', 'null') then
      return false;
    end if;
    if jsonb_typeof(v -> 'film_id') = 'string'
       and (v ->> 'film_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

create table public.simulations (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  vehicle_image_id uuid references public.vehicle_images (id) on delete set null,
  mode public.simulation_mode not null,
  config jsonb not null check (public.is_valid_simulation_config(config)),
  customer_id uuid references public.customers (id) on delete set null,
  notes text not null default '' check (char_length(notes) <= 1000),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index simulations_created_idx on public.simulations (created_at desc);
create index simulations_customer_idx on public.simulations (customer_id);

create trigger simulations_set_created_by before insert on public.simulations
  for each row execute function public.set_created_by();

-- ---------------------------------------------------------------------
-- Orçamentos
-- ---------------------------------------------------------------------

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity unique,
  customer_id uuid not null references public.customers (id) on delete restrict,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  vehicle_description text not null default '' check (char_length(vehicle_description) <= 160),
  vehicle_plate text check (vehicle_plate is null or vehicle_plate ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  vehicle_year smallint check (vehicle_year between 1950 and 2100),
  vehicle_color text not null default '' check (char_length(vehicle_color) <= 40),
  simulation_id uuid references public.simulations (id) on delete set null,
  status public.quote_status not null default 'rascunho',
  valid_until date,
  discount_type text not null default 'valor' check (discount_type in ('valor', 'percentual')),
  discount_value numeric(12, 2) not null default 0 check (discount_value >= 0),
  subtotal numeric(12, 2) not null default 0 check (subtotal >= 0),
  items_discount numeric(12, 2) not null default 0 check (items_discount >= 0),
  discount_total numeric(12, 2) not null default 0 check (discount_total >= 0),
  total numeric(12, 2) not null default 0 check (total >= 0),
  discount_authorized_by uuid references public.profiles (id) on delete set null,
  discount_authorized_percent numeric(8, 4),
  notes text not null default '' check (char_length(notes) <= 4000),
  internal_notes text not null default '' check (char_length(internal_notes) <= 4000),
  sent_at timestamptz,
  decided_at timestamptz,
  completed_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index quotes_customer_idx on public.quotes (customer_id);
create index quotes_status_idx on public.quotes (status);
create index quotes_created_idx on public.quotes (created_at desc);

create trigger quotes_set_updated_at before update on public.quotes
  for each row execute function public.set_updated_at();

create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  position smallint not null default 0,
  kind public.quote_item_kind not null,
  film_id uuid references public.films (id) on delete set null,
  service_type_id uuid references public.service_types (id) on delete set null,
  glass_zones public.glass_zone[] not null default '{}',
  description text not null check (char_length(trim(description)) between 1 and 300),
  quantity numeric(10, 2) not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  discount numeric(12, 2) not null default 0 check (discount >= 0),
  total numeric(12, 2) not null check (total >= 0)
);

create index quote_items_quote_idx on public.quote_items (quote_id, position);

-- Linha do tempo do orçamento (criação, edições e mudanças de status).
create table public.quote_events (
  id bigint generated always as identity primary key,
  quote_id uuid not null references public.quotes (id) on delete cascade,
  event text not null check (event in ('criado', 'atualizado', 'status')),
  status public.quote_status,
  note text check (note is null or char_length(note) <= 500),
  created_by uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create index quote_events_quote_idx on public.quote_events (quote_id, created_at);

create or replace function public.quote_status_label(s public.quote_status)
returns text
language sql
immutable
set search_path = ''
as $$
  select case s
    when 'rascunho' then 'Rascunho'
    when 'enviado' then 'Enviado'
    when 'aprovado' then 'Aprovado'
    when 'recusado' then 'Recusado'
    when 'concluido' then 'Concluído'
  end;
$$;

-- Cria ou atualiza um orçamento com seus itens em uma única transação.
-- Os totais e a autorização de desconto são calculados no servidor.
create or replace function public.save_quote(p_quote jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := nullif(p_quote ->> 'id', '')::uuid;
  v_customer uuid := nullif(p_quote ->> 'customer_id', '')::uuid;
  v_vehicle uuid := nullif(p_quote ->> 'vehicle_id', '')::uuid;
  v_simulation uuid := nullif(p_quote ->> 'simulation_id', '')::uuid;
  v_items jsonb := coalesce(p_quote -> 'items', '[]'::jsonb);
  v_item jsonb;
  v_existing public.quotes%rowtype;
  v_subtotal numeric(12, 2) := 0;
  v_items_discount numeric(12, 2) := 0;
  v_gross numeric(12, 2);
  v_qty numeric;
  v_price numeric;
  v_disc numeric;
  v_net numeric(12, 2);
  v_discount_type text := coalesce(nullif(p_quote ->> 'discount_type', ''), 'valor');
  v_discount_value numeric(12, 2) := coalesce(nullif(p_quote ->> 'discount_value', '')::numeric, 0);
  v_quote_discount numeric(12, 2);
  v_discount_total numeric(12, 2);
  v_pct numeric;
  v_max numeric;
  v_validity int;
  v_valid_until date := nullif(p_quote ->> 'valid_until', '')::date;
  v_authorized_by uuid;
  v_authorized_pct numeric(8, 4);
  v_vehicle_desc text := left(trim(coalesce(p_quote ->> 'vehicle_description', '')), 160);
  v_pos int := 0;
begin
  if not public.has_permission('orcamentos.gerenciar') then
    raise exception 'Você não tem permissão para criar ou editar orçamentos.' using errcode = '42501';
  end if;

  if v_customer is null or not exists (select 1 from public.customers c where c.id = v_customer) then
    raise exception 'Selecione um cliente válido.' using errcode = '22023';
  end if;
  if v_vehicle is not null then
    select concat_ws(' ', v.brand, v.model, nullif(v.generation, ''))
      into v_vehicle_desc
      from public.vehicles v where v.id = v_vehicle;
    if not found then
      raise exception 'Veículo não encontrado.' using errcode = '22023';
    end if;
  end if;
  if v_simulation is not null and not exists (select 1 from public.simulations s where s.id = v_simulation) then
    raise exception 'Simulação não encontrada.' using errcode = '22023';
  end if;

  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 then
    raise exception 'Adicione pelo menos um item ao orçamento.' using errcode = '22023';
  end if;
  if jsonb_array_length(v_items) > 100 then
    raise exception 'Um orçamento pode ter no máximo 100 itens.' using errcode = '22023';
  end if;
  if v_discount_type not in ('valor', 'percentual') then
    raise exception 'Tipo de desconto inválido.' using errcode = '22023';
  end if;
  if v_discount_value < 0 or (v_discount_type = 'percentual' and v_discount_value > 100) then
    raise exception 'Valor de desconto inválido.' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(v_items) loop
    if coalesce(v_item ->> 'kind', '') not in ('pelicula', 'servico', 'outro') then
      raise exception 'Tipo de item inválido.' using errcode = '22023';
    end if;
    if char_length(trim(coalesce(v_item ->> 'description', ''))) = 0 then
      raise exception 'Informe a descrição de todos os itens.' using errcode = '22023';
    end if;
    v_qty := nullif(v_item ->> 'quantity', '')::numeric;
    v_price := nullif(v_item ->> 'unit_price', '')::numeric;
    v_disc := coalesce(nullif(v_item ->> 'discount', '')::numeric, 0);
    if v_qty is null or v_qty <= 0 then
      raise exception 'A quantidade de cada item deve ser maior que zero.' using errcode = '22023';
    end if;
    if v_price is null or v_price < 0 then
      raise exception 'O valor unitário dos itens não pode ser negativo.' using errcode = '22023';
    end if;
    v_gross := round(v_qty * v_price, 2);
    if v_disc < 0 or v_disc > v_gross then
      raise exception 'O desconto de um item não pode ser negativo nem maior que o valor do item.' using errcode = '22023';
    end if;
    v_subtotal := v_subtotal + v_gross;
    v_items_discount := v_items_discount + round(v_disc, 2);
  end loop;

  v_net := v_subtotal - v_items_discount;
  if v_discount_type = 'percentual' then
    v_quote_discount := round(v_net * v_discount_value / 100, 2);
  else
    v_quote_discount := v_discount_value;
  end if;
  if v_quote_discount > v_net then
    raise exception 'O desconto não pode ser maior que o valor do orçamento.' using errcode = '22023';
  end if;
  v_discount_total := v_items_discount + v_quote_discount;

  select s.max_discount_percent, s.quote_validity_days into v_max, v_validity
  from public.settings s where s.id = 1;

  if v_id is not null then
    select * into v_existing from public.quotes q where q.id = v_id for update;
    if not found then
      raise exception 'Orçamento não encontrado.' using errcode = '22023';
    end if;
    if v_existing.status in ('aprovado', 'concluido') then
      raise exception 'Orçamentos aprovados ou concluídos não podem ser editados. Volte o status para rascunho antes de alterar.'
        using errcode = 'P0001';
    end if;
    v_authorized_by := v_existing.discount_authorized_by;
    v_authorized_pct := v_existing.discount_authorized_percent;
  end if;

  v_pct := case when v_subtotal > 0 then round(v_discount_total / v_subtotal * 100, 4) else 0 end;
  if v_pct > v_max then
    if public.has_permission('orcamentos.desconto_livre') then
      v_authorized_by := auth.uid();
      v_authorized_pct := v_pct;
    elsif v_authorized_pct is null or v_pct > v_authorized_pct + 0.0001 then
      raise exception 'Desconto de % acima do limite autorizado de %. Solicite a autorização de um gerente.',
        public.format_brl_percent(v_pct), public.format_brl_percent(v_max)
        using errcode = 'P0001';
    end if;
  else
    v_authorized_by := null;
    v_authorized_pct := null;
  end if;

  if v_id is null then
    insert into public.quotes (
      customer_id, vehicle_id, vehicle_description, vehicle_plate, vehicle_year, vehicle_color, simulation_id,
      valid_until, discount_type, discount_value, subtotal, items_discount, discount_total, total,
      discount_authorized_by, discount_authorized_percent, notes, internal_notes, created_by
    ) values (
      v_customer, v_vehicle, coalesce(v_vehicle_desc, ''), public.normalize_plate(p_quote ->> 'vehicle_plate'),
      nullif(p_quote ->> 'vehicle_year', '')::smallint, left(trim(coalesce(p_quote ->> 'vehicle_color', '')), 40), v_simulation,
      coalesce(v_valid_until, (now() at time zone 'America/Sao_Paulo')::date + v_validity),
      v_discount_type, v_discount_value, v_subtotal, v_items_discount, v_discount_total, v_subtotal - v_discount_total,
      v_authorized_by, v_authorized_pct, coalesce(p_quote ->> 'notes', ''), coalesce(p_quote ->> 'internal_notes', ''), auth.uid()
    )
    returning id into v_id;

    insert into public.quote_events (quote_id, event, status) values (v_id, 'criado', 'rascunho');
  else
    update public.quotes set
      customer_id = v_customer,
      vehicle_id = v_vehicle,
      vehicle_description = coalesce(v_vehicle_desc, ''),
      vehicle_plate = public.normalize_plate(p_quote ->> 'vehicle_plate'),
      vehicle_year = nullif(p_quote ->> 'vehicle_year', '')::smallint,
      vehicle_color = left(trim(coalesce(p_quote ->> 'vehicle_color', '')), 40),
      simulation_id = v_simulation,
      valid_until = coalesce(v_valid_until, valid_until),
      discount_type = v_discount_type,
      discount_value = v_discount_value,
      subtotal = v_subtotal,
      items_discount = v_items_discount,
      discount_total = v_discount_total,
      total = v_subtotal - v_discount_total,
      discount_authorized_by = v_authorized_by,
      discount_authorized_percent = v_authorized_pct,
      notes = coalesce(p_quote ->> 'notes', ''),
      internal_notes = coalesce(p_quote ->> 'internal_notes', '')
    where id = v_id;

    insert into public.quote_events (quote_id, event, status) values (v_id, 'atualizado', v_existing.status);
  end if;

  delete from public.quote_items where quote_id = v_id;

  for v_item in select * from jsonb_array_elements(v_items) loop
    v_qty := (v_item ->> 'quantity')::numeric;
    v_price := (v_item ->> 'unit_price')::numeric;
    v_disc := round(coalesce(nullif(v_item ->> 'discount', '')::numeric, 0), 2);
    insert into public.quote_items (
      quote_id, position, kind, film_id, service_type_id, glass_zones, description, quantity, unit_price, discount, total
    ) values (
      v_id,
      v_pos,
      (v_item ->> 'kind')::public.quote_item_kind,
      case when v_item ->> 'kind' = 'pelicula' then nullif(v_item ->> 'film_id', '')::uuid end,
      case when v_item ->> 'kind' = 'servico' then nullif(v_item ->> 'service_type_id', '')::uuid end,
      coalesce(
        (select array_agg(z::public.glass_zone)
           from jsonb_array_elements_text(case when jsonb_typeof(v_item -> 'glass_zones') = 'array' then v_item -> 'glass_zones' else '[]'::jsonb end) z),
        '{}'
      ),
      left(trim(v_item ->> 'description'), 300),
      v_qty,
      v_price,
      v_disc,
      round(v_qty * v_price, 2) - v_disc
    );
    v_pos := v_pos + 1;
  end loop;

  return v_id;
end;
$$;

-- Altera o status respeitando o fluxo do orçamento e registra na linha do tempo.
create or replace function public.set_quote_status(p_id uuid, p_status public.quote_status, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.quote_status;
  v_allowed boolean;
begin
  if not public.has_permission('orcamentos.gerenciar') then
    raise exception 'Você não tem permissão para alterar orçamentos.' using errcode = '42501';
  end if;

  select q.status into v_old from public.quotes q where q.id = p_id for update;
  if not found then
    raise exception 'Orçamento não encontrado.' using errcode = '22023';
  end if;
  if v_old = p_status then
    return;
  end if;

  v_allowed := case v_old
    when 'rascunho' then p_status in ('enviado', 'aprovado', 'recusado')
    when 'enviado' then p_status in ('rascunho', 'aprovado', 'recusado')
    when 'aprovado' then p_status in ('rascunho', 'enviado', 'concluido')
    when 'recusado' then p_status in ('rascunho', 'enviado')
    when 'concluido' then p_status in ('aprovado')
  end;
  if not v_allowed then
    raise exception 'Não é possível alterar o status de "%" para "%".',
      public.quote_status_label(v_old), public.quote_status_label(p_status)
      using errcode = 'P0001';
  end if;

  update public.quotes set
    status = p_status,
    sent_at = case when p_status = 'enviado' then now() else sent_at end,
    decided_at = case
      when p_status in ('aprovado', 'recusado') then now()
      when p_status in ('rascunho', 'enviado') then null
      else decided_at end,
    completed_at = case when p_status = 'concluido' then now() else null end
  where id = p_id;

  insert into public.quote_events (quote_id, event, status, note)
  values (p_id, 'status', p_status, nullif(left(trim(coalesce(p_note, '')), 500), ''));
end;
$$;

-- ---------------------------------------------------------------------
-- Ordens de serviço
-- ---------------------------------------------------------------------

create table public.service_orders (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity unique,
  quote_id uuid references public.quotes (id) on delete set null,
  customer_id uuid not null references public.customers (id) on delete restrict,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  vehicle_description text not null default '' check (char_length(vehicle_description) <= 160),
  vehicle_plate text check (vehicle_plate is null or vehicle_plate ~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$'),
  service_type_id uuid references public.service_types (id) on delete set null,
  description text not null check (char_length(trim(description)) between 2 and 500),
  status public.service_order_status not null default 'agendado',
  scheduled_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  assigned_to uuid references public.profiles (id) on delete set null,
  price numeric(12, 2) check (price >= 0),
  notes text not null default '' check (char_length(notes) <= 2000),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index service_orders_status_idx on public.service_orders (status, scheduled_at);
create index service_orders_customer_idx on public.service_orders (customer_id);

create or replace function public.service_orders_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.vehicle_plate := public.normalize_plate(new.vehicle_plate);
  if new.vehicle_id is not null and (tg_op = 'INSERT' or new.vehicle_id is distinct from old.vehicle_id) then
    select concat_ws(' ', v.brand, v.model, nullif(v.generation, ''))
      into new.vehicle_description
      from public.vehicles v where v.id = new.vehicle_id;
  end if;
  new.vehicle_description := coalesce(new.vehicle_description, '');
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    if new.status = 'em_andamento' and new.started_at is null then
      new.started_at := now();
    end if;
    if new.status = 'concluido' then
      new.completed_at := coalesce(new.completed_at, now());
      new.started_at := coalesce(new.started_at, new.completed_at);
    elsif new.status <> 'concluido' then
      new.completed_at := null;
    end if;
  end if;
  return new;
end;
$$;

create trigger service_orders_before_write before insert or update on public.service_orders
  for each row execute function public.service_orders_before_write();
create trigger service_orders_set_updated_at before update on public.service_orders
  for each row execute function public.set_updated_at();
create trigger service_orders_set_created_by before insert on public.service_orders
  for each row execute function public.set_created_by();

-- ---------------------------------------------------------------------
-- Indicadores do painel (respeita RLS: executa com os privilégios do usuário)
-- ---------------------------------------------------------------------

create or replace function public.dashboard_stats()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with bounds as (
    select
      (date_trunc('month', now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo') as month_start,
      now() - interval '7 days' as week_start
  )
  select jsonb_build_object(
    'customers_total', (select count(*) from public.customers),
    'customers_month', (select count(*) from public.customers c, bounds b where c.created_at >= b.month_start),
    'quotes_pending', (select count(*) from public.quotes q where q.status in ('rascunho', 'enviado')),
    'quotes_pending_value', (select coalesce(sum(q.total), 0) from public.quotes q where q.status in ('rascunho', 'enviado')),
    'quotes_approved_month', (select count(*) from public.quotes q, bounds b where q.status in ('aprovado', 'concluido') and q.decided_at >= b.month_start),
    'quotes_approved_month_value', (select coalesce(sum(q.total), 0) from public.quotes q, bounds b where q.status in ('aprovado', 'concluido') and q.decided_at >= b.month_start),
    'service_orders_total', (select count(*) from public.service_orders),
    'service_orders_open', (select count(*) from public.service_orders s where s.status in ('agendado', 'em_andamento')),
    'service_orders_done_month', (select count(*) from public.service_orders s, bounds b where s.status = 'concluido' and s.completed_at >= b.month_start),
    'simulations_total', (select count(*) from public.simulations),
    'simulations_week', (select count(*) from public.simulations s, bounds b where s.created_at >= b.week_start),
    'vehicles_total', (select count(*) from public.vehicles v where v.active),
    'films_total', (select count(*) from public.films f where f.active)
  );
$$;
