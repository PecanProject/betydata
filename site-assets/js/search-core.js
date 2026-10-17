// Search text is deliberately literal: no stemming, synonyms, or row-expanding joins.
export const columns = ['result_type', 'id', 'trait', 'trait_description', 'mean', 'units',
  'scientificname', 'commonname', 'author', 'citation_year', 'sitename', 'checked'];
export const normalize = value => String(value ?? '').toLowerCase().replace(/\s+/gu, ' ').trim();
const tokens = value => normalize(value).split(' ').filter(Boolean);
const matches = (text, terms) => terms.every(term => text.includes(term));
const text = (...values) => normalize(values.join(' '));
export const hasQuery = filters => ['query', 'variable', 'species', 'author'].some(key => normalize(filters[key]));

export function prepareIndex(data) {
  if (data?.version !== 1 || JSON.stringify(data.columns) !== JSON.stringify(columns) ||
      !Array.isArray(data.rows) || !Array.isArray(data.variables)) throw new Error('Unsupported search index');
  const names = new Map();
  const ids = new Set();
  const variables = data.variables.map(variable => {
    if (!variable || !Number.isSafeInteger(variable.id) || variable.id < 0 || ids.has(variable.id) ||
        typeof variable.name !== 'string' || !variable.name.trim() ||
        ![variable.description, variable.units].every(value => value === null || typeof value === 'string')) {
      throw new Error('Invalid variable definition');
    }
    ids.add(variable.id);
    const descriptions = names.get(variable.name) ?? [];
    descriptions.push(variable.description ?? '');
    names.set(variable.name, descriptions);
    return {...variable, search: text(variable.name, variable.description)};
  });
  const keys = new Set();
  const observations = data.rows.map(row => {
    if (!Array.isArray(row) || row.length !== columns.length ||
        !['traits', 'yields'].includes(row[0]) || !Number.isSafeInteger(row[1]) || row[1] < 0 ||
        ![0, 1].includes(row[11]) ||
        !row.every((value, i) => [1, 4, 9, 11].includes(i)
          ? value === null || (typeof value === 'number' && Number.isFinite(value))
          : value === null || typeof value === 'string')) throw new Error('Invalid observation');
    const key = `${row[0]}:${row[1]}`;
    if (keys.has(key)) throw new Error('Duplicate observation');
    keys.add(key);
    const variableText = text(row[2], row[3], ...(names.get(row[2]) ?? []));
    return {row, variableText, speciesText: text(row[6], row[7]), authorText: text(row[8]),
      search: text(variableText, row[6], row[7], row[8])};
  });
  return {observations, variables, names};
}

export function searchIndex(index, filters) {
  const q = tokens(filters.query), variable = tokens(filters.variable);
  const species = tokens(filters.species), author = tokens(filters.author);
  const observations = [];
  const counts = new Map();
  for (const observation of index.observations) {
    if (matches(observation.search, q) && matches(observation.variableText, variable) &&
        matches(observation.speciesText, species) && matches(observation.authorText, author)) {
      observations.push(observation.row);
      counts.set(observation.row[2], (counts.get(observation.row[2]) ?? 0) + 1);
    }
  }
  const variables = index.variables.filter(item => matches(item.search, q) && matches(item.search, variable))
    .map(item => ({...item, count: counts.get(item.name) ?? 0, shared: index.names.get(item.name).length > 1}));
  return {observations, variables};
}

export function paginate(rows, page, size) {
  const pages = Math.max(1, Math.ceil(rows.length / size));
  const current = Math.max(1, Math.min(pages, Number.isSafeInteger(page) ? page : 1));
  return {rows: rows.slice((current - 1) * size, current * size), page: current, pages};
}
