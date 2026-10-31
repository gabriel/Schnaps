import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorker } from '../src/worker.mjs';
import { receiveLaunch, appID } from '../src/analytics.mjs';

function fixture() {
  const events = [], calls = [], pending = [];
  let status = 200;
  const fetcher = async (url, init = {}) => {
    calls.push({ url: String(url), init });
    if (url === 'https://rel.me/api/analytics/schnaps') {
      assert.equal(init.headers.authorization, 'Bearer test-only-key');
      assert.equal(init.redirect, 'manual');
      events.push(JSON.parse(init.body)); return new Response(null, { status: 204 });
    }
    return new Response(status === 304 || init.method === 'HEAD' ? null : 'signed bytes', { status, headers: { etag: '"signed"', 'content-range': status === 206 ? 'bytes 0-3/12' : '', 'content-type': 'application/octet-stream' } });
  };
  const env = { ANALYTICS: { fetch: fetcher }, ANALYTICS_FORWARDING_KEY: 'test-only-key', ASSETS: { fetch: async () => new Response('no', { status: 404 }) } };
  const worker = createWorker(fetcher), ctx = { waitUntil: promise => pending.push(promise) };
  return { events, calls, env, fetcher, setStatus: value => { status = value; }, async request(path, options) {
    const result = await worker.fetch(new Request('https://getschnaps.com' + path, options), env, ctx);
    await Promise.all(pending); return result;
  } };
}

test('signed feed bytes, conditional responses, and updater metadata survive the proxy', async () => {
  const f = fixture(), headers = { 'user-agent': 'Schnaps/0.7.4 Sparkle/2.10.1' };
  const feed = await f.request('/appcast.xml', { headers });
  assert.equal(await feed.text(), 'signed bytes');
  assert.equal(feed.headers.get('etag'), '"signed"');
  assert.equal(f.events[0].kind, 'check');
  assert.equal(f.events[0].version, '0.7.4');
  f.setStatus(304);
  assert.equal((await f.request('/appcast.xml', { headers: { ...headers, 'if-none-match': '"signed"' } })).status, 304);
  assert.equal(f.events.length, 2);
  await f.request('/appcast.xml'); // A browser/feed reader is not an updater check.
  assert.equal(f.events.length, 2);
  assert.equal(f.calls.filter(call => call.url.startsWith('https://github.com/')).at(-2).init.headers.get('if-none-match'), '"signed"');
});

test('first-party file starts distinguish website, direct, updater, Debug, and failed/HEAD requests', async () => {
  const f = fixture(), path = '/updates/artifacts/v0.7.4/Schnaps-0.7.4.dmg';
  assert.equal(await (await f.request(path + '?source=hero')).text(), 'signed bytes');
  await f.request(path);
  await f.request(path, { headers: { 'x-schnaps-client': 'macos-updater', 'x-schnaps-app-version': '0.7.3', 'x-schnaps-runtime': 'debug' } });
  await f.request(path, { method: 'HEAD' });
  await f.request(path, { headers: { purpose: 'prefetch' } });
  f.setStatus(404); await f.request(path);
  assert.deepEqual(f.events.map(event => [event.source, event.version, event.runtime]), [
    ['website', '0.7.4', 'release'], ['direct', '0.7.4', 'release'], ['updater', '0.7.4', 'debug'],
  ]);
  assert.equal((await f.request('/updates/artifacts/v0.7.3/Schnaps-0.7.4.dmg')).status, 404);
  assert.ok(f.calls.every(call => !call.url.includes('example.com')));
});

test('installation identity is hashed in the Schnaps namespace before authenticated forwarding', async () => {
  const f = fixture();
  const id = 'abcdef01-1234-4321-8321-123456789012';
  const request = () => new Request('https://getschnaps.com/api/app-starts', { method: 'POST', headers: {
    'content-type': 'application/json', 'x-schnaps-client': 'macos-app',
  }, body: JSON.stringify({ launchID: id, installationID: id, version: '0.7.4', build: '16', runtime: 'release' }) });
  assert.equal((await receiveLaunch(request(), f.env, f.fetcher)).status, 204);
  const event = f.events[0];
  assert.equal(event.installationID, undefined);
  assert.match(event.installationHash, /^[0-9a-f]{64}$/);
  const expected = Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${appID}:analytics:v1:release:${id}`))).toString('hex');
  assert.equal(event.installationHash, expected);
  assert.notEqual(event.installationHash, Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`me.rel.REL:analytics:v1:release:${id}`))).toString('hex'));
  assert.equal((await receiveLaunch(request(), {}, f.fetcher)).status, 503);
});

test('analytics outages do not block archive bytes or forward credentials to GitHub', async () => {
  const pending = [], observed = [];
  const fetcher = async (url, init = {}) => {
    observed.push({ url, init });
    if (url === 'https://rel.me/api/analytics/schnaps') return new Response('unavailable', { status: 503 });
    assert.equal(init.headers.get('authorization'), null);
    return new Response('archive bytes', { headers: { 'content-type': 'application/octet-stream' } });
  };
  const worker = createWorker(fetcher);
  const response = await worker.fetch(new Request('https://getschnaps.com/updates/artifacts/v0.7.4/Schnaps-0.7.4.dmg'),
    { ANALYTICS: { fetch: fetcher }, ANALYTICS_FORWARDING_KEY: 'test-only-key' }, { waitUntil: promise => pending.push(promise) });
  assert.equal(response.status, 200);
  assert.equal(await response.text(), 'archive bytes');
  await Promise.all(pending);
  assert.equal(observed.length, 2);
});

test('native input rejects non-string identities and versions before forwarding', async () => {
  const f = fixture();
  const id = 'abcdef01-1234-4321-8321-123456789012';
  for (const invalid of [{ launchID: [id] }, { installationID: [id] }, { version: ['0.7.4'] }]) {
    const body = JSON.stringify({ launchID: id, installationID: id, version: '0.7.4', build: '16', runtime: 'debug', ...invalid });
    const response = await receiveLaunch(new Request('https://getschnaps.com/api/app-starts', { method: 'POST', headers: { 'content-type': 'application/json', 'x-schnaps-client': 'macos-app' }, body }), f.env, f.fetcher);
    assert.equal(response.status, 400);
  }
  assert.equal(f.events.length, 0);
});

test('collector redirects are rejected without a second request', async () => {
  let calls = 0;
  const env = { ANALYTICS_FORWARDING_KEY: 'test-only-key', ANALYTICS: { fetch: async (_url, init) => {
    assert.equal(init.redirect, 'manual'); calls++;
    return new Response(null, { status: 302, headers: { location: 'https://outside.example' } });
  } } };
  const id = 'abcdef01-1234-4321-8321-123456789012';
  const response = await receiveLaunch(new Request('https://getschnaps.com/api/app-starts', { method: 'POST', headers: { 'content-type': 'application/json', 'x-schnaps-client': 'macos-app' }, body: JSON.stringify({ launchID: id, installationID: id, version: '0.7.4', build: '16', runtime: 'debug' }) }), env);
  assert.equal(response.status, 503); assert.equal(calls, 1);
});
