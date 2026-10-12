// Tipos de domínio espelhando as tabelas do banco (supabase/migrations).

export type AppRole = 'admin' | 'gerente' | 'vendedor' | 'instalador'
export type VehicleCategory = 'hatch' | 'sedan' | 'suv' | 'picape' | 'minivan' | 'cupe' | 'utilitario'
export type GlassZone = 'para_brisa' | 'dianteiros' | 'traseiros' | 'vidro_traseiro'
export type FilmPriceUnit = 'veiculo' | 'vidro' | 'm2'
export type FilmFinish = 'neutra' | 'refletiva'
export type SimulationMode = 'imagem' | 'modelo_3d' | 'referencia'
export type QuoteStatus = 'rascunho' | 'enviado' | 'aprovado' | 'recusado' | 'concluido'
export type QuoteItemKind = 'pelicula' | 'servico' | 'outro'
export type ServiceOrderStatus = 'agendado' | 'em_andamento' | 'concluido' | 'cancelado'
export type ImageView = 'frente_34' | 'traseira_34' | 'lateral' | 'frontal' | 'traseira'
export type DiscountType = 'valor' | 'percentual'

export type Permission =
  | 'veiculos.gerenciar'
  | 'peliculas.gerenciar'
  | 'clientes.gerenciar'
  | 'clientes.excluir'
  | 'orcamentos.gerenciar'
  | 'orcamentos.desconto_livre'
  | 'orcamentos.excluir'
  | 'servicos.gerenciar'
  | 'historico.ver'
  | 'configuracoes.gerenciar'
  | 'usuarios.gerenciar'

export interface Profile {
  id: string
  full_name: string
  email: string
  phone: string | null
  role: AppRole
  active: boolean
  created_at: string
  updated_at: string
}

export interface ManagedUser extends Pick<Profile, 'id' | 'full_name' | 'email' | 'phone' | 'role' | 'active' | 'created_at'> {
  last_sign_in_at: string | null
  email_confirmed_at: string | null
  invited_at: string | null
}

export interface PermissionDef {
  code: Permission
  label: string
  description: string
  group_label: string
  sort_order: number
}

export interface RolePermission {
  role: AppRole
  permission: Permission
}

export interface Settings {
  id: 1
  company_name: string
  legal_name: string
  document: string | null
  phone: string
  email: string
  address: string
  website: string
  logo_path: string | null
  quote_validity_days: number
  max_discount_percent: number
  quote_terms: string
  legal_vlt_windshield: number
  legal_vlt_front: number
  legal_vlt_rear: number
  updated_at: string
  updated_by: string | null
}

/** Polígono com pontos normalizados (0 a 1) sobre a imagem. */
export type Point = [number, number]
export type Polygon = Point[]
export type GlassMasks = Partial<Record<GlassZone, Polygon[]>>
/** Chave estável da malha no arquivo GLB → zona de vidro. */
export type GlassMap = Record<string, GlassZone>

export interface Vehicle {
  id: string
  brand: string
  model: string
  generation: string
  year_start: number | null
  year_end: number | null
  category: VehicleCategory
  doors: number | null
  notes: string
  model_3d_path: string | null
  model_3d_credit: string | null
  model_3d_glass_map: GlassMap
  active: boolean
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface VehicleImage {
  id: string
  vehicle_id: string
  storage_path: string
  view: ImageView
  source_credit: string
  glass_masks: GlassMasks
  width: number | null
  height: number | null
  is_primary: boolean
  created_at: string
  updated_at: string
}

export interface VehicleWithMedia extends Vehicle {
  vehicle_images: VehicleImage[]
}

export interface TechnicalSpec {
  label: string
  value: string
}

export interface Film {
  id: string
  name: string
  manufacturer: string
  product_line: string
  vlt_percent: number
  finish: FilmFinish
  description: string
  uv_rejection_percent: number | null
  ir_rejection_percent: number | null
  tser_percent: number | null
  warranty_years: number | null
  technical_specs: TechnicalSpec[]
  price: number
  price_unit: FilmPriceUnit
  active: boolean
  created_at: string
  updated_at: string
}

export interface VehicleFilm {
  vehicle_id: string
  film_id: string
  price_override: number | null
  notes: string
  created_at: string
}

export interface ServiceType {
  id: string
  name: string
  description: string
  base_price: number
  estimated_minutes: number | null
  active: boolean
  created_at: string
  updated_at: string
}

export interface Customer {
  id: string
  name: string
  document: string | null
  email: string | null
  phone: string | null
  zip_code: string | null
  street: string
  address_number: string
  complement: string
  district: string
  city: string
  state: string | null
  notes: string
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface ZoneTint {
  vlt: number
  film_id: string | null
}
export type SimulationConfig = Partial<Record<GlassZone, ZoneTint>>

export interface Simulation {
  id: string
  vehicle_id: string
  vehicle_image_id: string | null
  mode: SimulationMode
  config: SimulationConfig
  customer_id: string | null
  notes: string
  created_by: string | null
  created_at: string
}

export interface Quote {
  id: string
  number: number
  customer_id: string
  vehicle_id: string | null
  vehicle_description: string
  vehicle_plate: string | null
  vehicle_year: number | null
  vehicle_color: string
  simulation_id: string | null
  status: QuoteStatus
  valid_until: string | null
  discount_type: DiscountType
  discount_value: number
  subtotal: number
  items_discount: number
  discount_total: number
  total: number
  discount_authorized_by: string | null
  discount_authorized_percent: number | null
  notes: string
  internal_notes: string
  sent_at: string | null
  decided_at: string | null
  completed_at: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface QuoteItem {
  id: string
  quote_id: string
  position: number
  kind: QuoteItemKind
  film_id: string | null
  service_type_id: string | null
  glass_zones: GlassZone[]
  description: string
  quantity: number
  unit_price: number
  discount: number
  total: number
}

export interface QuoteEvent {
  id: number
  quote_id: string
  event: 'criado' | 'atualizado' | 'status'
  status: QuoteStatus | null
  note: string | null
  created_by: string | null
  created_at: string
}

export interface ServiceOrder {
  id: string
  number: number
  quote_id: string | null
  customer_id: string
  vehicle_id: string | null
  vehicle_description: string
  vehicle_plate: string | null
  service_type_id: string | null
  description: string
  status: ServiceOrderStatus
  scheduled_at: string | null
  started_at: string | null
  completed_at: string | null
  assigned_to: string | null
  price: number | null
  notes: string
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface AuditEntry {
  id: number
  table_name: string
  record_id: string | null
  record_label: string | null
  action: 'INSERT' | 'UPDATE' | 'DELETE'
  changed_by: string | null
  changed_at: string
  old_data: Record<string, unknown> | null
  new_data: Record<string, unknown> | null
}

export interface DashboardStats {
  customers_total: number
  customers_month: number
  quotes_pending: number
  quotes_pending_value: number
  quotes_approved_month: number
  quotes_approved_month_value: number
  service_orders_total: number
  service_orders_open: number
  service_orders_done_month: number
  simulations_total: number
  simulations_week: number
  vehicles_total: number
  films_total: number
}
