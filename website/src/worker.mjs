import { backgroundEvent, receiveLaunch, updaterMetadata, versionPattern } from './analytics.mjs';
const feedURL = 'https://github.com/gabriel/Schnaps/releases/download/updates/appcast.xml';
const upstreamBase = 'https://github.com/gabriel/Schnaps/releases/download/';
const isPrefetch = request => /prefetch|prerender/i.test(`${request.headers.get('Sec-Purpose') ?? ''} ${request.headers.get('Purpose') ?? ''}`);
const startsTransfer = (request, response) => request.method === 'GET' && !isPrefetch(request) &&
  (response.status === 200 || (response.status === 206 && /^bytes 0-/.test(response.headers.get('content-range') ?? '')));

export function createWorker(fetcher = fetch) {
  return { async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/api/app-starts') return receiveLaunch(request, env);
    if (url.pathname === '/download') {
      if (!['GET', 'HEAD'].includes(request.method)) return new Response('Method not allowed', { status: 405, headers: { allow: 'GET, HEAD' } });
      try {
        const release = await fetcher('https://github.com/gabriel/Schnaps/releases/latest/download/Schnaps.dmg', {
          method: 'HEAD', redirect: 'manual', cf: { cacheTtl: 300, cacheEverything: true },
        });
        const location = release.headers.get('location') ?? '';
        const latest = /^https:\/\/github\.com\/gabriel\/Schnaps\/releases\/download\/(v?\d+\.\d+\.\d+)\/Schnaps\.dmg$/.exec(location);
        if (release.status !== 302 || !latest) throw new Error('Release unavailable');
        const tag = latest[1], version = tag.replace(/^v/, '');
        const source = ['hero', 'footer'].includes(url.searchParams.get('source')) ? url.searchParams.get('source') : 'direct';
        return new Response(null, { status: 302, headers: { location: `/updates/artifacts/${tag}/Schnaps-${version}.dmg?source=${source}`, 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' } });
      } catch { return new Response('Download temporarily unavailable', { status: 503, headers: { 'cache-control': 'no-store' } }); }
    }
    const artifact = /^\/updates\/artifacts\/(v?\d+\.\d+\.\d+(?:-beta\.\d+)?)\/(Schnaps-(\d+\.\d+\.\d+(?:-beta\.\d+)?)\.(dmg|delta))$/.exec(url.pathname);
    const feed = url.pathname === '/appcast.xml';
    if (!feed && !artifact) {
      if (url.pathname.startsWith('/updates/')) return new Response('Not found', { status: 404 });
      return env.ASSETS.fetch(request);
    }
    if (!['GET', 'HEAD'].includes(request.method)) return new Response('Method not allowed', { status: 405, headers: { allow: 'GET, HEAD' } });
    if (artifact && artifact[1].replace(/^v/, '') !== artifact[3]) return new Response('Not found', { status: 404 });
    const forwarded = new Headers();
    for (const name of ['range', 'if-none-match', 'if-modified-since', 'if-range']) if (request.headers.has(name)) forwarded.set(name, request.headers.get(name));
    let upstream;
    try { upstream = await fetcher(feed ? feedURL : upstreamBase + artifact[1] + '/' + artifact[2], { method: request.method, headers: forwarded, redirect: 'follow' }); }
    catch { return new Response('Release service unavailable', { status: 502 }); }
    const headers = new Headers();
    for (const name of ['content-type', 'etag', 'last-modified', 'content-range', 'accept-ranges']) if (upstream.headers.has(name)) headers.set(name, upstream.headers.get(name));
    headers.set('cache-control', feed ? 'public, max-age=0, must-revalidate' : 'public, max-age=31536000, immutable');
    headers.set('x-content-type-options', 'nosniff');
    if (artifact && upstream.headers.has('content-length') && !upstream.headers.has('content-encoding')) headers.set('content-length', upstream.headers.get('content-length'));
    if (artifact) headers.set('content-disposition', `attachment; filename="${artifact[2]}"`);
    const response = new Response(request.method === 'HEAD' ? null : upstream.body, { status: upstream.status, headers });
    const updater = updaterMetadata(request);
    if (feed && updater.isUpdater && request.method === 'GET' && [200, 304].includes(response.status)) {
      backgroundEvent({ kind: 'check', eventID: crypto.randomUUID(), runtime: updater.runtime, version: updater.version }, env, ctx);
    } else if (artifact && startsTransfer(request, response)) {
      let website = ['hero', 'footer', 'website'].includes(url.searchParams.get('source'));
      try { website ||= new URL(request.headers.get('referer') ?? '').origin === 'https://getschnaps.com'; } catch { /* unattributed */ }
      backgroundEvent({ kind: 'transfer', eventID: crypto.randomUUID(), runtime: updater.runtime, version: artifact[3], artifact: artifact[4],
        source: updater.isUpdater || artifact[4] === 'delta' ? 'updater' : website ? 'website' : 'direct' }, env, ctx);
    }
    return response;
  } };
}
export default createWorker();
