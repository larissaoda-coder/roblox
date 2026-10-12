import { readFileSync } from 'node:fs'
import { expect, type Page } from '@playwright/test'

export function e2eUser() {
  return JSON.parse(readFileSync('test-results/e2e-user.json', 'utf8')) as { email: string; password: string; suffix: string }
}

export async function login(page: Page, email = e2eUser().email, password = e2eUser().password) {
  await page.goto('/entrar')
  await page.getByLabel('E-mail').fill(email)
  await page.getByLabel('Senha', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await page.waitForURL(/\/app$/)
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
}

export const MAILPIT = process.env.MAILPIT_URL ?? 'http://localhost:54324'

export async function waitForEmailLink(to: string, subject: string) {
  const end = Date.now() + 20_000
  while (Date.now() < end) {
    const res = await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:${to}`)}`)
    const data = (await res.json()) as { messages: Array<{ ID: string; Subject: string }> }
    const msg = data.messages.find((m) => m.Subject.includes(subject))
    if (msg) {
      const full = (await (await fetch(`${MAILPIT}/api/v1/message/${msg.ID}`)).json()) as { HTML: string }
      const m = /href="([^"]*\/auth\/v1\/verify[^"]*)"/.exec(full.HTML)
      if (m) return m[1].replace(/&amp;/g, '&')
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`E-mail "${subject}" para ${to} não chegou`)
}

/** Garante que a página não tem rolagem horizontal (layout responsivo). */
export async function expectNoHorizontalScroll(page: Page) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
  expect(overflow, 'rolagem horizontal').toBeLessThanOrEqual(1)
}
