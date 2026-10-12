-- =====================================================================
-- Art Películas — políticas de segurança (RLS) e privilégios
-- =====================================================================
-- Regras gerais:
--   * Visitantes anônimos não acessam nenhuma tabela.
--   * Somente usuários com perfil ATIVO leem dados do sistema.
--   * Escritas exigem a permissão correspondente (public.has_permission).
--   * Orçamentos e itens só são gravados pelas funções save_quote / set_quote_status.

-- ---------------------------------------------------------------------
-- Privilégios
-- ---------------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from anon, public;
-- Usuários autenticados precisam executar as funções usadas em validações, gatilhos e políticas.
-- As funções que alteram dados verificam permissões internamente.
grant execute on all functions in schema public to authenticated, service_role;

-- Orçamentos: leitura direta; escrita somente via funções.
revoke insert, update on public.quotes from authenticated;
revoke insert, update, delete on public.quote_items from authenticated;
revoke insert, update, delete on public.quote_events from authenticated;
revoke insert, update, delete on public.audit_log from authenticated;
revoke insert, delete on public.settings from authenticated;
revoke insert, delete on public.profiles from authenticated;
revoke insert, update, delete on public.permissions from authenticated;
revoke update on public.role_permissions from authenticated;

-- Perfis: apenas estas colunas podem ser alteradas pelo cliente.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, role, active) on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- Habilita RLS em todas as tabelas
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.settings enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_images enable row level security;
alter table public.films enable row level security;
alter table public.vehicle_films enable row level security;
alter table public.service_types enable row level security;
alter table public.customers enable row level security;
alter table public.simulations enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.quote_events enable row level security;
alter table public.service_orders enable row level security;
alter table public.audit_log enable row level security;

-- ---------------------------------------------------------------------
-- Perfis, permissões e configurações
-- ---------------------------------------------------------------------

create policy "profiles: leitura" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select public.is_active_user()));

create policy "profiles: edição do próprio perfil ou por gestores" on public.profiles
  for update to authenticated
  using (
    (id = (select auth.uid()) and (select public.is_active_user()))
    or (select public.has_permission('usuarios.gerenciar'))
  )
  with check (
    (id = (select auth.uid()) and (select public.is_active_user()))
    or (select public.has_permission('usuarios.gerenciar'))
  );

create policy "permissions: leitura" on public.permissions
  for select to authenticated
  using (true);

create policy "role_permissions: leitura" on public.role_permissions
  for select to authenticated
  using ((select public.is_active_user()));

create policy "role_permissions: inclusão" on public.role_permissions
  for insert to authenticated
  with check ((select public.has_permission('usuarios.gerenciar')) and role <> 'admin');

create policy "role_permissions: remoção" on public.role_permissions
  for delete to authenticated
  using ((select public.has_permission('usuarios.gerenciar')) and role <> 'admin');

create policy "settings: leitura" on public.settings
  for select to authenticated
  using ((select public.is_active_user()));

create policy "settings: edição" on public.settings
  for update to authenticated
  using ((select public.has_permission('configuracoes.gerenciar')))
  with check ((select public.has_permission('configuracoes.gerenciar')));

-- ---------------------------------------------------------------------
-- Catálogos (veículos, películas, serviços)
-- ---------------------------------------------------------------------

create policy "vehicles: leitura" on public.vehicles
  for select to authenticated using ((select public.is_active_user()));
create policy "vehicles: inclusão" on public.vehicles
  for insert to authenticated with check ((select public.has_permission('veiculos.gerenciar')));
create policy "vehicles: edição" on public.vehicles
  for update to authenticated
  using ((select public.has_permission('veiculos.gerenciar')))
  with check ((select public.has_permission('veiculos.gerenciar')));
create policy "vehicles: exclusão" on public.vehicles
  for delete to authenticated using ((select public.has_permission('veiculos.gerenciar')));

create policy "vehicle_images: leitura" on public.vehicle_images
  for select to authenticated using ((select public.is_active_user()));
create policy "vehicle_images: inclusão" on public.vehicle_images
  for insert to authenticated with check ((select public.has_permission('veiculos.gerenciar')));
create policy "vehicle_images: edição" on public.vehicle_images
  for update to authenticated
  using ((select public.has_permission('veiculos.gerenciar')))
  with check ((select public.has_permission('veiculos.gerenciar')));
create policy "vehicle_images: exclusão" on public.vehicle_images
  for delete to authenticated using ((select public.has_permission('veiculos.gerenciar')));

create policy "films: leitura" on public.films
  for select to authenticated using ((select public.is_active_user()));
create policy "films: inclusão" on public.films
  for insert to authenticated with check ((select public.has_permission('peliculas.gerenciar')));
create policy "films: edição" on public.films
  for update to authenticated
  using ((select public.has_permission('peliculas.gerenciar')))
  with check ((select public.has_permission('peliculas.gerenciar')));
create policy "films: exclusão" on public.films
  for delete to authenticated using ((select public.has_permission('peliculas.gerenciar')));

create policy "vehicle_films: leitura" on public.vehicle_films
  for select to authenticated using ((select public.is_active_user()));
create policy "vehicle_films: inclusão" on public.vehicle_films
  for insert to authenticated
  with check ((select public.has_permission('veiculos.gerenciar')) or (select public.has_permission('peliculas.gerenciar')));
create policy "vehicle_films: edição" on public.vehicle_films
  for update to authenticated
  using ((select public.has_permission('veiculos.gerenciar')) or (select public.has_permission('peliculas.gerenciar')))
  with check ((select public.has_permission('veiculos.gerenciar')) or (select public.has_permission('peliculas.gerenciar')));
create policy "vehicle_films: exclusão" on public.vehicle_films
  for delete to authenticated
  using ((select public.has_permission('veiculos.gerenciar')) or (select public.has_permission('peliculas.gerenciar')));

create policy "service_types: leitura" on public.service_types
  for select to authenticated using ((select public.is_active_user()));
create policy "service_types: inclusão" on public.service_types
  for insert to authenticated with check ((select public.has_permission('servicos.gerenciar')));
create policy "service_types: edição" on public.service_types
  for update to authenticated
  using ((select public.has_permission('servicos.gerenciar')))
  with check ((select public.has_permission('servicos.gerenciar')));
create policy "service_types: exclusão" on public.service_types
  for delete to authenticated using ((select public.has_permission('servicos.gerenciar')));

-- ---------------------------------------------------------------------
-- Clientes, simulações, orçamentos e ordens de serviço
-- ---------------------------------------------------------------------

create policy "customers: leitura" on public.customers
  for select to authenticated using ((select public.is_active_user()));
create policy "customers: inclusão" on public.customers
  for insert to authenticated with check ((select public.has_permission('clientes.gerenciar')));
create policy "customers: edição" on public.customers
  for update to authenticated
  using ((select public.has_permission('clientes.gerenciar')))
  with check ((select public.has_permission('clientes.gerenciar')));
create policy "customers: exclusão" on public.customers
  for delete to authenticated using ((select public.has_permission('clientes.excluir')));

create policy "simulations: leitura" on public.simulations
  for select to authenticated using ((select public.is_active_user()));
create policy "simulations: inclusão" on public.simulations
  for insert to authenticated with check ((select public.is_active_user()));
create policy "simulations: edição" on public.simulations
  for update to authenticated
  using ((select public.is_active_user()) and (created_by = (select auth.uid()) or (select public.has_permission('orcamentos.gerenciar'))))
  with check ((select public.is_active_user()) and (created_by = (select auth.uid()) or (select public.has_permission('orcamentos.gerenciar'))));
create policy "simulations: exclusão" on public.simulations
  for delete to authenticated
  using ((select public.is_active_user()) and (created_by = (select auth.uid()) or (select public.has_permission('orcamentos.gerenciar'))));

create policy "quotes: leitura" on public.quotes
  for select to authenticated using ((select public.is_active_user()));
create policy "quotes: exclusão" on public.quotes
  for delete to authenticated using ((select public.has_permission('orcamentos.excluir')));

create policy "quote_items: leitura" on public.quote_items
  for select to authenticated using ((select public.is_active_user()));

create policy "quote_events: leitura" on public.quote_events
  for select to authenticated using ((select public.is_active_user()));

create policy "service_orders: leitura" on public.service_orders
  for select to authenticated using ((select public.is_active_user()));
create policy "service_orders: inclusão" on public.service_orders
  for insert to authenticated with check ((select public.has_permission('servicos.gerenciar')));
create policy "service_orders: edição" on public.service_orders
  for update to authenticated
  using ((select public.has_permission('servicos.gerenciar')))
  with check ((select public.has_permission('servicos.gerenciar')));
create policy "service_orders: exclusão" on public.service_orders
  for delete to authenticated using ((select public.has_permission('servicos.gerenciar')));

create policy "audit_log: leitura" on public.audit_log
  for select to authenticated using ((select public.has_permission('historico.ver')));
