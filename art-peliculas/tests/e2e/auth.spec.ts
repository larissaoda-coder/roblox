import { createClient } from '@supabase/supabase-js'
import { randomUUID } from 'node:crypto'
import { expect, test } from '@playwright/test'
import { e2eUser, login, waitForEmailLink } from './support'

test.describe('acesso e autenticação', () => {
  test('página inicial apresenta o sistema e leva ao login', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Simulação, orçamento e gestão')
    await page.getByRole('radio', { name: '5%', exact: true }).click()
    await expect(page.getByText('Transmissão luminosa: 5%')).toBeVisible()
    await page.getByRole('link', { name: 'Entrar no sistema' }).click()
    await expect(page).toHaveURL(/\/entrar$/)
  })

  test('rotas internas exigem login', async ({ page }) => {
    await page.goto('/app/orcamentos')
    await expect(page).toHaveURL(/\/entrar$/)
    await expect(page.getByRole('heading', { name: 'Entrar' })).toBeVisible()
  })

  test('valida campos e informa credenciais incorretas', async ({ page }) => {
    await page.goto('/entrar')
    await page.getByRole('button', { name: 'Entrar', exact: true }).click()
    await expect(page.getByText('Informe o e-mail.')).toBeVisible()
    await expect(page.getByText('Informe a senha.')).toBeVisible()

    await page.getByLabel('E-mail').fill('naoexiste@artpeliculas.test')
    await page.getByLabel('Senha', { exact: true }).fill('errada123')
    await page.getByRole('button', { name: 'Entrar', exact: true }).click()
    await expect(page.getByRole('alert').filter({ hasText: 'E-mail ou senha incorretos.' })).toBeVisible()
  })

  test('mostra e oculta a senha', async ({ page }) => {
    await page.goto('/entrar')
    const input = page.getByLabel('Senha', { exact: true })
    await input.fill('segredo1')
    await expect(input).toHaveAttribute('type', 'password')
    await page.getByRole('button', { name: 'Mostrar senha' }).click()
    await expect(input).toHaveAttribute('type', 'text')
  })

  test('entra, retorna à rota pedida e sai', async ({ page }) => {
    await page.goto('/app/clientes')
    await expect(page).toHaveURL(/\/entrar$/)
    const { email, password } = e2eUser()
    await page.getByLabel('E-mail').fill(email)
    await page.getByLabel('Senha', { exact: true }).fill(password)
    await page.getByRole('button', { name: 'Entrar', exact: true }).click()
    await expect(page).toHaveURL(/\/app\/clientes$/)
    await expect(page.getByRole('heading', { name: 'Clientes' })).toBeVisible()

    await page.getByRole('button', { name: /Eduarda Admin/ }).click()
    await page.getByRole('menuitem', { name: 'Sair' }).click()
    await page.goto('/app')
    await expect(page).toHaveURL(/\/entrar$/)
  })

  test('recupera a senha pelo link enviado por e-mail', async ({ page, browser }) => {
    // Usuário próprio para não afetar o administrador dos demais testes.
    const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, { auth: { persistSession: false } })
    const email = `e2e-recupera-${randomUUID().slice(0, 8)}@artpeliculas.test`
    const { data } = await admin.auth.admin.createUser({ email, password: 'Antiga-Senha-1', email_confirm: true, user_metadata: { full_name: 'Rita Recupera' } })
    await admin.from('profiles').update({ role: 'vendedor', active: true }).eq('id', data.user!.id)

    await page.goto('/entrar')
    await page.getByRole('link', { name: 'Esqueci minha senha' }).click()
    await page.getByLabel('E-mail').fill(email)
    await page.getByRole('button', { name: 'Enviar link de redefinição' }).click()
    await expect(page.getByText('Se houver uma conta com este e-mail')).toBeVisible()

    const link = await waitForEmailLink(email, 'Redefinição de senha')
    const ctx = await browser.newContext()
    const p2 = await ctx.newPage()
    await p2.goto(link)
    await expect(p2).toHaveURL(/\/redefinir-senha/)
    await expect(p2.getByRole('heading', { name: 'Criar nova senha' })).toBeVisible()
    await p2.getByLabel('Nova senha', { exact: true }).fill('fraca')
    await p2.getByLabel('Confirme a nova senha').fill('outra')
    await p2.getByRole('button', { name: 'Salvar senha' }).click()
    await expect(p2.getByText('As senhas não conferem.')).toBeVisible()
    await p2.getByLabel('Nova senha', { exact: true }).fill('Nova-Senha-2026')
    await p2.getByLabel('Confirme a nova senha').fill('Nova-Senha-2026')
    await p2.getByRole('button', { name: 'Salvar senha' }).click()
    await expect(p2).toHaveURL(/\/app$/, { timeout: 15_000 })
    await ctx.close()

    await login(page, email, 'Nova-Senha-2026')
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Rita')
  })

  test('link de recuperação inválido orienta a solicitar outro', async ({ page }) => {
    await page.goto('/redefinir-senha#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired')
    await expect(page.getByRole('heading', { name: 'Link inválido ou expirado' })).toBeVisible()
    await expect(page.getByRole('link', { name: 'Solicitar novo link' })).toBeVisible()
  })
})
