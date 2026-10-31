const downloadURL = 'https://github.com/gabriel/Schnaps/releases/latest/download/Schnaps.dmg';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/download') return env.ASSETS.fetch(request);
    if (!['GET', 'HEAD'].includes(request.method)) {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }

    // Count starts, not completed transfers or unique people. No visitor data is stored.
    const purpose = `${request.headers.get('Sec-Purpose') ?? ''} ${request.headers.get('Purpose') ?? ''}`;
    if (request.method === 'GET' && !/prefetch|prerender/i.test(purpose)) {
      const source = ['hero', 'footer'].includes(url.searchParams.get('source')) ? url.searchParams.get('source') : 'direct';
      const day = new Date().toISOString().slice(0, 10);
      ctx.waitUntil(Promise.resolve().then(() => env.DOWNLOADS.batch([
        env.DOWNLOADS.prepare('INSERT INTO download_totals (source, downloads) VALUES (?, 1) ON CONFLICT(source) DO UPDATE SET downloads = downloads + 1').bind('all'),
        env.DOWNLOADS.prepare('INSERT INTO download_totals (source, downloads) VALUES (?, 1) ON CONFLICT(source) DO UPDATE SET downloads = downloads + 1').bind(source),
        env.DOWNLOADS.prepare('INSERT INTO download_daily (day, downloads) VALUES (?, 1) ON CONFLICT(day) DO UPDATE SET downloads = downloads + 1').bind(day),
      ])).catch(() => { console.error('Download count write failed'); }));
    }
    // Always let the download continue, even if analytics is unavailable.
    return new Response(null, { status: 302, headers: {
      Location: downloadURL,
      'Cache-Control': 'no-store',
      'X-Robots-Tag': 'noindex, nofollow',
      'Referrer-Policy': 'no-referrer',
    } });
  },
};
