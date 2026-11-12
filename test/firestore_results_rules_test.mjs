// F08 (resultados con historial) y F05 (publicTournaments).
// Run only against the demo emulator; no credentials or production writes.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_results_rules_test.mjs"
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
// Integers are sent as integerValue so rules see them as int (scores, versions).
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

// ---------------------------------------------------------------
// Fixture: liga l (admin), liga l2 (otherAdmin), torneo t en l,
// partido programado m y partido sin horario m2.
// ---------------------------------------------------------------
const past = new Date(Date.now() - 3 * 3600000);
const match = {leagueId:'l',tournamentId:'t',roundNumber:1,matchNumber:1,homeTeamId:'a',awayTeamId:'b',
  homeTeamName:'A',awayTeamName:'B',status:'scheduled',homeScore:null,awayScore:null,
  createdByUserId:'admin',createdAt:new Date(),updatedAt:new Date(),
  courtId:'c',courtName:'Cancha',bookingId:`c_${past.getTime()}`,startsAt:past};
const unscheduled = {...match,matchNumber:2};
delete unscheduled.courtId; delete unscheduled.courtName; delete unscheduled.bookingId; delete unscheduled.startsAt;
const tournament = {leagueId:'l',name:'Torneo Apertura',category:'Libre',city:'Montemorelos',season:'2026',
  format:'football7',status:'active',createdByUserId:'admin',createdAt:new Date(),updatedAt:new Date()};
await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('leagues/l2',{adminUserIds:['otherAdmin']}),
  write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',managerUserIds:['manager'],playerUserIds:['player']}),
  write('tournaments/t',tournament),
  write('tournamentMatches/m',match),
  write('tournamentMatches/m2',unscheduled),
]),true,'seed fixture');

// ---------------------------------------------------------------
// F08 · Publicar resultado
// ---------------------------------------------------------------
const publish = (uid,{home=2,away=1,version=1,entry='v1',action='published',reason='',matchId='m',prevHome=null,prevAway=null,status=true,historyUid=uid}={}) => [
  write(`tournamentMatches/${matchId}`,{...(status ? {status:'completed'} : {}),homeScore:home,awayScore:away,resultVersion:version},
    [...(status ? ['status'] : []),'homeScore','awayScore','resultVersion'],['updatedAt']),
  write(`tournamentMatches/${matchId}/resultHistory/${entry}`,{action,homeScore:home,awayScore:away,
    previousHomeScore:prevHome,previousAwayScore:prevAway,reason,changedByUserId:historyUid},null,['changedAt']),
];

await check(await commit('player',publish('player')),false,'player cannot publish a result');
await check(await commit('manager',publish('manager')),false,'team manager cannot publish a result');
await check(await commit('otherAdmin',publish('otherAdmin')),false,'admin of another league cannot publish');
await check(await commit('admin',[publish('admin')[0]]),false,'publish without history is rejected');
await check(await commit('admin',[publish('admin')[1]]),false,'history alone (without result) is rejected');
await check(await commit('admin',publish('admin',{home:-1})),false,'negative score rejected');
await check(await commit('admin',publish('admin',{home:100})),false,'score above 99 rejected');
await check(await commit('admin',publish('admin',{version:2,entry:'v2'})),false,'first publish must be version 1');
await check(await commit('admin',publish('admin',{historyUid:'someoneElse'})),false,'cannot spoof who captured');
await check(await commit('admin',publish('admin',{matchId:'m2'})),false,'match without schedule cannot get a result');
await check(await commit('admin',publish('admin')),true,'league admin publishes result with history');
await check(await commit('admin',publish('admin')),false,'publishing twice is rejected');

// ---------------------------------------------------------------
// F08 · Corregir resultado
// ---------------------------------------------------------------
const correct = (uid,opts={}) => publish(uid,{home:3,away:1,version:2,entry:'v2',action:'corrected',
  reason:'Gol mal anotado',prevHome:2,prevAway:1,status:false,...opts});

await check(await commit('player',correct('player')),false,'player cannot correct');
await check(await commit('admin',correct('admin',{reason:'x'})),false,'correction needs a reason');
await check(await commit('admin',correct('admin',{home:2,away:1})),false,'correction must change the score');
await check(await commit('admin',correct('admin',{prevHome:0})),false,'history must record the real previous score');
await check(await commit('admin',correct('admin',{version:3,entry:'v3'})),false,'version must increase by exactly one');
await check(await commit('admin',[correct('admin')[0]]),false,'correction without history is rejected');
await check(await commit('admin',correct('admin')),true,'league admin corrects with reason and history');
await check(await commit('admin',correct('admin')),false,'retrying the same correction does not apply twice');

// Historial inmutable y privado para administradores.
await check(await commit('admin',[write('tournamentMatches/m/resultHistory/v1',{reason:'edit'},['reason'])]),false,'history entries are immutable');
await check(await commit('admin',[{delete:path('tournamentMatches/m/resultHistory/v1')}]),false,'history entries cannot be deleted');
await check(await request('/tournamentMatches/m/resultHistory/v2','admin',null,'GET'),true,'league admin reads history');
await check(await request('/tournamentMatches/m/resultHistory/v2','player',null,'GET'),false,'player cannot read history');
await check(await request('/tournamentMatches/m','player',null,'GET'),true,'player reads the final result');

// Un partido con resultado no se borra (regenerar calendario).
await check(await commit('admin',[{delete:path('tournamentMatches/m')}]),false,'completed match cannot be deleted');

// ---------------------------------------------------------------
// F05 · publicTournaments
// ---------------------------------------------------------------
const publicT = {leagueId:'l',name:'Torneo Apertura',category:'Libre',city:'Montemorelos',season:'2026',format:'football7',status:'active'};
const putPublic = (uid,data=publicT) => commit(uid,[write('publicTournaments/t',data,null,['updatedAt'])]);

await check(await request('/tournaments/t','player',null,'GET'),false,'player cannot read private tournament');
await check(await putPublic('player'),false,'player cannot publish a tournament');
await check(await putPublic('otherAdmin'),false,'other league admin cannot publish');
await check(await putPublic('admin',{...publicT,name:'Otro nombre'}),false,'public data must match the tournament');
await check(await putPublic('admin',{...publicT,createdByUserId:'admin'}),false,'extra private fields rejected');
await check(await putPublic('admin'),true,'league admin publishes public tournament');
await check(await request('/publicTournaments/t','player',null,'GET'),true,'any signed-in user reads public tournament');
await check(await request('/publicTournaments/t',null,null,'GET'),false,'anonymous cannot read public tournament');
await check(await commit('admin',[
  write('tournaments/t',{status:'finished'},['status'],['updatedAt']),
  write('publicTournaments/t',{...publicT,status:'finished'},null,['updatedAt']),
]),true,'status change syncs atomically');
await check(await commit('admin',[{delete:path('publicTournaments/t')}]),false,'public tournament cannot be deleted');

console.log('All result and public tournament security tests passed.');
