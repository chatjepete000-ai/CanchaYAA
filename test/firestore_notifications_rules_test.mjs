// F06 (avisos de partidos en la bandeja). Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_notifications_rules_test.mjs"
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

await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('leagues/l2',{adminUserIds:['otherAdmin']}),
  write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',managerUserIds:['managerA'],playerUserIds:['p1','p2']}),
  write('teams/b',{name:'B',leagueId:'l',tournamentId:'t',managerUserIds:['managerB'],playerUserIds:['q1']}),
  write('teams/c',{name:'C',leagueId:'l',tournamentId:'t',managerUserIds:[],playerUserIds:['outsider']}),
  write('tournamentMatches/m',{leagueId:'l',tournamentId:'t',homeTeamId:'a',awayTeamId:'b',status:'scheduled'}),
]),true,'seed fixture');

const notice = ({recipient='p1',sender='admin',type='match_created',eventKey='sched_1',matchId='m',...extra}={}) => ({
  recipientUserId:recipient,title:'A vs B',body:'Se programó el partido.',type,isRead:false,readAt:null,
  senderUserId:sender,matchId,tournamentId:'t',route:'notifications',data:{eventKey,homeTeamId:'a',awayTeamId:'b'},...extra});
const send = (uid,data,id=`${data.matchId}_${data.data.eventKey}_${data.recipientUserId}`) =>
  commit(uid,[write(`notifications/${id}`,data,null,['createdAt'])]);

// 1) Avisos del administrador de la liga.
await check(await send('admin',notice()),true,'league admin notifies a home-team player');
await check(await send('admin',notice({recipient:'q1'})),true,'league admin notifies an away-team player');
await check(await send('admin',notice({recipient:'managerB'})),true,'league admin notifies a team manager');
await check(await send('admin',notice()),false,'retrying the same notice does not duplicate it');
await check(await send('admin',notice({recipient:'outsider'})),false,'cannot notify someone outside both teams');
await check(await send('otherAdmin',notice({sender:'otherAdmin',eventKey:'sched_2'})),false,'admin of another league cannot notify');
await check(await send('p1',notice({recipient:'p2',sender:'p1',eventKey:'sched_3'})),false,'player cannot send match notices to others');
await check(await send('managerA',notice({recipient:'q1',sender:'managerA',eventKey:'sched_4'})),false,'team manager cannot send match notices');
await check(await send('admin',notice({sender:'someoneElse',eventKey:'sched_5'})),false,'cannot spoof the sender');
await check(await send('admin',notice({type:'system',eventKey:'sched_6'})),false,'arbitrary notification types rejected');
await check(await send('admin',notice({eventKey:'sched_7'}),'custom_id'),false,'notification id must be deterministic');
await check(await send('admin',notice({eventKey:'sched_8',isRead:true})),false,'cannot create already read');
await check(await send('admin',{...notice({eventKey:'sched_9'}),extra:'x'}),false,'unknown fields rejected');
await check(await send('admin',notice({eventKey:'sched_10',title:'x'.repeat(121)})),false,'oversized title rejected');

// 2) Recordatorios en la propia bandeja.
const reminder = (uid,key='r24',recipient=uid) => notice({recipient,sender:uid,type:'match_reminder',eventKey:key});
await check(await send('p1',reminder('p1')),true,'player registers own reminder');
await check(await send('managerB',reminder('managerB','r1')),true,'manager registers own reminder');
await check(await send('p1',reminder('p1')),false,'same reminder is not duplicated');
await check(await send('p1',reminder('p1','r1','p2')),false,'cannot create reminders for someone else');
await check(await send('outsider',reminder('outsider','r0')),false,'non-member cannot create reminder for the match');
await check(await send('p1',reminder('p1','sched_x')),false,'reminder key must be r24, r1 or r0');

// Lectura y marcado como leído (reglas existentes).
await check(await request(`/notifications/m_sched_1_p1`,'p1',null,'GET'),true,'recipient reads own notice');
await check(await request(`/notifications/m_sched_1_p1`,'p2',null,'GET'),false,'others cannot read it');
await check(await commit('p1',[write('notifications/m_sched_1_p1',{isRead:true},['isRead'],['readAt'])]),true,'recipient marks as read');
await check(await commit('p1',[{delete:path('notifications/m_sched_1_p1')}]),false,'notices cannot be deleted');

console.log('All notification security tests passed.');
