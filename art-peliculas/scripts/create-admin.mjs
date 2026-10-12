#!/usr/bin/env node
// Cria (ou promove) o primeiro administrador do sistema.
// Execute no seu computador — a service_role key nunca deve ir para o frontend.
//
//   SUPABASE_URL=https://xxxx.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=... \
//   npm run create-admin -- admin@empresa.com.br "Senha-Forte-123" "Nome Completo"
import { createClient } from '@supabase/supabase-js'

const [email, password, fullName = 'Administrador'] = process.argv.slice(2)
const url = process.env.SUPABASE_URL
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

function fail(message) {
  console.error(`\n✖ ${message}\n`)
  process.exit(1)
}

if (!url || !serviceKey) fail('Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY nas variáveis de ambiente.')
if (!email || !password) fail('Uso: npm run create-admin -- <email> <senha> ["Nome Completo"]')
if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
  fail('A senha deve ter pelo menos 8 caracteres, com letras e números.')
}

const supabase = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })

let userId
const { data: created, error: createError } = await supabase.auth.admin.createUser({
  email,
  password,
  email_confirm: true,
  user_metadata: { full_name: fullName },
})

if (createError) {
  if (!/already|registered|exists/i.test(createError.message)) fail(createError.message)
  // Usuário já existe: localiza para promover a administrador.
  let page = 1
  while (!userId) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 200 })
    if (error) fail(error.message)
    const found = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase())
    if (found) userId = found.id
    if (data.users.length < 200) break
    page += 1
  }
  if (!userId) fail('Usuário existente não encontrado.')
  console.log('• Usuário já existia; promovendo a administrador.')
} else {
  userId = created.user.id
  console.log('• Usuário criado.')
}

const { error: profileError } = await supabase
  .from('profiles')
  .update({ role: 'admin', active: true, full_name: fullName })
  .eq('id', userId)
if (profileError) fail(`Falha ao atualizar o perfil: ${profileError.message}`)

console.log(`✔ ${email} agora é administrador ativo.`)
