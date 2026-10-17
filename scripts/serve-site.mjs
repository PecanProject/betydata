// Test server: the same built site is served at / and /betydata/.
import {createServer} from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import {resolve, extname, sep} from 'node:path';
const root = resolve('_site');
const mime = {'.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.json':'application/json',
  '.csv':'text/csv', '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.woff2':'font/woff2'};
createServer(async (request, response) => {
  try {
    let path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (path.startsWith('/betydata/')) path = path.slice('/betydata'.length);
    if (path.endsWith('/')) path += 'index.html';
    const file = resolve(root, '.' + path);
    if (!file.startsWith(root + sep) || !(await stat(file)).isFile()) throw new Error('not found');
    response.writeHead(200, {'Content-Type':mime[extname(file)] ?? 'application/octet-stream', 'Cache-Control':'no-store'});
    response.end(await readFile(file));
  } catch { response.writeHead(404); response.end('Not found'); }
}).listen(8765, '127.0.0.1');
