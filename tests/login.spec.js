import { test, expect } from '@playwright/test';

test('kan logga in', async ({ page }) => {
  await page.goto('http://localhost:9292/login');

  await page.locator('input[name="username"]').fill('hejhejhej');
  await page.locator('input[name="password"]').fill('hejhejhej');
  await page.getByRole('button', { name: 'Login' }).click();

  await expect(page).toHaveURL('http://localhost:9292/');

  await page.goto('http://localhost:9292/admin/message');
  await expect(page).toHaveURL('http://localhost:9292/admin/message');
});