const { chromium } = require('playwright');

const baseUrl = (process.env.E2E_BASE_URL || '').replace(/\/$/, '');
const requireAuth = /^true$/i.test(process.env.E2E_REQUIRE_AUTH || '');
if (!baseUrl) throw new Error('E2E_BASE_URL es obligatorio.');

const profiles = [
  { name: 'admin', email: process.env.E2E_ADMIN_EMAIL, password: process.env.E2E_ADMIN_PASSWORD, landing: '/Admin' },
  { name: 'client', email: process.env.E2E_CLIENT_EMAIL, password: process.env.E2E_CLIENT_PASSWORD, landing: '/' },
  { name: 'seller', email: process.env.E2E_SELLER_EMAIL, password: process.env.E2E_SELLER_PASSWORD, landing: '/SellerOrders' },
  { name: 'driver', email: process.env.E2E_DRIVER_EMAIL, password: process.env.E2E_DRIVER_PASSWORD, landing: '/DriverDeliveries' }
];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function login(page, profile) {
  await page.goto(`${baseUrl}/Account/Login`, { waitUntil: 'domcontentloaded' });
  await page.locator('#Email').fill(profile.email);
  await page.locator('#Password').fill(profile.password);
  await Promise.all([
    page.waitForURL(url => profile.landing === '/' ? url.pathname === '/' : url.pathname.startsWith(profile.landing)),
    page.locator('button[type="submit"]').click()
  ]);
  const currentPath = new URL(page.url()).pathname;
  assert(profile.landing === '/' ? currentPath === '/' : currentPath.startsWith(profile.landing), `${profile.name}: destino de login inesperado: ${page.url()}`);
}

(async () => {
  const launchOptions = { headless: true };
  if (process.env.E2E_BROWSER_CHANNEL) launchOptions.channel = process.env.E2E_BROWSER_CHANNEL;
  const browser = await chromium.launch(launchOptions);
  const failures = [];
  try {
    const publicPage = await browser.newPage();
    publicPage.setDefaultTimeout(15000);
    publicPage.on('console', message => { if (message.type() === 'error') failures.push(`consola pública: ${message.text()}`); });
    await publicPage.goto(`${baseUrl}/Account/Login?returnUrl=%2FCart%2FCheckout`, { waitUntil: 'domcontentloaded' });
    assert(await publicPage.locator('input[name="returnUrl"]').getAttribute('value') === '/Cart/Checkout', 'Login no preserva returnUrl local.');
    await publicPage.goto(`${baseUrl}/Home/Contact`, { waitUntil: 'domcontentloaded' });
    assert(await publicPage.locator('form').count() > 0, 'Formulario público de contacto no disponible.');
    await publicPage.close();

    for (const profile of profiles) {
      if (!profile.email || !profile.password) {
        if (requireAuth) failures.push(`${profile.name}: faltan credenciales E2E autorizadas.`);
        continue;
      }
      const context = await browser.newContext();
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      page.on('console', message => { if (message.type() === 'error') failures.push(`${profile.name} consola: ${message.text()}`); });
      try {
        await login(page, profile);
        if (profile.name === 'seller' && process.env.E2E_FOREIGN_SELLER_ORDER_ID) {
          const response = await page.goto(`${baseUrl}/SellerOrders/Confirmation/${process.env.E2E_FOREIGN_SELLER_ORDER_ID}`);
          assert(response && response.status() === 404, 'Vendedor pudo consultar un pedido ajeno.');
        }
        if (profile.name === 'client' && process.env.E2E_FOREIGN_CLIENT_ORDER_ID) {
          const response = await page.goto(`${baseUrl}/ClientPortal/Detail/${process.env.E2E_FOREIGN_CLIENT_ORDER_ID}`);
          assert(response && response.status() === 404, 'Cliente pudo consultar un pedido ajeno.');
        }
        const logout = page.locator('form[action*="/Account/Logout"] button[type="submit"]');
        if (await logout.count()) {
          await Promise.all([page.waitForNavigation({ waitUntil: 'domcontentloaded' }), logout.first().click()]);
          const privateKeys = await page.evaluate(() => Object.keys(localStorage).filter(key => key.startsWith('distribuidorajj:user:')));
          assert(privateKeys.length === 0, `${profile.name}: quedaron datos offline privados tras logout.`);
        }
      } catch (error) {
        failures.push(`${profile.name}: ${error.message}`);
      } finally {
        await context.close();
      }
    }
  } finally {
    await browser.close();
  }

  if (failures.length) throw new Error(failures.join('\n'));
  process.stdout.write('Stage 1 E2E smoke passed.\n');
})().catch(error => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
