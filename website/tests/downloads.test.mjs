import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorker } from '../src/worker.mjs';
const worker = createWorker(async () => new Response(null, { status: 302, headers: { location: 'https://github.com/gabriel/Schnaps/releases/download/v0.7.4/Schnaps.dmg' } }));

function context({ fail = false } = {}) {
  const writes = [], pending = [];
  return {
    writes, pending,
    env: {
      ASSETS: { fetch: async () => new Response('asset', { status: 404 }) },
      DOWNLOADS: {
        prepare: (sql) => ({ bind: (value) => ({ sql, value }) }),
        batch: async (statements) => { if (fail) throw new Error('unavailable'); writes.push(...statements); },
      },
    },
    ctx: { waitUntil: (promise) => pending.push(promise) },
  };
}

for (const [query, source] of [['?source=hero', 'hero'], ['?source=footer', 'footer'], ['?source=private-data&redirect=https://example.com', 'direct']]) {
  test(`download ${source}: fixed redirect and bounded aggregate data`, async () => {
    const c = context();
    const response = await worker.fetch(new Request(`https://getschnaps.com/download${query}`), c.env, c.ctx);
    await Promise.all(c.pending);
    assert.equal(response.status, 302);
    assert.equal(response.headers.get('Location'), `/updates/artifacts/v0.7.4/Schnaps-0.7.4.dmg?source=${source}`);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
    assert.equal(await response.text(), '');
    assert.equal(c.writes.length, 0); // Only the subsequent file transfer counts centrally.
  });
}

for (const options of [{ method: 'HEAD' }, { headers: { 'Sec-Purpose': 'prefetch;prerender' } }, { headers: { Purpose: 'prefetch' } }]) {
  test(`non-download request is not counted: ${JSON.stringify(options)}`, async () => {
    const c = context();
    const response = await worker.fetch(new Request('https://getschnaps.com/download', options), c.env, c.ctx);
    await Promise.all(c.pending);
    assert.equal(response.status, 302);
    assert.equal(c.writes.length, 0);
  });
}

test('analytics failure does not stop downloads', async () => {
  const c = context({ fail: true });
  const response = await worker.fetch(new Request('https://getschnaps.com/download'), c.env, c.ctx);
  await Promise.all(c.pending);
  assert.equal(response.status, 302);
});

test('no public stats API and no POST tracking', async () => {
  const c = context();
  for (const path of ['/stats', '/admin/downloads', '/api/downloads']) {
    assert.equal((await worker.fetch(new Request(`https://getschnaps.com${path}`), c.env, c.ctx)).status, 404);
  }
  const response = await worker.fetch(new Request('https://getschnaps.com/download', { method: 'POST' }), c.env, c.ctx);
  assert.equal(response.status, 405);
  assert.equal(c.writes.length, 0);
});
