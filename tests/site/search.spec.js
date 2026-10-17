import {test, expect} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import {readFile} from 'node:fs/promises';
import {prepareIndex, searchIndex} from '../../site-assets/js/search-core.js';
const raw = JSON.parse(await readFile('site-data/search-index.json', 'utf8'));
const prepared = prepareIndex(raw);
const submit = async page => page.getByRole('button', {name:'Search data', exact:true}).click();
const ready = async page => expect(page.locator('#search-status')).toContainText('found.');

test('home actions, no eager data, search submission and download', async ({page, baseURL}) => {
  const dataRequests = [];
  page.on('request', req => { if (/site-data\/(search-index|observations)/.test(req.url())) dataRequests.push(req.url()); });
  await page.goto(baseURL);
  for (const action of ['Access data','Explore data','Download data','Add data','Use the R package','Report corrections']) {
    await expect(page.getByRole('link',{name:action,exact:true}).first()).toBeVisible();
  }
  expect(dataRequests).toEqual([]);
  await page.locator('form input[name=query]').fill('photosynthesis');
  await page.locator('form button[type=submit]').click();
  await ready(page);
  expect(page.url()).toContain('search.html?query=photosynthesis');
  await expect(page.locator('#observation-total')).toHaveText(searchIndex(prepared,{query:'photosynthesis'}).observations.length.toLocaleString());
  expect(dataRequests).toHaveLength(1);
  expect(dataRequests[0]).toBe(new URL('site-data/search-index.json',baseURL).href);
  const download = page.waitForEvent('download');
  await page.getByRole('link',{name:'Download all public observations (CSV)',exact:true}).click();
  expect((await download).suggestedFilename()).toBe('observations.csv');
});

test('blank, combined filters, pagination, history, and cached requests', async ({page,baseURL}) => {
  let requests=0;
  page.on('request', req => {if(req.url().endsWith('/search-index.json')) requests++;});
  await page.goto(new URL('search.html',baseURL).href);
  await expect(page.locator('#search-results')).toBeHidden();
  await submit(page);
  await expect(page.locator('#search-status')).toContainText('Enter a keyword');
  expect(requests).toBe(0);
  await page.locator('#variable').fill('yield');
  await page.locator('#species').fill('Panicum');
  await submit(page); await ready(page);
  const result=searchIndex(prepared,{variable:'yield',species:'Panicum'});
  await expect(page.locator('#observation-total')).toHaveText(result.observations.length.toLocaleString());
  await expect(page.locator('#observation-body tr')).toHaveCount(25);
  await page.locator('#observation-next').click();
  await expect(page.locator('#observation-page')).toContainText('Page 2');
  await page.locator('#author').fill('no-such-author-xyz'); await submit(page); await ready(page);
  await expect(page.locator('#observation-empty')).toBeVisible();
  await expect(page.locator('#variable-body tr')).not.toHaveCount(0);
  await page.goBack(); await ready(page);
  await expect(page.locator('#author')).toHaveValue('');
  await expect(page.locator('#observation-page')).toContainText('Page 1');
  await page.goForward(); await ready(page);
  await expect(page.locator('#author')).toHaveValue('no-such-author-xyz');
  expect(requests).toBe(1);
});

for (const failure of ['missing','corrupt','offline']) {
  test(`${failure} index reports error and retries`, async ({page,baseURL}) => {
    await page.route('**/site-data/search-index.json', route => failure==='offline' ? route.abort('internetdisconnected') :
      route.fulfill({status:failure==='missing'?404:200,contentType:'application/json',body:'{"version":999}'}));
    await page.goto(new URL('search.html?query=photosynthesis',baseURL).href);
    await expect(page.locator('#search-retry')).toBeVisible();
    await expect(page.locator('#search-results')).toBeHidden();
    await page.unroute('**/site-data/search-index.json');
    await page.locator('#search-retry').click(); await ready(page);
  });
}

test('latest submission wins while index is in flight', async ({page,baseURL}) => {
  let release;
  const gate = new Promise(resolve => { release=resolve; });
  await page.route('**/site-data/search-index.json', async route => {await gate; await route.continue();});
  await page.goto(new URL('search.html?query=photosynthesis',baseURL).href);
  await page.locator('#query').fill('nonexistentword-xyz'); await submit(page);
  release(); await ready(page);
  await expect(page.locator('#observation-total')).toHaveText('0');
  await expect(page.locator('#variable-total')).toHaveText('0');
});

test('HTML-like content stays text; duplicate definitions have explicit shared counts', async ({page,baseURL}) => {
  const data={version:1,columns:raw.columns,rows:[['traits',1,'<img src=x onerror=alert(1)>','desc',1,'m','plant',null,'author',2020,null,0]],
    variables:[1,2].map(id=>({id,name:'<img src=x onerror=alert(1)>',description:'desc',units:'m'}))};
  await page.route('**/site-data/search-index.json',route=>route.fulfill({json:data}));
  await page.goto(new URL('search.html?query=desc',baseURL).href); await ready(page);
  await expect(page.locator('#observation-body img')).toHaveCount(0);
  await expect(page.locator('#observation-body')).toContainText('<img');
  await expect(page.locator('#variable-body tr')).toHaveCount(2);
  await expect(page.locator('#variable-body')).toContainText('1 (shared name)');
});

test('accessibility, keyboard, mobile and zoomed layouts', async ({page,baseURL},testInfo) => {
  for (const path of ['index.html','access.html','contribute.html','about.html','search.html','search.html?query=photosynthesis']) {
    await page.goto(new URL(path,baseURL).href);
    if(path.includes('?')) await ready(page);
    const scan=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
    expect(scan.violations, JSON.stringify(scan.violations,null,2)).toEqual([]);
  }
  await page.locator('#query').focus(); await page.locator('#query').fill('yield'); await page.keyboard.press('Enter'); await ready(page);
  await expect(page.locator('#query')).toBeFocused();
  for(const viewport of [{width:375,height:812},{width:720,height:500}]) {
    await page.setViewportSize(viewport);
    expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth+1)).toBe(true);
  }
  await page.setViewportSize({width:1440,height:1000});
  await page.evaluate(()=>{document.documentElement.style.zoom='2';});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth+1)).toBe(true);
  await page.evaluate(()=>{document.documentElement.style.zoom='';});
  await page.setViewportSize({width:375,height:812});
  await page.screenshot({path:testInfo.outputPath('search-mobile.png'),fullPage:true});
  await page.setViewportSize({width:1440,height:1000});
  await page.goto(baseURL); await page.screenshot({path:testInfo.outputPath('homepage-desktop.png'),fullPage:true});
  await page.setViewportSize({width:375,height:812});
  await page.screenshot({path:testInfo.outputPath('homepage-mobile.png'),fullPage:true});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth+1)).toBe(true);
});

test('CSV route and guidance remain usable without JavaScript', async ({browser,baseURL}) => {
  const context=await browser.newContext({javaScriptEnabled:false});const page=await context.newPage();
  await page.goto(new URL('search.html',baseURL).href);
  await expect(page.locator('noscript p')).toBeVisible();
  await expect(page.locator('noscript p')).toContainText('Interactive search requires JavaScript.');
  const response=await context.request.get(new URL('site-data/observations.csv',baseURL).href);
  expect(response.status()).toBe(200);expect((await response.text()).split('\n')[0]).toContain('result_type');
  await context.close();
});

test('performance budget at four-times CPU throttling', async ({page,baseURL},testInfo) => {
  const cdp=await page.context().newCDPSession(page);await cdp.send('Emulation.setCPUThrottlingRate',{rate:4});
  const start=Date.now();await page.goto(new URL('search.html?query=photosynthesis',baseURL).href);await ready(page);
  const firstSearchMs=Date.now()-start;
  const measurements=await page.evaluate(async base=>{
    const {prepareIndex,searchIndex}=await import(new URL('site-assets/js/search-core.js',base));
    const data=await (await fetch(new URL('site-data/search-index.json',base))).json();const index=prepareIndex(data);
    const times=[];for(const q of ['yield','photosynthesis','switchgrass','smith','leaf area']){
      const t=performance.now();searchIndex(index,{query:q});times.push(performance.now()-t);
    }return times;
  },baseURL);
  await testInfo.attach('performance',{body:JSON.stringify({firstSearchMs,cachedSearchMs:measurements,cpuThrottle:4,network:'local HTTP, uncompressed'},null,2),contentType:'application/json'});
  expect(Math.max(...measurements)).toBeLessThan(200);
});
