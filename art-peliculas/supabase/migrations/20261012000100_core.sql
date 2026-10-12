-- =====================================================================
-- Art Películas — núcleo: perfis, papéis, permissões e configurações
-- =====================================================================

create type public.app_role as enum ('admin', 'gerente', 'vendedor', 'instalador');

-- ---------------------------------------------------------------------
-- Funções utilitárias
-- ---------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Garante que created_by seja sempre o usuário autenticado (não pode ser forjado pelo cliente).
create or replace function public.set_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

-- Normaliza CPF/CNPJ: somente dígitos e letras maiúsculas (CNPJ alfanumérico).
create or replace function public.normalize_document(doc text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(upper(coalesce(doc, '')), '[^0-9A-Z]', '', 'g'), '');
$$;

-- Valida CPF (11 dígitos) ou CNPJ (14 caracteres, numérico ou alfanumérico — IN RFB nº 2.229/2024).
create or replace function public.is_valid_cpf_cnpj(doc text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  d text := public.normalize_document(doc);
  s int;
  r int;
  i int;
  w int[];
begin
  if d is null then
    return false;
  end if;

  if length(d) = 11 then
    if d !~ '^[0-9]{11}$' or d ~ '^(.)\1{10}$' then
      return false;
    end if;
    s := 0;
    for i in 1..9 loop
      s := s + substr(d, i, 1)::int * (11 - i);
    end loop;
    r := (s * 10) % 11;
    if r = 10 then r := 0; end if;
    if r <> substr(d, 10, 1)::int then
      return false;
    end if;
    s := 0;
    for i in 1..10 loop
      s := s + substr(d, i, 1)::int * (12 - i);
    end loop;
    r := (s * 10) % 11;
    if r = 10 then r := 0; end if;
    return r = substr(d, 11, 1)::int;
  end if;

  if length(d) = 14 then
    if d !~ '^[0-9A-Z]{12}[0-9]{2}$' or d ~ '^(.)\1{13}$' then
      return false;
    end if;
    w := array[5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    s := 0;
    for i in 1..12 loop
      s := s + (ascii(substr(d, i, 1)) - 48) * w[i];
    end loop;
    r := s % 11;
    r := case when r < 2 then 0 else 11 - r end;
    if r <> substr(d, 13, 1)::int then
      return false;
    end if;
    w := array[6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    s := 0;
    for i in 1..13 loop
      s := s + (ascii(substr(d, i, 1)) - 48) * w[i];
    end loop;
    r := s % 11;
    r := case when r < 2 then 0 else 11 - r end;
    return r = substr(d, 14, 1)::int;
  end if;

  return false;
end;
$$;

-- ---------------------------------------------------------------------
-- Perfis
-- ---------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '' check (char_length(full_name) <= 120),
  email text not null default '',
  phone text check (phone is null or phone ~ '^[0-9]{10,13}$'),
  role public.app_role not null default 'vendedor',
  -- Novas contas nascem inativas: somente um administrador libera o acesso.
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Dados de perfil e papel de acesso de cada usuário do sistema.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Permissões
-- ---------------------------------------------------------------------

create table public.permissions (
  code text primary key,
  label text not null,
  description text not null default '',
  group_label text not null,
  sort_order int not null default 0
);

create table public.role_permissions (
  role public.app_role not null,
  permission text not null references public.permissions (code) on delete cascade,
  primary key (role, permission)
);

insert into public.permissions (code, label, description, group_label, sort_order) values
  ('veiculos.gerenciar', 'Gerenciar garagem', 'Cadastrar, editar e excluir veículos, imagens, máscaras de vidros e modelos 3D.', 'Garagem de veículos', 10),
  ('peliculas.gerenciar', 'Gerenciar catálogo de películas', 'Cadastrar, editar e excluir películas e associá-las aos veículos.', 'Catálogo de películas', 20),
  ('clientes.gerenciar', 'Cadastrar e editar clientes', 'Criar e atualizar o cadastro de clientes.', 'Clientes', 30),
  ('clientes.excluir', 'Excluir clientes', 'Remover clientes sem orçamentos vinculados.', 'Clientes', 31),
  ('orcamentos.gerenciar', 'Criar e editar orçamentos', 'Gerar orçamentos, alterar itens e acompanhar o status.', 'Orçamentos', 40),
  ('orcamentos.desconto_livre', 'Autorizar descontos acima do limite', 'Aplicar descontos maiores que o limite definido nas configurações.', 'Orçamentos', 41),
  ('orcamentos.excluir', 'Excluir orçamentos', 'Remover orçamentos definitivamente.', 'Orçamentos', 42),
  ('servicos.gerenciar', 'Gerenciar serviços', 'Cadastrar tipos de serviço e registrar ordens de serviço.', 'Serviços', 50),
  ('historico.ver', 'Consultar histórico', 'Visualizar o histórico de alterações do sistema.', 'Histórico', 60),
  ('configuracoes.gerenciar', 'Alterar configurações', 'Editar dados da empresa, limites de desconto e parâmetros do simulador.', 'Configurações', 70),
  ('usuarios.gerenciar', 'Gerenciar usuários e permissões', 'Convidar usuários, alterar papéis, ativar/desativar contas e editar permissões.', 'Usuários e permissões', 80);

insert into public.role_permissions (role, permission)
select 'gerente', code from public.permissions where code <> 'usuarios.gerenciar';

insert into public.role_permissions (role, permission) values
  ('vendedor', 'clientes.gerenciar'),
  ('vendedor', 'orcamentos.gerenciar'),
  ('vendedor', 'servicos.gerenciar'),
  ('instalador', 'servicos.gerenciar');

-- ---------------------------------------------------------------------
-- Funções de autorização (usadas pelas políticas RLS)
-- ---------------------------------------------------------------------

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.active
  );
$$;

create or replace function public.has_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.active
      and (
        p.role = 'admin'
        or exists (
          select 1 from public.role_permissions rp
          where rp.role = p.role and rp.permission = p_permission
        )
      )
  );
$$;

create or replace function public.my_permissions()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(p.code order by p.code), '{}')
  from public.permissions p
  where public.has_permission(p.code);
$$;

-- Conexões privilegiadas (SQL editor, service_role) podem administrar perfis sem um usuário logado.
create or replace function public.is_privileged_connection()
returns boolean
language sql
stable
set search_path = ''
as $$
  select current_user in ('postgres', 'supabase_admin', 'service_role')
      or coalesce(auth.role(), '') = 'service_role';
$$;

-- Protege alterações de papel/ativação e impede que o sistema fique sem administrador.
-- Executa com os privilégios de quem altera (security invoker), para que current_user
-- identifique corretamente conexões privilegiadas.
create or replace function public.guard_profile_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id or new.email is distinct from old.email then
    if not public.is_privileged_connection() then
      raise exception 'O e-mail do perfil é sincronizado com a conta de acesso e não pode ser alterado aqui.'
        using errcode = '42501';
    end if;
  end if;

  if new.role is distinct from old.role or new.active is distinct from old.active then
    if not public.is_privileged_connection() then
      if not public.has_permission('usuarios.gerenciar') then
        raise exception 'Você não tem permissão para alterar o papel ou o status de usuários.'
          using errcode = '42501';
      end if;
      if new.id = auth.uid() then
        raise exception 'Você não pode alterar o seu próprio papel ou desativar a sua própria conta.'
          using errcode = 'P0001';
      end if;
    end if;

    if old.role = 'admin' and old.active and (new.role <> 'admin' or not new.active) then
      if not exists (
        select 1 from public.profiles p
        where p.role = 'admin' and p.active and p.id <> old.id
      ) then
        raise exception 'É necessário manter pelo menos um administrador ativo.'
          using errcode = 'P0001';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_guard_changes
  before update on public.profiles
  for each row execute function public.guard_profile_changes();

-- Cria o perfil automaticamente para cada nova conta de acesso.
-- Papel e status NÃO são lidos dos metadados enviados pelo usuário.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(coalesce(new.email, ''), '@', 1)), 120)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = coalesce(new.email, '') where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- Lista usuários com dados da conta de acesso (somente para quem gerencia usuários).
create or replace function public.list_users()
returns table (
  id uuid,
  full_name text,
  email text,
  phone text,
  role public.app_role,
  active boolean,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed_at timestamptz,
  invited_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('usuarios.gerenciar') then
    raise exception 'Você não tem permissão para gerenciar usuários.' using errcode = '42501';
  end if;

  return query
  select p.id, p.full_name, p.email, p.phone, p.role, p.active, p.created_at,
         u.last_sign_in_at, u.email_confirmed_at, u.invited_at
  from public.profiles p
  join auth.users u on u.id = p.id
  order by p.active desc, p.full_name;
end;
$$;

-- ---------------------------------------------------------------------
-- Configurações gerais (linha única)
-- ---------------------------------------------------------------------

create table public.settings (
  id smallint primary key default 1 check (id = 1),
  company_name text not null default 'Art Películas' check (char_length(trim(company_name)) between 2 and 120),
  legal_name text not null default '' check (char_length(legal_name) <= 160),
  document text check (document is null or public.is_valid_cpf_cnpj(document)),
  phone text not null default '' check (char_length(phone) <= 30),
  email text not null default '' check (email = '' or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  address text not null default '' check (char_length(address) <= 300),
  website text not null default '' check (char_length(website) <= 160),
  logo_path text,
  quote_validity_days int not null default 15 check (quote_validity_days between 1 and 365),
  max_discount_percent numeric(5, 2) not null default 10 check (max_discount_percent between 0 and 100),
  quote_terms text not null default '' check (char_length(quote_terms) <= 4000),
  -- Referências de transmissão luminosa mínima (%) exibidas no simulador.
  legal_vlt_windshield numeric(5, 2) not null default 75 check (legal_vlt_windshield between 0 and 100),
  legal_vlt_front numeric(5, 2) not null default 70 check (legal_vlt_front between 0 and 100),
  legal_vlt_rear numeric(5, 2) not null default 28 check (legal_vlt_rear between 0 and 100),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

insert into public.settings (id) values (1);

create or replace function public.settings_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.id := 1;
  new.document := public.normalize_document(new.document);
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

create trigger settings_before_update
  before update on public.settings
  for each row execute function public.settings_before_update();
