import { lazy, Suspense, type ComponentType } from 'react'
import { Route, Routes } from 'react-router-dom'
import { PageLoader } from '@/components/ui'
import { AppLayout } from '@/components/layout/AppLayout'
import { PublicLayout } from '@/components/layout/PublicLayout'
import { ProtectedRoute, RequirePermission } from '@/auth/ProtectedRoute'
import { LandingPage } from '@/features/landing/LandingPage'
import { LoginPage } from '@/features/auth/LoginPage'
import { ForgotPasswordPage } from '@/features/auth/ForgotPasswordPage'
import { ResetPasswordPage } from '@/features/auth/ResetPasswordPage'
import { NotFoundPage } from '@/features/NotFoundPage'

function page<T extends Record<string, ComponentType>>(loader: () => Promise<T>, name: keyof T) {
  return lazy(() => loader().then((m) => ({ default: m[name] })))
}

const DashboardPage = page(() => import('@/features/dashboard/DashboardPage'), 'DashboardPage')
const VehiclesPage = page(() => import('@/features/vehicles/VehiclesPage'), 'VehiclesPage')
const VehicleDetailPage = page(() => import('@/features/vehicles/VehicleDetailPage'), 'VehicleDetailPage')
const SimulatorPage = page(() => import('@/features/simulator/SimulatorPage'), 'SimulatorPage')
const FilmsPage = page(() => import('@/features/films/FilmsPage'), 'FilmsPage')
const CustomersPage = page(() => import('@/features/customers/CustomersPage'), 'CustomersPage')
const CustomerDetailPage = page(() => import('@/features/customers/CustomerDetailPage'), 'CustomerDetailPage')
const QuotesPage = page(() => import('@/features/quotes/QuotesPage'), 'QuotesPage')
const QuoteEditorPage = page(() => import('@/features/quotes/QuoteEditorPage'), 'QuoteEditorPage')
const QuoteDetailPage = page(() => import('@/features/quotes/QuoteDetailPage'), 'QuoteDetailPage')
const QuotePrintPage = page(() => import('@/features/quotes/QuotePrintPage'), 'QuotePrintPage')
const ServicesPage = page(() => import('@/features/services/ServicesPage'), 'ServicesPage')
const HistoryPage = page(() => import('@/features/history/HistoryPage'), 'HistoryPage')
const UsersPage = page(() => import('@/features/users/UsersPage'), 'UsersPage')
const SettingsPage = page(() => import('@/features/settings/SettingsPage'), 'SettingsPage')

export function App() {
  return (
    <Routes>
      <Route element={<PublicLayout />}>
        <Route index element={<LandingPage />} />
      </Route>
      <Route path="/entrar" element={<LoginPage />} />
      <Route path="/recuperar-senha" element={<ForgotPasswordPage />} />
      <Route path="/redefinir-senha" element={<ResetPasswordPage />} />

      <Route path="/app" element={<ProtectedRoute />}>
        <Route element={<AppLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="garagem" element={<VehiclesPage />} />
          <Route path="garagem/:id" element={<VehicleDetailPage />} />
          <Route path="simulador" element={<SimulatorPage />} />
          <Route path="peliculas" element={<FilmsPage />} />
          <Route path="clientes" element={<CustomersPage />} />
          <Route path="clientes/:id" element={<CustomerDetailPage />} />
          <Route path="orcamentos" element={<QuotesPage />} />
          <Route path="orcamentos/novo" element={<QuoteEditorPage />} />
          <Route path="orcamentos/:id" element={<QuoteDetailPage />} />
          <Route path="orcamentos/:id/editar" element={<QuoteEditorPage />} />
          <Route path="servicos" element={<ServicesPage />} />
          <Route
            path="historico"
            element={
              <RequirePermission permission="historico.ver">
                <HistoryPage />
              </RequirePermission>
            }
          />
          <Route
            path="usuarios"
            element={
              <RequirePermission permission="usuarios.gerenciar">
                <UsersPage />
              </RequirePermission>
            }
          />
          <Route path="configuracoes" element={<SettingsPage />} />
          <Route path="*" element={<NotFoundPage inApp />} />
        </Route>
        <Route
          path="orcamentos/:id/imprimir"
          element={
            <Suspense fallback={<PageLoader />}>
              <QuotePrintPage />
            </Suspense>
          }
        />
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
