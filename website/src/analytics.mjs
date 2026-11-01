export const appID = 'com.gabrielhandford.Schnap';
export const versionPattern = /^\d+\.\d+\.\d+(?:-beta\.[1-9]\d*)?$/;
function deliveryFailure(code) { const error = new Error('Analytics delivery failed'); error.analyticsCode = code; return error; }
function failureCode(error) { return /^(missing-key|missing-service|http-[0-9]{3})$/.test(error?.analyticsCode ?? '') ? error.analyticsCode : 'transport'; }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
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
export async function receiveLaunch(request, env) {
  const headers = { 'cache-control': 'no-store' };
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: { ...headers, allow: 'POST' } });
  if (request.headers.get('x-schnaps-client') !== 'macos-app' ||
      (request.headers.has('origin') && request.headers.get('origin') !== 'https://getschnaps.com')) return new Response('Forbidden', { status: 403, headers });
  if (env.LAUNCH_RATE_LIMITER && !(await env.LAUNCH_RATE_LIMITER.limit({ key: request.headers.get('cf-connecting-ip') ?? 'unknown' })).success) return new Response('Too many events', { status: 429, headers });
  if (!request.headers.get('content-type')?.startsWith('application/json')) return new Response('Send JSON', { status: 415, headers });
  const reader = request.body?.getReader();
  if (!reader) return new Response('Missing event', { status: 400, headers });
  let text = '', size = 0, event;
  const decoder = new TextDecoder();
  try {
    while (true) {
      const part = await reader.read(); if (part.done) break;
      size += part.value.byteLength;
      if (size > 512) { await reader.cancel(); return new Response('Event too large', { status: 413, headers }); }
      text += decoder.decode(part.value, { stream: true });
    }
    event = JSON.parse(text + decoder.decode());
  } catch { return new Response('Invalid JSON', { status: 400, headers }); }
  finally { reader.releaseLock(); }
  if (!event || typeof event.launchID !== 'string' || typeof event.installationID !== 'string' || typeof event.version !== 'string' ||
      !uuid.test(event.launchID) || !uuid.test(event.installationID) || !versionPattern.test(event.version) || typeof event.build !== 'string' || !/^[1-9]\d{0,14}$/.test(event.build) ||
      !Number.isSafeInteger(Number(event.build)) || !['release', 'debug'].includes(event.runtime)) return new Response('Invalid event', { status: 400, headers });
  const input = `${appID}:analytics:v1:${event.runtime}:${event.installationID.toLowerCase()}`;
  if (event.runtime === 'debug' || excludesAnalytics(request)) return new Response(null, { status: 204, headers });
  const installationHash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))), b => b.toString(16).padStart(2, '0')).join('');
  try {
    await sendEvent({ kind: 'launch', launchID: event.launchID, runtime: event.runtime, version: event.version, build: event.build, installationHash }, env);
    return new Response(null, { status: 204, headers });
  } catch (error) { console.error('Schnaps launch analytics unavailable', failureCode(error)); return new Response('Analytics unavailable', { status: 503, headers }); }
}
