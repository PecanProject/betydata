import {readdir, readFile, stat, access} from 'node:fs/promises';
import {resolve, dirname, extname} from 'node:path';
import {gzipSync} from 'node:zlib';
const root=resolve('_site');
async function files(directory) {
  const entries=await readdir(directory,{withFileTypes:true});
  return (await Promise.all(entries.map(e=>e.isDirectory()?files(resolve(directory,e.name)):[resolve(directory,e.name)]))).flat();
}
const all=await files(root);
let bytes=0;
const errors=[];
for(const file of all) {
  bytes+=(await stat(file)).size;
  if(extname(file)!=='.html')continue;
  const html=await readFile(file,'utf8');
  for(const match of html.matchAll(/\b(?:href|src)=["']([^"']+)["']/g)) {
    const href=match[1].replaceAll('&amp;','&');
    if(/^(?:[a-z][\w+.-]*:|\/\/|#)/i.test(href))continue;
    const pathname=decodeURIComponent(href.split(/[?#]/)[0]);
    if(!pathname)continue;
    const target=pathname.startsWith('/')?resolve(root,'.'+pathname):resolve(dirname(file),pathname);
    try {await access(target);}catch{errors.push(`${file.slice(root.length+1)} -> ${href}`);}
  }
}
const index=await readFile(resolve(root,'site-data/search-index.json'));
if(bytes>=100_000_000)errors.push('Published site exceeds the 100 MB project budget');
if(index.length>=10_000_000)errors.push('Search index exceeds the 10 MB budget');
console.log(JSON.stringify({siteBytes:bytes,indexBytes:index.length,indexGzipBytes:gzipSync(index).length,files:all.length},null,2));
if(errors.length)throw new Error(errors.join('\n'));
console.log('All rendered local links/resources exist.');
