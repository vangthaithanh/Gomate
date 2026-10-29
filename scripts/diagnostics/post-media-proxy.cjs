// Local, streaming measurement only. No headers/body/URLs are written to logs.
const http = require('node:http');
const { Transform, pipeline } = require('node:stream');
const agent = new http.Agent({ keepAlive: true, maxSockets: 64 });
const totals = new Map();
let phase = 'cold';
function classify(req) {
  const path = new URL(req.url, 'http://localhost').pathname;
  let m = /^\/api\/v1\/posts\/(\d+)\/media\/([0-9a-f-]{36})(\/thumbnail)?$/i.exec(path);
  if (m) return { key: `post:${m[1]}:${m[2]}:${m[3] ? 'thumbnail' : 'original'}`, kind: m[3] ? 'thumbnail' : req.headers.range ? 'range' : 'original' };
  if (path === '/api/v1/feed') return { key: 'feed', kind: 'feed' };
  m = /^\/api\/v1\/posts\/(\d+)$/.exec(path);
  return m ? { key: `post:${m[1]}`, kind: 'detail' } : null;
}
const server = http.createServer((req, res) => {
  const local = new URL(req.url, 'http://localhost');
  if (local.pathname === '/__stats') {
    if (req.method === 'POST') phase = (local.searchParams.get('phase') || 'phase').replace(/[^a-zA-Z0-9_-]/g, '').slice(0,40);
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    return res.end(JSON.stringify({ phase, rows: [...totals.values()] }));
  }
  const metric = classify(req); const start = Date.now(); const currentPhase = phase;
  const upstream = http.request({ hostname: '127.0.0.1', port: 8081, path: req.url, method: req.method, agent, headers: { ...req.headers, host: '127.0.0.1:8081' } }, source => {
    res.writeHead(source.statusCode, source.headers);
    let bytes = 0; let finished = false;
    const meter = new Transform({ transform(chunk, _, cb) { bytes += chunk.length; cb(null, chunk); } });
    const record = () => {
      if (finished || !metric) return; finished = true;
      const k = `${currentPhase}:${metric.kind}:${metric.key}`;
      const row = totals.get(k) || { phase: currentPhase, ...metric, requests: 0, bytes: 0, statuses: {} };
      row.requests++; row.bytes += bytes; row.statuses[source.statusCode] = (row.statuses[source.statusCode] || 0) + 1; totals.set(k,row);
      const range = /^bytes=\d*-\d*$/.test(req.headers.range || '') ? req.headers.range : null;
      console.log(JSON.stringify({ time: new Date().toISOString(), phase: currentPhase, ...metric, status: source.statusCode, bytes, range, ms: Date.now()-start }));
    };
    pipeline(source,meter,res,record);
  });
  upstream.on('error', () => { if(!res.headersSent) res.writeHead(502); res.end(); });
  req.on('aborted', () => upstream.destroy());
  res.on('close', () => { if(!res.writableFinished) upstream.destroy(); });
  req.pipe(upstream);
});
server.listen(18094,'127.0.0.1',()=>console.log('Post media diagnostic proxy ready on loopback 18094'));
process.on('SIGTERM',()=>{server.close();agent.destroy();});
