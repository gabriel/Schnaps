export const versionPattern = /^\d+\.\d+\.\d+(?:-beta\.[1-9]\d*)?$/;
function deliveryFailure(code) { const error = new Error('Analytics delivery failed'); error.analyticsCode = code; return error; }
function failureCode(error) { return /^(missing-key|missing-service|http-[0-9]{3})$/.test(error?.analyticsCode ?? '') ? error.analyticsCode : 'transport'; }
export function excludesAnalytics(request) {
  return request.headers.get('x-analytics-excluded') === '1' ||
    (request.headers.get('cookie') ?? '').split(';').some(part => part.trim() === '__Host-analytics_excluded=1');
}
export function browserExclusion(request) {
  const headers = { 'cache-control': 'no-store', 'content-type': 'text/html; charset=utf-8',
    'content-security-policy': "default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'", 'referrer-policy': 'no-referrer' };
  if (request.method === 'POST') {
    if (request.headers.get('origin') !== new URL(request.url).origin) return new Response('Forbidden', { status: 403, headers });
    return new Response(null, { status: 303, headers: { ...headers, location: '/analytics/exclude',
      'set-cookie': '__Host-analytics_excluded=1; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=31536000' } });
  }
  if (request.method !== 'GET') return new Response('Method not allowed', { status: 405, headers: { ...headers, allow: 'GET, POST' } });
  return new Response(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="robots" content="noindex"><title>Exclude this browser</title><h1>Exclude this browser from statistics</h1><p>${excludesAnalytics(request) ? 'This browser is excluded.' : 'Exclude future Schnaps downloads from this browser. This saves only an on/off cookie, with no unique identifier.'}</p><form method="post"><button>Exclude this browser</button></form></html>`, { headers });
}
export async function sendEvent(event, env) {
  if (!env.ANALYTICS_FORWARDING_KEY) throw deliveryFailure('missing-key');
  if (!env.ANALYTICS?.fetch) throw deliveryFailure('missing-service');
  const response = await env.ANALYTICS.fetch('https://rel.me/api/analytics/schnaps', {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${env.ANALYTICS_FORWARDING_KEY}` },
    body: JSON.stringify(event), redirect: 'manual', signal: AbortSignal.timeout(5000),
  });
  if (response.status !== 204) throw deliveryFailure(`http-${response.status}`);
}
export function backgroundEvent(event, env, ctx) {
  ctx.waitUntil(sendEvent(event, env).catch(error => console.error('Schnaps analytics delivery failed', failureCode(error))));
}
export function updaterMetadata(request) {
  const agent = request.headers.get('user-agent') ?? '';
  const legacy = /^Schnaps?(?:Debug[^/ ]*)?\/([^ ]+)\s+Sparkle\//.exec(agent);
  const explicit = request.headers.get('x-schnaps-client') === 'macos-updater';
  const version = explicit ? request.headers.get('x-schnaps-app-version') : legacy?.[1];
  return { isUpdater: explicit || !!legacy, version: versionPattern.test(version ?? '') ? version : 'unknown',
    runtime: (explicit ? request.headers.get('x-schnaps-runtime') === 'debug' : /Debug/.test(legacy?.[0] ?? '')) ? 'debug' : 'release' };
}
