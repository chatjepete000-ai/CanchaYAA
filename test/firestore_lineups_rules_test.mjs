// F04 (alineaciones). Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_lineups_rules_test.mjs"
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Local emulator required');
const project = 'demo-canchaya';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const path = p => `projects/${project}/databases/(default)/documents/${p}`;
const token = uid => {
  const enc = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
};
const value = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} :
  typeof v === 'string' ? {stringValue:v} : typeof v === 'boolean' ? {booleanValue:v} :
  typeof v === 'number' ? (Number.isInteger(v) ? {integerValue:String(v)} : {doubleValue:v}) :
  Array.isArray(v) ? {arrayValue:{values:v.map(value)}} : {mapValue:{fields:fields(v)}};
const fields = o => Object.fromEntries(Object.entries(o).map(([k,v]) => [k,value(v)]));
async function request(suffix, uid, body, method='POST') {
  return fetch(root+suffix,{method, headers:{'Content-Type':'application/json', ...(uid ? {Authorization:`Bearer ${uid === 'owner' ? 'owner' : token(uid)}`} : {})}, body:body ? JSON.stringify(body) : undefined});
}
const write = (p,data,mask,stamps=[]) => ({update:{name:path(p),fields:fields(data)},
  ...(mask ? {updateMask:{fieldPaths:mask}} : {}),
  ...(stamps.length ? {updateTransforms:stamps.map(fieldPath => ({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})});
const commit = (uid,writes) => request(':commit',uid,{writes});
async function check(response, allowed, label) {
  const text = await response.text();
  assert.equal(response.ok,allowed,`${label}: ${response.status} ${text}`);
  if (!allowed) assert.match(text,/PERMISSION_DENIED/,label);
  console.log(`PASS ${label}`);
}

await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});

const players = ['p1','p2','p3','p4','p5','p6','p7','p8'];
await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',managerUserIds:['manager'],playerUserIds:players}),
  write('teams/b',{name:'B',leagueId:'l',tournamentId:'t',managerUserIds:['otherManager'],playerUserIds:['q1']}),
]),true,'seed fixture');

const lineup = (overrides={}) => ({teamId:'a',leagueId:'l',tournamentId:'t',format:'football7',formation:'2-3-1',
  slots:['p1','p2','p3','','p5','p6','p7'],playerNames:['Uno','Dos','Tres','','Cinco','Seis','Siete'],
  updatedByUserId:'manager',...overrides});
const save = (uid,data) => commit(uid,[write('teamLineups/a',data,null,['updatedAt'])]);

await check(await save('p1',lineup({updatedByUserId:'p1'})),false,'player cannot edit lineup');
await check(await save('otherManager',lineup({updatedByUserId:'otherManager'})),false,'another team manager cannot edit');
await check(await save('admin',lineup({updatedByUserId:'admin'})),false,'league admin cannot edit (only the team manager)');
await check(await save('manager',lineup({slots:['p1','p1','','','','','']})),false,'same player in two positions rejected');
await check(await save('manager',lineup({slots:['q1','','','','','','']})),false,'player from another team rejected');
await check(await save('manager',lineup({slots:['p1','','','','','']})),false,'wrong number of positions rejected');
await check(await save('manager',lineup({format:'football9'})),false,'unknown format rejected');
await check(await save('manager',lineup({updatedByUserId:'p1'})),false,'cannot spoof who edited');
await check(await save('manager',lineup({leagueId:'other'})),false,'league must match the team');
await check(await save('manager',{...lineup(),extra:'x'}),false,'unknown fields rejected');
await check(await save('manager',lineup()),true,'team manager saves lineup');
await check(await save('manager',lineup({slots:['p2','p1','p3','p4','p5','p6','p8']})),true,'team manager updates lineup');
await check(await save('manager',lineup({slots:['','','','','','',''],playerNames:['','','','','','','']})),true,'empty lineup allowed');

await check(await request('/teamLineups/a','p3',null,'GET'),true,'team player reads lineup');
await check(await request('/teamLineups/a','manager',null,'GET'),true,'team manager reads lineup');
await check(await request('/teamLineups/a','admin',null,'GET'),true,'league admin reads lineup');
await check(await request('/teamLineups/a','q1',null,'GET'),false,'player of another team cannot read');
await check(await request('/teamLineups/a',null,null,'GET'),false,'anonymous cannot read');
await check(await commit('manager',[{delete:path('teamLineups/a')}]),false,'lineup cannot be deleted');

console.log('All lineup security tests passed.');
