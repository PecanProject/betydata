import test from 'node:test';
import assert from 'node:assert/strict';
import {columns, prepareIndex, searchIndex, hasQuery, paginate} from '../../site-assets/js/search-core.js';
export function fixture() {
  return {version: 1, columns, rows: [
    ['traits', 5000000006, 'A', 'A measurement', 2, 'm', 'Panicum virgatum', 'switchgrass', 'Smith', 2020, 'Field', 0],
    ['yields', 5000000006, 'A', null, 3, 'm', 'Other species', null, 'Jones', 2021, null, 1],
    ['traits', 3, 'B', 'leaf area', null, null, 'Panicum virgatum', 'switchgrass', 'Jones', null, null, 0]
  ], variables: [
    {id: 1, name: 'A', description: 'photosynthesis', units: 'm'},
    {id: 2, name: 'A', description: 'another definition', units: 'm'},
    {id: 3, name: 'C', description: 'photosynthesis without observations', units: null}
  ]};
}
const query = (filters, data = fixture()) => searchIndex(prepareIndex(data), filters);
test('all supported fields and combined normalized literal tokens', () => {
  for (const [filters, count] of [[{query:'SMITH'},1],[{query:'leaf area'},1],[{query:'switchgrass'},2],
    [{species:'PANICUM   virgatum'},2],[{author:'jones'},2],[{variable:'photosynthesis'},2],
    [{query:'photosynthesis', species:'switchgrass', author:'smith'},1],[{query:'not-present'},0]]) {
    assert.equal(query(filters).observations.length, count, JSON.stringify(filters));
  }
  assert.equal(query({query: 'photosynthesis PANICUM'}).observations.length, 1);
  assert.equal(query({query: 'photo*'}).observations.length, 0);
});
test('catalog IDs remain distinct; counts shared by name, never row multiplication', () => {
  const result = query({variable:'A', species:'Panicum'});
  assert.equal(result.observations.length, 2); // B's description also contains "a".
  assert.deepEqual(result.variables.slice(0,2).map(v => [v.id, v.count, v.shared]), [[1,1,true],[2,1,true]]);
  assert.equal(query({query:'photosynthesis'}).observations.length, 2);
  assert.equal(query({query:'photosynthesis'}).variables.length, 2); // own definitions only
});
test('zero-count definitions survive author/species filters', () => {
  const result = query({query:'photosynthesis', author:'nobody', species:'missing'});
  assert.equal(result.observations.length, 0);
  assert.deepEqual(result.variables.map(v => [v.id,v.count]), [[1,0],[3,0]]);
  assert.equal(query({author:'Smith'}).variables.length, 3);
});
test('null metadata and composite IDs do not collapse records', () => {
  assert.equal(query({}).observations.length, 3);
  assert.equal(query({query:'null'}).observations.length, 0);
});
test('blank submissions and deterministic pagination boundaries', () => {
  assert.equal(hasQuery({query:' \t '}), false);
  assert.equal(hasQuery({species:'switchgrass'}), true);
  assert.deepEqual(paginate([1,2,3], 2, 2), {rows:[3],page:2,pages:2});
  assert.deepEqual(paginate([], 9, 25), {rows:[],page:1,pages:1});
  assert.equal(paginate([1,2,3], -1, 2).page, 1);
});
test('reject incompatible, corrupt, duplicate or unsafe data', () => {
  const mutations = [d => {d.version=2;}, d => {d.rows.push(d.rows[0]);},
    d => {d.rows[0][1]=null;}, d => {d.rows[0][1]=Number.MAX_SAFE_INTEGER+1;},
    d => {d.rows[0][11]=-1;}, d => {d.rows[0][4]='bad';},
    d => {d.variables[1].id=1;}, d => {d.variables[0].description={bad:1};}];
  for (const mutate of mutations) {const d=fixture();mutate(d);assert.throws(() => prepareIndex(d));}
});
