import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import '@fontsource-variable/inter'
import './index.css'
import { App } from './App'
import { AuthProvider } from './auth/AuthProvider'
import { ConfirmProvider, ToastProvider } from './components/ui'
import { env } from './lib/env'
import { SetupRequired } from './features/SetupRequired'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (count, error) => {
        const code = (error as { code?: string })?.code
        if (code === '42501' || code === 'PGRST301') return false
        return count < 1
      },
      refetchOnWindowFocus: false,
      staleTime: 30_000,
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {env.configured ? (
      <QueryClientProvider client={queryClient}>
        <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
          <ToastProvider>
            <ConfirmProvider>
              <AuthProvider>
                <App />
              </AuthProvider>
            </ConfirmProvider>
          </ToastProvider>
        </BrowserRouter>
      </QueryClientProvider>
    ) : (
      <SetupRequired />
    )}
  </StrictMode>,
)
