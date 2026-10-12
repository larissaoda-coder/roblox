// Edge Function: administração de usuários (convite, criação e ativação/desativação).
// Executa no servidor com a service_role key, que NUNCA é exposta ao navegador.
// Toda chamada é validada: o solicitante precisa estar autenticado, ativo e ter a
// permissão "usuarios.gerenciar".
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const ROLES = ['admin', 'gerente', 'vendedor', 'instalador'] as const
type Role = (typeof ROLES)[number]

class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
  })
}

function env(name: string) {
  const value = Deno.env.get(name)
  if (!value) throw new HttpError(500, `Variável de ambiente ${name} não configurada na função.`)
  return value
}

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

function parseEmail(value: unknown) {
  const email = String(value ?? '').trim().toLowerCase()
  if (!EMAIL_RE.test(email) || email.length > 160) throw new HttpError(400, 'Informe um e-mail válido.')
  return email
}

function parseName(value: unknown) {
  const name = String(value ?? '').trim().replace(/\s+/g, ' ')
  if (name.length < 2 || name.length > 120) throw new HttpError(400, 'Informe o nome completo (2 a 120 caracteres).')
  return name
}

function parseRole(value: unknown): Role {
  if (!ROLES.includes(value as Role)) throw new HttpError(400, 'Papel de acesso inválido.')
  return value as Role
}

function parseUuid(value: unknown) {
  const id = String(value ?? '')
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    throw new HttpError(400, 'Usuário inválido.')
  }
  return id
}

// Regras mínimas de senha, iguais às do formulário do sistema.
function parsePassword(value: unknown) {
  const password = String(value ?? '')
  if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    throw new HttpError(400, 'A senha deve ter pelo menos 8 caracteres, com letras e números.')
  }
  return password
}

function redirectUrl(req: Request) {
  const configured = Deno.env.get('SITE_URL')
  const origin = req.headers.get('origin') ?? configured
  if (!origin) return undefined
  return `${origin.replace(/\/$/, '')}/redefinir-senha`
}

function translateAuthError(message: string) {
  const m = message.toLowerCase()
  if (m.includes('already been registered') || m.includes('already registered') || m.includes('email_exists')) {
    return 'Já existe um usuário com este e-mail.'
  }
  if (m.includes('rate limit')) return 'Muitos e-mails enviados em pouco tempo. Aguarde alguns minutos e tente novamente.'
  if (m.includes('smtp') || m.includes('sending')) return 'Não foi possível enviar o e-mail. Verifique a configuração de SMTP do projeto.'
  return message
}

async function activateProfile(userClient: SupabaseClient, id: string, fullName: string, role: Role) {
  // Feito com o token do solicitante: as políticas RLS e o histórico registram quem fez a alteração.
  const { data, error } = await userClient
    .from('profiles')
    .update({ full_name: fullName, role, active: true })
    .eq('id', id)
    .select('id')
  if (error) throw new HttpError(400, error.message)
  if (!data?.length) throw new HttpError(403, 'Não foi possível atualizar o perfil do novo usuário.')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Método não permitido.' }, 405)

  try {
    const url = env('SUPABASE_URL')
    const anonKey = env('SUPABASE_ANON_KEY')
    const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY')

    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace(/^Bearer\s+/i, '')
    if (!token) throw new HttpError(401, 'Sessão expirada. Entre novamente.')

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
    const userClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    })

    const { data: userData, error: userError } = await admin.auth.getUser(token)
    if (userError || !userData.user) throw new HttpError(401, 'Sessão expirada. Entre novamente.')
    const caller = userData.user

    const { data: allowed, error: permError } = await userClient.rpc('has_permission', {
      p_permission: 'usuarios.gerenciar',
    })
    if (permError) throw new HttpError(500, permError.message)
    if (!allowed) throw new HttpError(403, 'Você não tem permissão para gerenciar usuários.')

    const body = await req.json().catch(() => {
      throw new HttpError(400, 'Requisição inválida.')
    })
    const action = String(body?.action ?? '')

    if (action === 'invite') {
      const email = parseEmail(body.email)
      const fullName = parseName(body.full_name)
      const role = parseRole(body.role)
      const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
        data: { full_name: fullName },
        redirectTo: redirectUrl(req),
      })
      if (error || !data.user) throw new HttpError(400, translateAuthError(error?.message ?? 'Falha ao convidar.'))
      await activateProfile(userClient, data.user.id, fullName, role)
      return json({ id: data.user.id, message: `Convite enviado para ${email}.` })
    }

    if (action === 'create') {
      const email = parseEmail(body.email)
      const fullName = parseName(body.full_name)
      const role = parseRole(body.role)
      const password = parsePassword(body.password)
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
      })
      if (error || !data.user) throw new HttpError(400, translateAuthError(error?.message ?? 'Falha ao criar usuário.'))
      await activateProfile(userClient, data.user.id, fullName, role)
      return json({ id: data.user.id, message: `Usuário ${email} criado.` })
    }

    if (action === 'set_active') {
      const id = parseUuid(body.user_id)
      const active = body.active === true
      if (id === caller.id) throw new HttpError(400, 'Você não pode desativar a sua própria conta.')
      // 1) Perfil (valida regras como "manter ao menos um administrador ativo").
      const { data, error } = await userClient.from('profiles').update({ active }).eq('id', id).select('id')
      if (error) throw new HttpError(400, error.message)
      if (!data?.length) throw new HttpError(404, 'Usuário não encontrado.')
      // 2) Bloqueia/desbloqueia o login na conta de acesso.
      const { error: banError } = await admin.auth.admin.updateUserById(id, {
        ban_duration: active ? 'none' : '876000h',
      })
      if (banError) throw new HttpError(500, translateAuthError(banError.message))
      return json({ id, message: active ? 'Usuário reativado.' : 'Usuário desativado.' })
    }

    throw new HttpError(400, 'Ação desconhecida.')
  } catch (err) {
    if (err instanceof HttpError) return json({ error: err.message }, err.status)
    console.error(err)
    return json({ error: 'Erro interno ao processar a solicitação.' }, 500)
  }
})
