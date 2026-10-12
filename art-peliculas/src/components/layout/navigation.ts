import {
  Car,
  FileText,
  History,
  Layers,
  LayoutDashboard,
  Settings,
  ShieldCheck,
  SunDim,
  Users,
  Wrench,
  type LucideIcon,
} from 'lucide-react'
import type { Permission } from '@/types/domain'

export interface NavItem {
  to: string
  label: string
  icon: LucideIcon
  permission?: Permission
  end?: boolean
  dividerBefore?: boolean
}

export const NAV_ITEMS: NavItem[] = [
  { to: '/app', label: 'Visão geral', icon: LayoutDashboard, end: true },
  { to: '/app/garagem', label: 'Garagem de veículos', icon: Car },
  { to: '/app/simulador', label: 'Simulador de insulfilm', icon: SunDim },
  { to: '/app/peliculas', label: 'Catálogo de películas', icon: Layers },
  { to: '/app/clientes', label: 'Clientes', icon: Users },
  { to: '/app/orcamentos', label: 'Orçamentos', icon: FileText },
  { to: '/app/servicos', label: 'Serviços', icon: Wrench },
  { to: '/app/historico', label: 'Histórico', icon: History, permission: 'historico.ver', dividerBefore: true },
  { to: '/app/usuarios', label: 'Usuários e permissões', icon: ShieldCheck, permission: 'usuarios.gerenciar' },
  { to: '/app/configuracoes', label: 'Configurações', icon: Settings },
]
