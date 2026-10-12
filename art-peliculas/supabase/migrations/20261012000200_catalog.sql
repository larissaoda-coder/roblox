-- =====================================================================
-- Art Películas — garagem de veículos, películas e tipos de serviço
-- =====================================================================

create type public.vehicle_category as enum ('hatch', 'sedan', 'suv', 'picape', 'minivan', 'cupe', 'utilitario');
create type public.glass_zone as enum ('para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro');
create type public.film_price_unit as enum ('veiculo', 'vidro', 'm2');
create type public.film_finish as enum ('neutra', 'refletiva');

-- Máscaras de vidros: { "<zona>": [ [[x,y], [x,y], ...], ... ] } com coordenadas normalizadas (0 a 1).
create or replace function public.is_valid_glass_masks(m jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  k text;
  v jsonb;
  poly jsonb;
  pt jsonb;
begin
  if m is null or jsonb_typeof(m) <> 'object' then
    return false;
  end if;
  for k, v in select * from jsonb_each(m) loop
    if k not in ('para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro') then
      return false;
    end if;
    if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 12 then
      return false;
    end if;
    for poly in select * from jsonb_array_elements(v) loop
      if jsonb_typeof(poly) <> 'array' or jsonb_array_length(poly) < 3 or jsonb_array_length(poly) > 300 then
        return false;
      end if;
      for pt in select * from jsonb_array_elements(poly) loop
        if jsonb_typeof(pt) <> 'array' or jsonb_array_length(pt) <> 2
           or jsonb_typeof(pt -> 0) <> 'number' or jsonb_typeof(pt -> 1) <> 'number' then
          return false;
        end if;
        if (pt ->> 0)::numeric < 0 or (pt ->> 0)::numeric > 1
           or (pt ->> 1)::numeric < 0 or (pt ->> 1)::numeric > 1 then
          return false;
        end if;
      end loop;
    end loop;
  end loop;
  return true;
end;
$$;

-- Mapa de malhas do modelo 3D: { "<chave da malha>": "<zona>" }.
create or replace function public.is_valid_glass_map(m jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  k text;
  v jsonb;
  n int := 0;
begin
  if m is null or jsonb_typeof(m) <> 'object' then
    return false;
  end if;
  for k, v in select * from jsonb_each(m) loop
    n := n + 1;
    if n > 1000 or char_length(k) > 300 then
      return false;
    end if;
    if jsonb_typeof(v) <> 'string' or (v #>> '{}') not in ('para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro') then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- Veículos
-- ---------------------------------------------------------------------

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  brand text not null check (char_length(trim(brand)) between 1 and 60),
  model text not null check (char_length(trim(model)) between 1 and 80),
  generation text not null default '' check (char_length(generation) <= 80),
  year_start smallint check (year_start between 1950 and 2100),
  year_end smallint check (year_end between 1950 and 2100),
  category public.vehicle_category not null,
  doors smallint check (doors between 2 and 5),
  notes text not null default '' check (char_length(notes) <= 2000),
  model_3d_path text,
  model_3d_credit text check (model_3d_credit is null or char_length(model_3d_credit) <= 300),
  model_3d_glass_map jsonb not null default '{}'::jsonb check (public.is_valid_glass_map(model_3d_glass_map)),
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_years_order check (year_end is null or year_start is null or year_end >= year_start),
  -- Todo modelo 3D precisa ter origem/licença informada.
  constraint vehicles_model_credit check (model_3d_path is null or char_length(trim(coalesce(model_3d_credit, ''))) >= 3)
);

create unique index vehicles_identity_key on public.vehicles (lower(brand), lower(model), lower(generation));
create index vehicles_category_idx on public.vehicles (category);

create trigger vehicles_set_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();
create trigger vehicles_set_created_by before insert on public.vehicles
  for each row execute function public.set_created_by();

create table public.vehicle_images (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  storage_path text not null unique check (storage_path ~ '^vehicles/'),
  view text not null default 'frente_34' check (view in ('frente_34', 'traseira_34', 'lateral', 'frontal', 'traseira')),
  -- Origem e autorização de uso da imagem (obrigatório).
  source_credit text not null check (char_length(trim(source_credit)) between 3 and 300),
  glass_masks jsonb not null default '{}'::jsonb check (public.is_valid_glass_masks(glass_masks)),
  width int check (width > 0),
  height int check (height > 0),
  is_primary boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index vehicle_images_vehicle_idx on public.vehicle_images (vehicle_id);
create unique index vehicle_images_one_primary on public.vehicle_images (vehicle_id) where is_primary;

create trigger vehicle_images_set_updated_at before update on public.vehicle_images
  for each row execute function public.set_updated_at();
create trigger vehicle_images_set_created_by before insert on public.vehicle_images
  for each row execute function public.set_created_by();

-- ---------------------------------------------------------------------
-- Películas
-- ---------------------------------------------------------------------

create table public.films (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 100),
  manufacturer text not null check (char_length(trim(manufacturer)) between 1 and 80),
  product_line text not null default '' check (char_length(product_line) <= 80),
  -- Transmissão luminosa (VLT) informada pelo fabricante, em %.
  vlt_percent numeric(5, 2) not null check (vlt_percent between 0 and 100),
  finish public.film_finish not null default 'neutra',
  description text not null default '' check (char_length(description) <= 2000),
  uv_rejection_percent numeric(5, 2) check (uv_rejection_percent between 0 and 100),
  ir_rejection_percent numeric(5, 2) check (ir_rejection_percent between 0 and 100),
  tser_percent numeric(5, 2) check (tser_percent between 0 and 100),
  warranty_years smallint check (warranty_years between 0 and 50),
  -- Características adicionais informadas pelo administrador: [{ "label": "...", "value": "..." }]
  technical_specs jsonb not null default '[]'::jsonb check (jsonb_typeof(technical_specs) = 'array' and jsonb_array_length(technical_specs) <= 30),
  price numeric(12, 2) not null check (price >= 0),
  price_unit public.film_price_unit not null default 'veiculo',
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index films_identity_key on public.films (lower(manufacturer), lower(name), lower(product_line));

create trigger films_set_updated_at before update on public.films
  for each row execute function public.set_updated_at();
create trigger films_set_created_by before insert on public.films
  for each row execute function public.set_created_by();

-- Películas indicadas para cada veículo, com preço específico opcional.
create table public.vehicle_films (
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  film_id uuid not null references public.films (id) on delete cascade,
  price_override numeric(12, 2) check (price_override >= 0),
  notes text not null default '' check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  primary key (vehicle_id, film_id)
);

create index vehicle_films_film_idx on public.vehicle_films (film_id);

-- ---------------------------------------------------------------------
-- Tipos de serviço
-- ---------------------------------------------------------------------

create table public.service_types (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 100),
  description text not null default '' check (char_length(description) <= 1000),
  base_price numeric(12, 2) not null default 0 check (base_price >= 0),
  estimated_minutes int check (estimated_minutes between 1 and 10080),
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index service_types_name_key on public.service_types (lower(name));

create trigger service_types_set_updated_at before update on public.service_types
  for each row execute function public.set_updated_at();
create trigger service_types_set_created_by before insert on public.service_types
  for each row execute function public.set_created_by();
