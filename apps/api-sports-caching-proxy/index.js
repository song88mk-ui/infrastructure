import http from 'node:http';
import Redis from 'ioredis';
import sql from 'mssql';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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

const ZH_JSON     = path.join(path.dirname(fileURLToPath(import.meta.url)), 'zh.json');
const TABLE       = process.env.MSSQL_TABLE || 'dbo.SportsApiTranslationCache';
const TARGET_COL  = process.env.MSSQL_TARGET_COL || 'target_text_zh';
const RELOAD_MS   = Number(process.env.RELOAD_MS || 5 * 60 * 1000);
const FLUSH_MS    = Number(process.env.FLUSH_MS || 15 * 60 * 1000);
const DEEPL_KEY   = process.env.DEEPL_KEY || '';
const DEEPL_GLOSSARY_ID = process.env.DEEPL_GLOSSARY_ID || '';
const DEEPL_HOST  = process.env.DEEPL_HOST ||
  (DEEPL_KEY.endsWith(':fx') ? 'https://api-free.deepl.com' : 'https://api.deepl.com');

const dbConfig = {
  server:   process.env.MSSQL_HOST || 'localhost',
  port:     Number(process.env.MSSQL_PORT || 1433),
  user:     process.env.MSSQL_USER,
  password: process.env.MSSQL_PASSWORD,
  database: process.env.MSSQL_DB || 'Translation',
  options:  { encrypt: true, trustServerCertificate: true },
  pool:     { max: 5, min: 0, idleTimeoutMillis: 30000 },
};

let glossary = {};
let pool = null;

async function loadGlossary() {
  if (!pool) pool = await sql.connect(dbConfig);
  const r = await pool.request()
    .query(`SELECT source_text, ${TARGET_COL} AS t FROM ${TABLE} WHERE source_lang='EN' AND ${TARGET_COL} <> N''`);
  const g = {};
  for (const row of r.recordset) g[row.source_text] = row.t;
  glossary = g;
  return r.recordset.length;
}

async function upsert(source, target) {
  if (!pool) return;
  await pool.request()
    .input('s', sql.NVarChar(250), source)
    .input('t', sql.NVarChar(250), target)
    .query(`IF EXISTS (SELECT 1 FROM ${TABLE} WHERE source_text=@s AND source_lang='EN')
              UPDATE ${TABLE} SET ${TARGET_COL}=@t, updated_at=SYSUTCDATETIME() WHERE source_text=@s AND source_lang='EN';
            ELSE
              INSERT INTO ${TABLE} (source_lang, source_text, ${TARGET_COL}) VALUES ('EN', @s, @t);`);
}

const misses = new Set();

function translate(node) {
  if (Array.isArray(node)) return node.forEach(translate);
  if (!node || typeof node !== 'object') return;
  for (const k of Object.keys(node)) {
    const v = node[k];
    if ((k === 'team' || k === 'home' || k === 'away' || k === 'league' || k === 'country') &&
        v && typeof v === 'object' && typeof v.name === 'string') {
      if (glossary[v.name]) v.name = glossary[v.name]; else misses.add(v.name);
    }
    if (k === 'country' && typeof v === 'string' && v) {
      if (glossary[v]) node[k] = glossary[v]; else misses.add(v);
    }
    if (v && typeof v === 'object') translate(v);
  }
}

async function deeplBatch(texts) {
  const body = new URLSearchParams();
  body.set('source_lang', 'EN');
  body.set('target_lang', 'ZH');
  if (DEEPL_GLOSSARY_ID) body.set('glossary_id', DEEPL_GLOSSARY_ID);
  for (const t of texts) body.append('text', t);
  const r = await fetch(`${DEEPL_HOST}/v2/translate`, {
    method: 'POST',
    headers: { Authorization: `DeepL-Auth-Key ${DEEPL_KEY}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!r.ok) throw new Error(`DeepL ${r.status}: ${await r.text()}`);
  return (await r.json()).translations.map((t) => t.text);
}

let flushing = false;
async function flushMisses() {
  if (flushing || !DEEPL_KEY || !pool || misses.size === 0) return;
  flushing = true;
  const names = [...misses];
  misses.clear();
  try {
    for (let i = 0; i < names.length; i += 50) {
      const chunk = names.slice(i, i + 50);
      const out = await deeplBatch(chunk);
      for (let j = 0; j < chunk.length; j++) {
        const en = chunk[j], zh = out[j] || chunk[j];
        glossary[en] = zh;
        try { await upsert(en, zh); } catch (e) { console.warn(`upsert failed for "${en}": ${e.message}`); }
      }
    }
  } catch (e) {
    console.warn('deepl flush failed:', e.message);
    names.forEach((n) => misses.add(n));
  } finally {
    flushing = false;
  }
}

function sendJson(res, obj, status = 200) {
  const payload = JSON.stringify(obj);
  res.writeHead(status, {
    'content-type': 'application/json',
    'content-length': Buffer.byteLength(payload),
    ...CORS,
  });
  res.end(payload);
}

function sendData(res, body, lang, endpoint, status = 200) {
  if (lang === 'zh' && body && typeof body === 'object' && body.response) {
    body = JSON.parse(JSON.stringify(body));
    translate(body.response);
    if (Array.isArray(body.response) && /^(leagues|teams)(\/|$|\?)/.test(endpoint + '/')) {
      for (const item of body.response) {
        if (item && typeof item.name === 'string') {
          if (glossary[item.name]) item.name = glossary[item.name]; else misses.add(item.name);
        }
      }
    }
  }
  sendJson(res, body, status);
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

  if (url.pathname === '/zh.json') {
    try {
      const buf = await readFile(ZH_JSON);
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', ...CORS });
      return res.end(buf);
    } catch {
      res.writeHead(404, CORS);
      return res.end('{}');
    }
  }

  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS);
    return res.end();
  }
  if (req.method !== 'GET') {
    return sendJson(res, { errors: { proxy: 'method not allowed' } }, 405);
  }

  let lang = 'en';
  if (url.pathname.startsWith('/zh/')) {
    lang = 'zh';
    url.pathname = url.pathname.slice(3);
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
    if (age < ttl) return sendData(res, cached.body, lang, endpoint);
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
    return sendData(res, body, lang, endpoint);
  }

  if (cached) return sendData(res, cached.body, lang, endpoint); // serve stale
  return sendData(res, body ?? { errors: { proxy: 'upstream failed' } }, lang, endpoint);
});

server.listen(PORT, () => console.log(`listening on :${PORT}`));

loadGlossary()
  .then((n) => console.log(`glossary loaded: ${n} entries`))
  .catch((e) => console.warn('glossary load failed (serving untranslated):', e.message));
if (RELOAD_MS > 0) {
  setInterval(() => loadGlossary().catch((e) => console.warn('glossary reload failed:', e.message)), RELOAD_MS);
}
if (DEEPL_KEY) {
  setInterval(flushMisses, FLUSH_MS);
} else {
  console.log('deepl auto-fill off (no DEEPL_KEY) — missing names stay English');
}

// Graceful shutdown so k8s rolling updates don't drop in-flight requests
function shutdown() {
  server.close(() => {
    Promise.allSettled([redis.quit(), pool?.close()]).finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
