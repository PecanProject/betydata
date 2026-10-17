import {prepareIndex, searchIndex, hasQuery, paginate} from './search-core.js';

const form = document.querySelector('#data-search');
const status = document.querySelector('#search-status');
const results = document.querySelector('#search-results');
const retry = document.querySelector('#search-retry');
const keys = ['query', 'variable', 'species', 'author'];
let cached, pending, generation = 0, found;
let observationPage = 1, variablePage = 1;

function filtersFromURL() {
  const parameters = new URLSearchParams(location.search);
  return Object.fromEntries(keys.map(key => [key, parameters.get(key) ?? '']));
}
function fill(filters) { keys.forEach(key => { form.elements[key].value = filters[key]; }); }
function announce(message) { status.textContent = message; }
function cell(row, value) {
  const td = document.createElement('td');
  td.textContent = value === null || value === undefined || value === '' ? '—' : String(value);
  row.append(td);
  return td;
}
function pager(kind, pagination, render) {
  document.querySelector(`#${kind}-page`).textContent = `Page ${pagination.page} of ${pagination.pages}`;
  for (const [direction, delta] of [['previous', -1], ['next', 1]]) {
    const button = document.querySelector(`#${kind}-${direction}`);
    button.disabled = delta < 0 ? pagination.page === 1 : pagination.page === pagination.pages;
    button.onclick = () => {
      if (kind === 'observation') observationPage += delta;
      else variablePage += delta;
      render();
      announce(`${kind === 'observation' ? 'Observations' : 'Variable definitions'}: page ${pagination.page + delta} of ${pagination.pages}.`);
      // Keep keyboard focus on the pager, even when the clicked button becomes disabled.
      document.querySelector(`#${kind}-page`).focus();
    };
  }
}
function renderObservations() {
  const pagination = paginate(found.observations, observationPage, 25);
  const body = document.querySelector('#observation-body');
  body.replaceChildren();
  for (const observation of pagination.rows) {
    const row = document.createElement('tr');
    for (const index of [2, 4, 5, 6, 7, 8, 9, 10]) cell(row, observation[index]);
    cell(row, observation[11] === 1 ? 'Verified' : 'Unchecked');
    const link = document.createElement('a');
    link.textContent = `${observation[0]}:${observation[1]}`;
    const url = new URL('https://github.com/PecanProject/betydata/issues/new');
    url.searchParams.set('template', 'data_correction.md');
    url.searchParams.set('title', `Data correction: ${link.textContent}`);
    link.href = url.href;
    link.setAttribute('aria-label', `Report correction for ${link.textContent}`);
    const td = cell(row, ''); td.replaceChildren(link);
    body.append(row);
  }
  document.querySelector('#observation-empty').hidden = found.observations.length !== 0;
  document.querySelector('#observations').hidden = found.observations.length === 0;
  pager('observation', pagination, renderObservations);
}
function renderVariables() {
  const pagination = paginate(found.variables, variablePage, 10);
  const body = document.querySelector('#variable-body');
  body.replaceChildren();
  for (const variable of pagination.rows) {
    const row = document.createElement('tr');
    for (const value of [variable.id, variable.name, variable.description, variable.units]) cell(row, value);
    cell(row, `${variable.count.toLocaleString()}${variable.shared ? ' (shared name)' : ''}`);
    body.append(row);
  }
  document.querySelector('#variable-empty').hidden = found.variables.length !== 0;
  document.querySelector('#definitions').hidden = found.variables.length === 0;
  pager('variable', pagination, renderVariables);
}
async function loadIndex() {
  if (cached) return cached;
  if (!pending) {
    pending = (async () => {
      const response = await fetch(new URL('../../site-data/search-index.json', import.meta.url));
      if (!response.ok) throw new Error('Index download failed');
      const prepared = prepareIndex(await response.json());
      cached = prepared;
      return prepared;
    })().finally(() => { pending = undefined; });
  }
  return pending;
}
async function execute(filters) {
  const current = ++generation;
  retry.hidden = true;
  results.hidden = true;
  if (!hasQuery(filters)) {
    results.removeAttribute('aria-busy');
    announce('Enter a keyword or at least one filter to search.');
    return;
  }
  announce('Loading and searching the public data snapshot…');
  results.setAttribute('aria-busy', 'true');
  try {
    const index = await loadIndex();
    if (current !== generation) return;
    found = searchIndex(index, filters);
    observationPage = variablePage = 1;
    renderObservations(); renderVariables();
    document.querySelector('#observation-total').textContent = found.observations.length.toLocaleString();
    document.querySelector('#variable-total').textContent = found.variables.length.toLocaleString();
    results.hidden = false;
    announce(`${found.observations.length.toLocaleString()} observations and ${found.variables.length.toLocaleString()} variable definitions found.`);
  } catch {
    if (current !== generation) return;
    announce('Search data could not be loaded. Check your connection and retry. The complete CSV is also available below.');
    retry.hidden = false;
  } finally {
    if (current === generation) results.removeAttribute('aria-busy');
  }
}
form.addEventListener('submit', event => {
  event.preventDefault();
  const filters = Object.fromEntries(keys.map(key => [key, form.elements[key].value.trim()]));
  const url = new URL(location.href);
  for (const key of keys) {
    if (filters[key]) url.searchParams.set(key, filters[key]); else url.searchParams.delete(key);
  }
  history.pushState(null, '', url);
  execute(filters);
});
retry.addEventListener('click', () => execute(filtersFromURL()));
window.addEventListener('popstate', () => { const filters = filtersFromURL(); fill(filters); execute(filters); });
const initial = filtersFromURL();
fill(initial);
if (hasQuery(initial)) execute(initial);
