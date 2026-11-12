// Eliminar equipos (solo administrador de la liga). Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_team_deletion_rules_test.mjs"
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Local emulator required');
const project = 'demo-canchaya';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const path = p => `projects/${project}/databases/(default)/documents/${p}`;
const token = uid => {
  const enc = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,email:`${uid}@example.com`,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom'}})}.`;
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
const query = (uid, collectionId, filters) => request(':runQuery', uid, {structuredQuery:{
  from:[{collectionId}],
  where:{compositeFilter:{op:'AND',filters:filters.map(([field,v]) => ({fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:{stringValue:v}}}))}},
}});

await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});

const assignment = (userId, role, status='active') => ({userId,userEmail:`${userId}@example.com`,teamId:'a',leagueId:'l',
  tournamentId:'t',role,status,assignedByUserId:'admin'});

await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('leagues/l2',{adminUserIds:['otherAdmin']}),
  write('teams/a',{name:'Diablos',leagueId:'l',tournamentId:'t',status:'active',managerUserIds:['manager'],playerUserIds:['p1','p2']}),
  write('publicTeams/a',{name:'Diablos',shortName:'',logoUrl:'',leagueId:'l',tournamentId:'t',updatedAt:new Date()}),
  write('teamLineups/a',{teamId:'a',leagueId:'l',tournamentId:'t',format:'football5',formation:'2-2',slots:['p1','','','',''],playerNames:['Uno','','','',''],updatedByUserId:'manager',updatedAt:new Date()}),
  write('teamAssignments/asgManager',assignment('manager','teamManager')),
  write('teamAssignments/asgP1',assignment('p1','player')),
  write('teamAssignments/asgP2',assignment('p2','player')),
  write('teamAssignments/asgOld',assignment('old','player','rejected')),
  write('teamManagerInvitations/inv1',{teamId:'a',teamName:'Diablos',leagueId:'l',tournamentId:'t',invitedEmail:'new@example.com',invitedByUserId:'admin',invitedUserId:'',status:'pending'}),
]),true,'seed fixture');

// Consultas que hace la app antes de eliminar.
await check(await query('admin','teamAssignments',[['teamId','a'],['leagueId','l']]),true,'league admin lists the team assignments');
await check(await query('admin','teamManagerInvitations',[['teamId','a'],['leagueId','l']]),true,'league admin lists the team invitations');
await check(await query('otherAdmin','teamAssignments',[['teamId','a'],['leagueId','l']]),false,'other league admin cannot list them');

const revoke = id => write(`teamAssignments/${id}`,{status:'revoked'},['status'],['revokedAt','updatedAt']);
const revokeInvitation = id => write(`teamManagerInvitations/${id}`,{status:'revoked'},['status'],['updatedAt']);
const fullDeletion = [del('teams/a'),del('publicTeams/a'),del('teamLineups/a'),
  revoke('asgManager'),revoke('asgP1'),revoke('asgP2'),revokeInvitation('inv1')];

// Permisos.
await check(await commit('p1',fullDeletion),false,'player cannot delete the team');
await check(await commit('manager',fullDeletion),false,'team manager cannot delete the team');
await check(await commit('otherAdmin',fullDeletion),false,'admin of another league cannot delete the team');

// Debe ser completo y atómico.
await check(await commit('admin',[del('teams/a')]),false,'team alone (public card left behind) is rejected');
await check(await commit('admin',[del('teams/a'),del('publicTeams/a')]),false,'team without deleting its lineup is rejected');
await check(await commit('admin',[del('publicTeams/a')]),false,'public card cannot be deleted while the team exists');
await check(await commit('admin',[del('teamLineups/a')]),false,'lineup cannot be deleted while the team exists');
await check(await commit('admin',[revoke('asgP1')]),false,'cannot revoke a player while the team still exists');
await check(await commit('admin',[revokeInvitation('inv1')]),false,'cannot cancel an invitation while the team still exists');

// Eliminación completa.
await check(await commit('admin',fullDeletion),true,'league admin deletes team, card, lineup and revokes access atomically');
await check(await request('/teamAssignments/asgManager','manager',null,'GET'),true,'former manager can still read the history');
await check(await commit('admin',[revoke('asgOld')]),false,'rejected assignments are not changed');
await check(await commit('p1',[write('teamAssignments/asgP1',{status:'active'},['status'],['updatedAt'])]),false,'revoked player cannot reactivate himself');

console.log('All team deletion security tests passed.');
