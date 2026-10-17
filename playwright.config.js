import {defineConfig} from '@playwright/test';
export default defineConfig({
  testDir: './tests/site', testMatch: '*.spec.js', fullyParallel: false, workers: 1,
  timeout: 60000, expect: {timeout: 15000},
  reporter: [['list'], ['html', {open:'never'}]],
  use: {browserName:'chromium', viewport:{width:1440,height:1000}, screenshot:'only-on-failure', trace:'retain-on-failure'},
  projects: [
    {name:'root', use:{baseURL:'http://127.0.0.1:8765/'}},
    {name:'project-path', use:{baseURL:'http://127.0.0.1:8765/betydata/'}}
  ],
  webServer: {command:'node scripts/serve-site.mjs', url:'http://127.0.0.1:8765/', reuseExistingServer:!process.env.CI}
});
