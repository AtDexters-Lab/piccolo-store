// Immich init script: creates admin user and configures OIDC via the Immich API.
// Runs via podman exec after the Immich server container is started.
// All sensitive values are injected as environment variables.

const BASE = 'http://localhost:2283/api';
const h = { 'Content-Type': 'application/json' };

async function main() {
  // Wait for Immich server to be ready (up to 30s).
  let ready = false;
  for (let i = 0; i < 30; i++) {
    try {
      const r = await fetch(BASE + '/server/ping');
      if (r.ok) { ready = true; break; }
    } catch {}
    await new Promise(r => setTimeout(r, 1000));
  }
  if (!ready) throw new Error('Immich server not ready after 30s');

  // Create admin user (400 = already exists, treated as OK for idempotency).
  const signup = await fetch(BASE + '/auth/admin-sign-up', {
    method: 'POST', headers: h,
    body: JSON.stringify({
      email: process.env.ADMIN_EMAIL,
      name: 'Admin',
      password: process.env.ADMIN_PASSWORD
    })
  });
  if (!signup.ok && signup.status !== 400) {
    throw new Error('admin signup failed: ' + signup.status + ' ' + await signup.text());
  }

  // Login to get access token.
  const loginResp = await fetch(BASE + '/auth/login', {
    method: 'POST', headers: h,
    body: JSON.stringify({
      email: process.env.ADMIN_EMAIL,
      password: process.env.ADMIN_PASSWORD
    })
  });
  if (!loginResp.ok) {
    throw new Error('admin login failed: ' + loginResp.status + ' ' + await loginResp.text());
  }
  const { accessToken } = await loginResp.json();
  const auth = { ...h, Authorization: 'Bearer ' + accessToken };

  // GET full system config, modify oauth section, PUT back.
  // Immich requires the full config object (all 21 sections) for PUT.
  const configResp = await fetch(BASE + '/system-config', { headers: auth });
  if (!configResp.ok) {
    throw new Error('get system config failed: ' + configResp.status);
  }
  const cfg = await configResp.json();

  cfg.oauth = { ...cfg.oauth,
    enabled: true,
    autoRegister: true,
    autoLaunch: true,
    clientId: process.env.OAUTH_CLIENT_ID,
    clientSecret: process.env.OAUTH_CLIENT_SECRET,
    issuerUrl: process.env.OAUTH_ISSUER,
    buttonText: 'Login with SSO',
    scope: 'openid email profile',
    tokenEndpointAuthMethod: 'client_secret_post'
  };
  // Disable password login so users go through Piccolo SSO only.
  // The admin password still exists as an emergency fallback (resettable via Immich CLI).
  cfg.passwordLogin = { ...cfg.passwordLogin, enabled: false };

  const updateResp = await fetch(BASE + '/system-config', {
    method: 'PUT', headers: auth,
    body: JSON.stringify(cfg)
  });
  if (!updateResp.ok) {
    throw new Error('update system config failed: ' + updateResp.status + ' ' + await updateResp.text());
  }

  console.log('Immich OIDC configured successfully');
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
