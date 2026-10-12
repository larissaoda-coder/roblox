import { randomUUID } from 'node:crypto'
import { expect, test } from '@playwright/test'
import { login, waitForEmailLink } from './support'

test('administrador convida um vendedor, que acessa apenas o permitido', async ({ page, browser }) => {
  const email = `e2e-vendedor-${randomUUID().slice(0, 8)}@artpeliculas.test`
  await login(page)

  await page.getByRole('link', { name: 'Usuários e permissões' }).click()
  await page.getByRole('button', { name: 'Adicionar usuário' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel('Nome completo').fill('Victor Vendedor')
  await dialog.getByLabel('E-mail').fill(email)
  await dialog.getByLabel('Papel de acesso').selectOption('vendedor')
  await dialog.getByRole('button', { name: 'Enviar convite' }).click()
  await expect(page.getByText(`Convite enviado para ${email}.`)).toBeVisible()
  await expect(page.getByRole('row', { name: /Victor Vendedor/ }).getByText('Convite pendente')).toBeVisible()

  // O convidado define a senha pelo link recebido por e-mail.
  const link = await waitForEmailLink(email, 'convidado')
  const ctx = await browser.newContext()
  const guest = await ctx.newPage()
  await guest.goto(link)
  await expect(guest.getByRole('heading', { name: 'Defina a sua senha' })).toBeVisible()
  await guest.getByLabel('Nova senha', { exact: true }).fill('Vendas-2026')
  await guest.getByLabel('Confirme a nova senha').fill('Vendas-2026')
  await guest.getByRole('button', { name: 'Salvar senha' }).click()
  await expect(guest).toHaveURL(/\/app$/, { timeout: 15_000 })

  // Menu e ações conforme o papel de vendedor.
  const nav = guest.getByRole('navigation', { name: 'Menu principal' })
  await expect(nav.getByRole('link', { name: 'Orçamentos' })).toBeVisible()
  await expect(nav.getByRole('link', { name: 'Histórico' })).toHaveCount(0)
  await expect(nav.getByRole('link', { name: 'Usuários e permissões' })).toHaveCount(0)
  await guest.goto('/app/usuarios')
  await expect(guest.getByRole('heading', { name: 'Acesso restrito' })).toBeVisible()
  await guest.goto('/app/garagem')
  await expect(guest.getByRole('heading', { name: 'Garagem de veículos' })).toBeVisible()
  await expect(guest.getByRole('button', { name: 'Novo veículo' })).toHaveCount(0)
  await guest.goto('/app/peliculas')
  await expect(guest.getByRole('button', { name: 'Nova película' })).toHaveCount(0)
  await guest.goto('/app/clientes')
  await expect(guest.getByRole('button', { name: 'Novo cliente' })).toBeVisible()
  await guest.goto('/app/configuracoes')
  await expect(guest.getByText('Somente administradores e gerentes podem alterar estes dados.')).toBeVisible()

  // O administrador desativa a conta: o acesso é bloqueado imediatamente.
  await page.reload()
  const row = page.getByRole('row', { name: /Victor Vendedor/ })
  await row.getByRole('switch').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Desativar' }).click()
  await expect(page.getByText('Usuário desativado.')).toBeVisible()
  await guest.goto('/app')
  await expect(guest.getByRole('heading', { name: 'Acesso ainda não liberado' })).toBeVisible()
  await ctx.close()
})
