// Suspender (clima u otro motivo), cancelar y reprogramar partidos.
// Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_match_status_rules_test.mjs"
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
const del = p => ({delete:path(p)});
const commit = (uid,writes) => request(':commit',uid,{writes});
async function check(response, allowed, label) {
  const text = await response.text();
  assert.equal(response.ok,allowed,`${label}: ${response.status} ${text}`);
  if (!allowed) assert.match(text,/PERMISSION_DENIED/,label);
  console.log(`PASS ${label}`);
}

await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});

// Bloques de 2 h en el futuro (alineados a UTC).
const block = n => new Date((Math.floor(Date.now() / 7200000) + n) * 7200000);
const s1 = block(24), s2 = block(30);

const base = {leagueId:'l',tournamentId:'t',roundNumber:1,matchNumber:1,homeTeamId:'a',awayTeamId:'b',
  homeTeamName:'A',awayTeamName:'B',homeScore:null,awayScore:null,createdByUserId:'admin',
  createdAt:new Date(),updatedAt:new Date()};
const scheduledAt = (start, extra={}) => ({...base,status:'scheduled',courtId:'c',courtName:'Cancha',
  bookingId:`c_${start.getTime()}`,startsAt:start,...extra});
const bookings = (matchId, start) => [
  write(`courtBookings/c_${start.getTime()}`,{courtId:'c',matchId,leagueId:'l',startsAt:start}),
  write(`teamBookings/a_${start.getTime()}`,{teamId:'a',matchId,leagueId:'l',startsAt:start}),
  write(`teamBookings/b_${start.getTime()}`,{teamId:'b',matchId,leagueId:'l',startsAt:start}),
];

await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('leagues/l2',{adminUserIds:['otherAdmin']}),
  write('courts/c',{name:'Cancha',active:true}),
  write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',managerUserIds:['manager'],playerUserIds:['p1']}),
  write('teams/b',{name:'B',leagueId:'l',tournamentId:'t',managerUserIds:[],playerUserIds:['q1']}),
  write('tournamentMatches/m1',scheduledAt(s1)), ...bookings('m1',s1),
  write('tournamentMatches/m2',scheduledAt(s2,{matchNumber:2})), ...bookings('m2',s2),
  write('tournamentMatches/done',{...base,matchNumber:3,status:'completed',homeScore:2,awayScore:1}),
]),true,'seed fixture');

// Mismo batch que MatchStatusRepository.
const change = (uid, matchId, start, status, {reason='weather', note=null, release=true, extra={}}={}) => commit(uid,[
  ...(release && start ? [del(`courtBookings/c_${start.getTime()}`), del(`teamBookings/a_${start.getTime()}`), del(`teamBookings/b_${start.getTime()}`)] : []),
  write(`tournamentMatches/${matchId}`,{status,statusReason:reason,...(note === null ? {} : {statusNote:note}),...extra},
    ['status','statusReason',...(note === null ? [] : ['statusNote']),
     ...(start ? ['courtId','courtName','startsAt','bookingId'] : []),...Object.keys(extra),'updatedAt'],['updatedAt']),
]);

await check(await change('p1','m1',s1,'postponed'),false,'player cannot suspend');
await check(await change('manager','m1',s1,'postponed'),false,'team manager cannot suspend');
await check(await change('otherAdmin','m1',s1,'postponed'),false,'admin of another league cannot suspend');
await check(await change('admin','m1',s1,'postponed',{release:false}),false,'must release court and team bookings');
await check(await change('admin','m1',s1,'postponed',{reason:'lluvia'}),false,'unknown reason rejected');
await check(await change('admin','m1',s1,'postponed',{note:'x'.repeat(141)}),false,'note too long rejected');
await check(await change('admin','m1',s1,'postponed',{extra:{homeScore:1}}),false,'cannot set a score while suspending');
await check(await change('admin','m1',s1,'postponed',{note:'Tormenta eléctrica'}),true,'admin suspends for weather and frees the court');

// Reprogramar el suspendido: nuevas reservas, sin motivo.
const s3 = block(36);
const reschedule = (keepReason) => commit('admin',[
  ...bookings('m1',s3),
  write('tournamentMatches/m1',{status:'scheduled',courtId:'c',courtName:'Cancha',bookingId:`c_${s3.getTime()}`,startsAt:s3,
    ...(keepReason ? {statusReason:'weather'} : {})},
    ['status','courtId','courtName','bookingId','startsAt',...(keepReason ? [] : ['statusReason','statusNote']),'updatedAt'],['updatedAt']),
]);
await check(await reschedule(true),false,'rescheduling must clear the suspension reason');
await check(await reschedule(false),true,'admin reschedules the suspended match');

// Cancelar.
await check(await change('admin','m2',s2,'cancelled',{reason:'court',release:false}),false,'cancel must release bookings');
await check(await change('manager','m2',s2,'cancelled',{reason:'court'}),false,'team manager cannot cancel');
await check(await change('admin','m2',s2,'cancelled',{reason:'court'}),true,'admin cancels and frees the court');
await check(await change('admin','m2',null,'postponed'),false,'a cancelled match cannot be suspended');
await check(await commit('admin',[write('tournamentMatches/m2',{status:'scheduled'},['status','statusReason','updatedAt'],['updatedAt'])]),false,'a cancelled match cannot be rescheduled without a venue');
await check(await change('admin','done',null,'cancelled',{reason:'other'}),false,'a completed match cannot be cancelled');
await check(await commit('admin',[del('tournamentMatches/m2')]),true,'a cancelled match can be removed when regenerating the calendar');

console.log('ALL MATCH STATUS RULE TESTS PASSED');
