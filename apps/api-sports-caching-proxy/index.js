import http from 'node:http';
import Redis from 'ioredis';

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

const BLOCKED = new Set(['status']);

const TTL_GAMES  = 60;
const TTL_STATIC = 6 * 60 * 60;
const STALE_KEEP = 7 * 24 * 60 * 60;

const CORS = {
  'access-control-allow-origin':  '*',
  'access-control-allow-headers': 'x-apisports-key, content-type',
  'access-control-allow-methods': 'GET, OPTIONS',
};

const PORT           = Number(process.env.PORT || 8080);
const APISPORTS_KEY  = process.env.APISPORTS_KEY;
const REDIS_URL      = process.env.REDIS_URL || 'redis://localhost:6379';

if (!APISPORTS_KEY) {
  console.error('APISPORTS_KEY is required');
  process.exit(1);
}

const redis = new Redis(REDIS_URL, {
  maxRetriesPerRequest: 2,
  enableOfflineQueue: false, // fail fast instead of blocking requests when Redis is down
});
redis.on('error', (e) => console.error('redis error:', e.message));

const ttlFor = (endpoint) =>
  /^(games|fixtures)(\/|$)?/.test(endpoint) && !/h2h|headtohead/.test(endpoint)
    ? TTL_GAMES
    : TTL_STATIC;

function sendJson(res, obj, status = 200) {
  const payload = JSON.stringify(obj);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(payload),
    ...CORS,
  });
  res.end(payload);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  // Health/readiness endpoints for kubelet probes
  if (url.pathname === '/healthz') {
    res.writeHead(200, { 'content-type': 'text/plain' });
    return res.end('ok');
  }
  if (url.pathname === '/readyz') {
    try {
      await redis.ping();
      res.writeHead(200, { 'content-type': 'text/plain' });
      return res.end('ready');
    } catch {
      res.writeHead(503, { 'content-type': 'text/plain' });
      return res.end('redis unavailable');
    }
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS);
    return res.end();
  }
  if (req.method !== 'GET') {
    return sendJson(res, { errors: { proxy: 'method not allowed' } }, 405);
  }

  // NOTE: sport is parts[2], so two path segments are skipped before it,
  // matching the original Worker (e.g. /api/v1/<sport>/<endpoint>).
  const parts = url.pathname.split('/').filter(Boolean);
  const sport = parts[2];
  const endpoint = parts.slice(3).join('/');
  const upstreamBase = UPSTREAM[sport];
  if (!upstreamBase || !endpoint) {
    return sendJson(res, { errors: { proxy: 'unknown sport or endpoint' } }, 404);
  }
  if (BLOCKED.has(parts[3])) {
    return sendJson(res, { errors: { proxy: 'endpoint not available' } }, 404);
  }

  url.searchParams.sort();
  const cacheKey = `sports-cache:${sport}/${endpoint}?${url.searchParams.toString()}`;
  const ttl = ttlFor(endpoint);

  // Read cache once; keep it around so we can serve it stale if upstream fails.
  let cached = null;
  try {
    const raw = await redis.get(cacheKey);
    if (raw) cached = JSON.parse(raw);
  } catch {
    /* Redis unreachable — fall through to upstream */
  }

  if (cached) {
    const age = (Date.now() - Number(cached.cachedAt || 0)) / 1000;
    if (age < ttl) return sendJson(res, cached.body, 200);
  }

  let body = null;
  let ok = false;
  try {
    const upstream = new URL(upstreamBase + endpoint);
    upstream.search = url.search;
    const r = await fetch(upstream, { headers: { 'x-apisports-key': APISPORTS_KEY } });
    body = await r.json();
    const hasErrors = body?.errors && Object.keys(body.errors).length > 0;
    ok = r.ok && !hasErrors;
  } catch (err) {
    body = { errors: { proxy: String(err) } };
  }

  if (ok) {
    const entry = JSON.stringify({ cachedAt: Date.now(), body });
    // Fire-and-forget, like ctx.waitUntil(). Key TTL = STALE_KEEP replaces
    // the Worker's `cache-control: max-age` retention hint.
    redis.set(cacheKey, entry, 'EX', STALE_KEEP).catch(() => {});
    return sendJson(res, body, 200);
  }

  if (cached) return sendJson(res, cached.body, 200); // serve stale
  return sendJson(res, body ?? { errors: { proxy: 'upstream failed' } }, 200);
});

server.listen(PORT, () => console.log(`listening on :${PORT}`));

// Graceful shutdown so k8s rolling updates don't drop in-flight requests
function shutdown() {
  server.close(() => redis.quit().finally(() => process.exit(0)));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
