/** Erros de aplicação com mensagem já pronta para o usuário. */
export class AppError extends Error {
  constructor(
    message: string,
    public code?: string,
  ) {
    super(message)
    this.name = 'AppError'
  }
}

interface ErrorLike {
  message?: string
  code?: string
  status?: number
  details?: string | null
  hint?: string | null
  name?: string
}

const AUTH_MESSAGES: Array<[RegExp, string]> = [
  [/invalid login credentials/i, 'E-mail ou senha incorretos.'],
  [/email not confirmed/i, 'Confirme o seu e-mail antes de entrar. Verifique a sua caixa de entrada.'],
  [/user is banned|user banned/i, 'Esta conta está desativada. Fale com o administrador.'],
  [/rate limit|too many requests|over_email_send_rate_limit/i, 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.'],
  [/for security purposes, you can only request this/i, 'Por segurança, aguarde alguns segundos antes de solicitar novamente.'],
  [/new password should be different/i, 'A nova senha deve ser diferente da senha atual.'],
  [/password should be at least|weak password/i, 'A senha é muito fraca. Use pelo menos 8 caracteres, com letras e números.'],
  [/auth session missing|jwt expired|invalid jwt|refresh token/i, 'Sua sessão expirou. Entre novamente.'],
  [/email link is invalid or has expired|otp_expired|token has expired/i, 'O link expirou ou já foi utilizado. Solicite um novo.'],
  [/signups not allowed|signup is disabled/i, 'O cadastro público está desativado. Solicite um convite ao administrador.'],
  [/failed to fetch|networkerror|network request failed|load failed/i, 'Não foi possível conectar ao servidor. Verifique a sua conexão.'],
]

const DB_CODES: Record<string, string> = {
  '42501': 'Você não tem permissão para realizar esta ação.',
  '23505': 'Já existe um registro com estes dados.',
  '23503': 'Este registro está vinculado a outros dados e não pode ser removido ou alterado.',
  '23514': 'Alguns dados não passaram na validação. Revise os campos e tente novamente.',
  '23502': 'Preencha todos os campos obrigatórios.',
  '22P02': 'Há um valor em formato inválido.',
  '22001': 'Um dos textos excede o tamanho permitido.',
  '22003': 'Um dos valores numéricos está fora do intervalo permitido.',
  PGRST301: 'Sua sessão expirou. Entre novamente.',
  PGRST116: 'Registro não encontrado.',
}

const CONSTRAINT_MESSAGES: Array<[RegExp, string]> = [
  [/customers_document_key/, 'Já existe um cliente com este CPF/CNPJ.'],
  [/vehicles_identity_key/, 'Já existe um veículo com esta marca, modelo e geração.'],
  [/films_identity_key/, 'Já existe uma película com este nome, fabricante e linha.'],
  [/service_types_name_key/, 'Já existe um tipo de serviço com este nome.'],
  [/quotes_customer_id_fkey|service_orders_customer_id_fkey/, 'Este cliente possui orçamentos ou ordens de serviço e não pode ser excluído.'],
  [/customers_document_check/, 'CPF ou CNPJ inválido.'],
  [/settings_document_check/, 'CNPJ/CPF da empresa inválido.'],
  [/vehicle_plate_check/, 'Placa inválida. Use o padrão AAA-9999 ou Mercosul AAA9A99.'],
  [/vehicles_model_credit/, 'Informe a origem/licença do modelo 3D.'],
  [/glass_masks_check/, 'As máscaras dos vidros são inválidas.'],
  [/row-level security/, 'Você não tem permissão para realizar esta ação.'],
  [/bucket.*not found/i, 'Armazenamento de mídia não configurado no projeto.'],
  [/mime type .* is not supported|invalid_mime_type/i, 'Tipo de arquivo não permitido.'],
  [/payload too large|exceeded the maximum allowed size|entity too large/i, 'O arquivo excede o tamanho máximo permitido (50 MB).'],
]

/** Converte qualquer erro (Supabase, Postgres, rede) em uma mensagem amigável em português. */
export function toMessage(error: unknown, fallback = 'Ocorreu um erro inesperado. Tente novamente.'): string {
  if (!error) return fallback
  if (error instanceof AppError) return error.message
  const e = error as ErrorLike
  const message = e.message ?? (typeof error === 'string' ? error : '')
  const blob = `${message} ${e.details ?? ''} ${e.hint ?? ''}`

  for (const [re, text] of CONSTRAINT_MESSAGES) if (re.test(blob)) return text
  for (const [re, text] of AUTH_MESSAGES) if (re.test(blob)) return text

  // Mensagens lançadas pelas nossas funções no banco (RAISE EXCEPTION) já estão em português.
  if (e.code === 'P0001' || (e.code === '22023' && message)) return message
  if (e.code === '42501' && /você|permissão/i.test(message)) return message
  if (e.code && DB_CODES[e.code]) return DB_CODES[e.code]
  if (/[áéíóúãõç]/i.test(message)) return message
  return fallback
}

/** Lança um AppError caso uma atualização/exclusão não afete nenhuma linha (bloqueio por RLS). */
export function ensureAffected<T>(rows: T[] | null, message = 'Você não tem permissão para realizar esta ação ou o registro não existe mais.'): T[] {
  if (!rows || rows.length === 0) throw new AppError(message, '42501')
  return rows
}
