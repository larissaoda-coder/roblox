import { describe, expect, it } from 'vitest'
import { AppError, toMessage } from './errors'

describe('mensagens de erro', () => {
  it('traduz erros de autenticação', () => {
    expect(toMessage({ message: 'Invalid login credentials' })).toBe('E-mail ou senha incorretos.')
    expect(toMessage({ message: 'User is banned' })).toContain('desativada')
  })
  it('traduz violações do banco', () => {
    expect(toMessage({ code: '42501', message: 'new row violates row-level security policy for table "films"' })).toBe('Você não tem permissão para realizar esta ação.')
    expect(toMessage({ code: '23505', message: 'duplicate key value violates unique constraint "customers_document_key"' })).toBe('Já existe um cliente com este CPF/CNPJ.')
  })
  it('mantém mensagens de negócio em português', () => {
    expect(toMessage({ code: 'P0001', message: 'Desconto de 15,00% acima do limite autorizado de 10,00%.' })).toContain('Desconto de 15,00%')
    expect(toMessage(new AppError('Mensagem própria'))).toBe('Mensagem própria')
  })
  it('usa mensagem genérica para erros desconhecidos', () => {
    expect(toMessage({ message: 'xyz internal' })).toBe('Ocorreu um erro inesperado. Tente novamente.')
  })
})
