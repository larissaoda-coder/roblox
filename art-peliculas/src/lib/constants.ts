import type {
  AppRole,
  FilmFinish,
  FilmPriceUnit,
  GlassZone,
  ImageView,
  QuoteItemKind,
  QuoteStatus,
  ServiceOrderStatus,
  SimulationMode,
  VehicleCategory,
} from '@/types/domain'

export const ROLE_LABELS: Record<AppRole, string> = {
  admin: 'Administrador',
  gerente: 'Gerente',
  vendedor: 'Vendedor',
  instalador: 'Instalador',
}
export const ROLES: AppRole[] = ['admin', 'gerente', 'vendedor', 'instalador']

export const CATEGORY_LABELS: Record<VehicleCategory, string> = {
  hatch: 'Hatch',
  sedan: 'Sedã',
  suv: 'SUV',
  picape: 'Picape',
  minivan: 'Minivan',
  cupe: 'Cupê',
  utilitario: 'Utilitário',
}
export const CATEGORIES = Object.keys(CATEGORY_LABELS) as VehicleCategory[]

export const ZONES: GlassZone[] = ['para_brisa', 'dianteiros', 'traseiros', 'vidro_traseiro']
export const ZONE_LABELS: Record<GlassZone, string> = {
  para_brisa: 'Para-brisa',
  dianteiros: 'Vidros dianteiros',
  traseiros: 'Vidros traseiros',
  vidro_traseiro: 'Vidro traseiro principal',
}
export const ZONE_SHORT: Record<GlassZone, string> = {
  para_brisa: 'Para-brisa',
  dianteiros: 'Dianteiros',
  traseiros: 'Traseiros',
  vidro_traseiro: 'Vidro traseiro',
}

export const VIEW_LABELS: Record<ImageView, string> = {
  frente_34: 'Frente 3/4',
  traseira_34: 'Traseira 3/4',
  lateral: 'Lateral',
  frontal: 'Frontal',
  traseira: 'Traseira',
}
export const VIEWS = Object.keys(VIEW_LABELS) as ImageView[]

export const PRICE_UNIT_LABELS: Record<FilmPriceUnit, string> = {
  veiculo: 'por veículo',
  vidro: 'por vidro',
  m2: 'por m²',
}
export const FINISH_LABELS: Record<FilmFinish, string> = {
  neutra: 'Neutra (fumê)',
  refletiva: 'Refletiva',
}

export const MODE_LABELS: Record<SimulationMode, string> = {
  imagem: 'Imagem com máscaras',
  modelo_3d: 'Modelo 3D',
  referencia: 'Modelo de referência',
}

export const QUOTE_STATUS_LABELS: Record<QuoteStatus, string> = {
  rascunho: 'Rascunho',
  enviado: 'Enviado',
  aprovado: 'Aprovado',
  recusado: 'Recusado',
  concluido: 'Concluído',
}
export const QUOTE_STATUSES = Object.keys(QUOTE_STATUS_LABELS) as QuoteStatus[]

/** Transições permitidas (espelha public.set_quote_status). */
export const QUOTE_TRANSITIONS: Record<QuoteStatus, QuoteStatus[]> = {
  rascunho: ['enviado', 'aprovado', 'recusado'],
  enviado: ['aprovado', 'recusado', 'rascunho'],
  aprovado: ['concluido', 'enviado', 'rascunho'],
  recusado: ['enviado', 'rascunho'],
  concluido: ['aprovado'],
}

export const ITEM_KIND_LABELS: Record<QuoteItemKind, string> = {
  pelicula: 'Película',
  servico: 'Serviço',
  outro: 'Outro',
}

export const SERVICE_STATUS_LABELS: Record<ServiceOrderStatus, string> = {
  agendado: 'Agendado',
  em_andamento: 'Em andamento',
  concluido: 'Concluído',
  cancelado: 'Cancelado',
}
export const SERVICE_STATUSES = Object.keys(SERVICE_STATUS_LABELS) as ServiceOrderStatus[]

export const TABLE_LABELS: Record<string, string> = {
  profiles: 'Usuário',
  role_permissions: 'Permissão',
  settings: 'Configurações',
  vehicles: 'Veículo',
  vehicle_images: 'Imagem de veículo',
  films: 'Película',
  vehicle_films: 'Película do veículo',
  service_types: 'Tipo de serviço',
  customers: 'Cliente',
  quotes: 'Orçamento',
  service_orders: 'Ordem de serviço',
}

export const BR_STATES = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI',
  'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
]

/** Níveis de transmissão luminosa (VLT) usuais no mercado. */
export const VLT_PRESETS = [5, 20, 35, 50, 70, 80]

/** Quantidade padrão de vidros por zona (para películas cobradas por vidro). */
export const ZONE_GLASS_COUNT: Record<GlassZone, number> = {
  para_brisa: 1,
  dianteiros: 2,
  traseiros: 2,
  vidro_traseiro: 1,
}
