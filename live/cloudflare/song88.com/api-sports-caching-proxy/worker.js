const UPSTREAM = {
  football:    'https://v3.football.api-sports.io/',
  basketball:  'https://v1.basketball.api-sports.io/',
  baseball:    'https://v1.baseball.api-sports.io/',
  hockey:      'https://v1.hockey.api-sports.io/',
  handball:    'https://v1.handball.api-sports.io/',
  rugby:       'https://v1.rugby.api-sports.io/',
  volleyball:  'https://v1.volleyball.api-sports.io/',
  nba:         'https://v2.nba.api-sports.io/',
  afl:         'https://v1.afl.api-sports.io/',
  nfl:         'https://v1.american-football.api-sports.io/',
  mma:         'https://v1.mma.api-sports.io/',
  'formula-1': 'https://v1.formula-1.api-sports.io/',
};

const TTL_GAMES = 60;
const TTL_STATIC = 6 * 60 * 60;
const STALE_KEEP = 7 * 24 * 60 * 60;

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'x-apisports-key, content-type',
  'access-control-allow-methods': 'GET, OPTIONS',
};

const ttlFor = (endpoint) =>
  /^(games|fixtures)(\/|$)?/.test(endpoint) && !/h2h|headtohead/.test(endpoint)
    ? TTL_GAMES
    : TTL_STATIC;

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

    const url = new URL(request.url);
    const parts = url.pathname.split('/').filter(Boolean);
    const sport = parts[2];
    const endpoint = parts.slice(3).join('/');
    const upstreamBase = UPSTREAM[sport];
    if (!upstreamBase || !endpoint) {
      return json({ errors: { proxy: 'unknown sport or endpoint' } }, 404);
    }

    url.searchParams.sort();
    const cacheKey = new Request(
      `https://sports-cache.internal/${sport}/${endpoint}?${url.searchParams}`,
      { method: 'GET' }
    );
    const cache = caches.default;
    const ttl = ttlFor(endpoint);

    const cached = await cache.match(cacheKey);
    if (cached) {
      const age = (Date.now() - Number(cached.headers.get('x-cached-at') || 0)) / 1000;
      if (age < ttl) return withCors(cached);
    }

    let body = null;
    let ok = false;
    try {
      const upstream = new URL(upstreamBase + endpoint);
      upstream.search = url.search;
      const r = await fetch(upstream, { headers: { 'x-apisports-key': env.APISPORTS_KEY } });
      body = await r.json();
      const hasErrors = body?.errors && Object.keys(body.errors).length > 0;
      ok = r.ok && !hasErrors;
    } catch (err) {
      body = { errors: { proxy: String(err) } };
    }

    if (ok) {
      const toStore = new Response(JSON.stringify(body), {
        headers: {
          'content-type': 'application/json',
          'x-cached-at': String(Date.now()),
          'cache-control': `public, max-age=${STALE_KEEP}`,
        },
      });
      ctx.waitUntil(cache.put(cacheKey, toStore.clone()));
      return withCors(toStore);
    }

    if (cached) return withCors(cached);
    return json(body ?? { errors: { proxy: 'upstream failed' } }, 200);
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json', ...CORS },
  });
}

function withCors(res) {
  const r = new Response(res.body, res);
  for (const [k, v] of Object.entries(CORS)) r.headers.set(k, v);
  return r;
}
