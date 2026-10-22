// Run only against the demo emulator; no credentials or production writes.
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
  typeof v === 'number' ? {doubleValue:v} : Array.isArray(v) ? {arrayValue:{values:v.map(value)}} : {mapValue:{fields:fields(v)}};
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
await check(await commit('owner',[
  write('users/admin',{role:'admin',status:'active',adminScope:'league'}),
  write('users/other',{role:'admin',status:'active',adminScope:'league'}),
  write('users/player',{role:'player',status:'active',adminScope:'none'}),
  write('users/suspended',{role:'admin',status:'suspended',adminScope:'league'}),
  write('leagues/l',{adminUserIds:['admin','other']}),
]),true,'seed isolated fixture');
const court = {name:'Escuela',address:'Calle 1',city:'Montemorelos',sport:'Fútbol 7',latitude:25.1,longitude:-99.8,active:true,createdBy:'admin'};
const createCourt = (uid,data=court) => commit(uid,[write('courts/c',data,null,['createdAt','updatedAt'])]);
await check(await createCourt(null),false,'anonymous cannot create');
await check(await createCourt('player',{...court,createdBy:'player'}),false,'player cannot create');
await check(await createCourt('suspended',{...court,createdBy:'suspended'}),false,'suspended admin cannot create');
await check(await createCourt('admin',{...court,createdBy:'other'}),false,'cannot spoof owner');
await check(await createCourt('admin'),true,'admin creates court');
await check(await request('/courts/c',null,null,'GET'),false,'anonymous cannot read');
await check(await request('/courts/c','player',null,'GET'),true,'player reads court');
const editCourt = (uid,patch) => commit(uid,[write('courts/c',patch,Object.keys(patch),['updatedAt'])]);
await check(await editCourt('player',{name:'Bad'}),false,'player cannot edit');
await check(await editCourt('other',{name:'Bad'}),false,'other league admin cannot edit owner court');
await check(await editCourt('admin',{address:'x'.repeat(241)}),false,'oversized address rejected on update');
await check(await editCourt('admin',{latitude:91}),false,'invalid latitude rejected');
await check(await editCourt('admin',{createdBy:'other'}),false,'ownership immutable');
await check(await editCourt('admin',{extra:'pollution'}),false,'unknown field rejected');
await check(await editCourt('admin',{name:'Escuela editada'}),true,'owner edits valid court');
await check(await commit('admin',[{delete:path('courts/c')}]),false,'court deletion rejected');
const match = {leagueId:'l',tournamentId:'t',roundNumber:1,matchNumber:1,homeTeamId:'a',awayTeamId:'b',homeTeamName:'A',awayTeamName:'B',status:'scheduled',homeScore:null,awayScore:null,createdByUserId:'admin',createdAt:new Date(),updatedAt:new Date()};
await check(await commit('owner',[write('tournamentMatches/m',match),write('tournamentMatches/m2',{...match,matchNumber:2})]),true,'seed matches');
const start = new Date(Math.ceil((Date.now()+86400000)/7200000)*7200000);
const id = `c_${start.getTime()}`;
const assignment = (matchId,when=start) => {
  const bid = `c_${when.getTime()}`;
  return [...['a','b'].map(teamId => write(`teamBookings/${teamId}_${when.getTime()}`,{teamId,matchId,leagueId:'l',startsAt:when})),write(`courtBookings/${bid}`,{courtId:'c',matchId,leagueId:'l',startsAt:when}),
    write(`tournamentMatches/${matchId}`,{courtId:'c',courtName:'Escuela editada',bookingId:bid,startsAt:when},['courtId','courtName','bookingId','startsAt'],['updatedAt'])];
};
await check(await commit('player',assignment('m')),false,'player cannot schedule');
await check(await commit('admin',[assignment('m').at(-1)]),false,'schedule requires atomic booking');
await check(await commit('admin',assignment('m')),true,'admin schedules atomically');
await check(await commit('other',assignment('m2')),false,'cannot double-book another match');
await check(await commit('admin',[{delete:path(`courtBookings/${id}`)}]),false,'cannot release assigned booking alone');
await check(await commit('admin',assignment('m2',new Date(start.getTime()+3600000))),false,'overlapping off-grid hour rejected');
await check(await request(':runQuery','player',{structuredQuery:{from:[{collectionId:'tournamentMatches'}],where:{compositeFilter:{op:'AND',filters:[{fieldFilter:{field:{fieldPath:'courtId'},op:'EQUAL',value:{stringValue:'c'}}},{fieldFilter:{field:{fieldPath:'status'},op:'EQUAL',value:{stringValue:'scheduled'}}}]}}}}),true,'player can query upcoming court matches');
await check(await request('/tournamentMatches/m2','player',null,'GET'),false,'unpublished match remains private');
const next = new Date(start.getTime()+7200000);
await check(await commit('admin',assignment('m',next)),false,'reschedule must release old slot');
await check(await commit('admin',[...assignment('m',next),{delete:path(`courtBookings/${id}`)},...['a','b'].map(teamId => ({delete:path(`teamBookings/${teamId}_${start.getTime()}`)}))]),true,'atomic reschedule releases old slot');
await check(await commit('other',assignment('m2')),true,'released slot can be reused');
await check(await commit('owner',[write('courts/c2',{...court,name:'Escuela editada',createdAt:new Date(),updatedAt:new Date()})]),true,'seed second court');
const teamConflict = assignment('m2',next).map(w => {
  if(w.update.name.includes('/courtBookings/')) { w.update.name=w.update.name.replace('/c_', '/c2_'); w.update.fields.courtId={stringValue:'c2'}; }
  if(w.update.name.includes('/tournamentMatches/')) { w.update.fields.courtId={stringValue:'c2'}; w.update.fields.bookingId={stringValue:`c2_${next.getTime()}`}; }
  return w;
});
await check(await commit('other',teamConflict),false,'same team cannot play on another court at the same time');
console.log('All court security and booking tests passed.');
