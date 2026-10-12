import { writeFileSync, mkdirSync } from 'node:fs'
import { randomUUID } from 'node:crypto'
import { createClient } from '@supabase/supabase-js'

/** Cria um administrador exclusivo para esta execução dos testes. */
export default async function globalSetup() {
  const url = process.env.SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) throw new Error('Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY para os testes E2E.')
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } })
  const suffix = randomUUID().slice(0, 8)
  const email = `e2e-admin-${suffix}@artpeliculas.test`
  const password = `E2e-Senha-${suffix}1`
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: 'Eduarda Admin' } })
  if (error) throw error
  const { error: pErr } = await admin.from('profiles').update({ role: 'admin', active: true }).eq('id', data.user.id)
  if (pErr) throw pErr
  mkdirSync('test-results', { recursive: true })
  writeFileSync('test-results/e2e-user.json', JSON.stringify({ email, password, suffix }))
}
