// Foto de la cara del jugador (unirse al equipo, plantilla y alineación).
// Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_player_photo_rules_test.mjs"
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) throw Error('Local emulator required');
const project = 'demo-canchaya';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const path = p => `projects/${project}/databases/(default)/documents/${p}`;
const token = uid => {
  const enc = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${enc({alg:'none',typ:'JWT'})}.${enc({sub:uid,user_id:uid,email:`${uid}@test.com`,email_verified:true,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'password'}})}.`;
};
const value = v => v === null ? {nullValue:null} : v instanceof Date ? {timestampValue:v.toISOString()} :
  typeof v === 'string' ? {stringValue:v} : typeof v === 'boolean' ? {booleanValue:v} :
  typeof v === 'number' ? (Number.isInteger(v) ? {integerValue:String(v)} : {doubleValue:v}) :
  Array.isArray(v) ? {arrayValue:{values:v.map(value)}} : {mapValue:{fields:fields(v)}};
const fields = o => Object.fromEntries(Object.entries(o).map(([k,v]) => [k,value(v)]));
async function request(suffix, uid, body, method='POST') {
  return fetch(root+suffix,{method, headers:{'Content-Type':'application/json', ...(uid ? {Authorization:`Bearer ${uid === 'owner' ? 'owner' : token(uid)}`} : {})}, body:body ? JSON.stringify(body) : undefined});
}
const write = (p,data,mask,stamps=[],extraTransforms=[]) => ({update:{name:path(p),fields:fields(data)},
  ...(mask ? {updateMask:{fieldPaths:mask}} : {}),
  ...((stamps.length || extraTransforms.length) ? {updateTransforms:[
    ...stamps.map(fieldPath => ({fieldPath,setToServerValue:'REQUEST_TIME'})),
    ...extraTransforms,
  ]} : {})});
const commit = (uid,writes) => request(':commit',uid,{writes});
async function check(response, allowed, label) {
  const text = await response.text();
  assert.equal(response.ok,allowed,`${label}: ${response.status} ${text}`);
  if (!allowed) assert.match(text,/PERMISSION_DENIED/,label);
  console.log(`PASS ${label}`);
}

const PHOTO = 'https://res.cloudinary.com/ns45i2wp/image/upload/v1/face_p1.jpg';
const PHOTO2 = 'https://res.cloudinary.com/ns45i2wp/image/upload/v2/face_p1b.jpg';

await fetch(`http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});

const code = id => ({code:id,teamId:'a',leagueId:'l',tournamentId:'t',purpose:'playerInvitation',
  delivery:'qr',status:'active',invitedUserId:'',invitedEmail:'',createdByUserId:'manager',
  createdAt:new Date('2026-11-01T00:00:00Z'),expiresAt:new Date('2027-01-01T00:00:00Z')});
await check(await commit('owner',[
  write('leagues/l',{adminUserIds:['admin']}),
  write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',status:'active',managerUserIds:['manager'],playerUserIds:['p2']}),
  write('teamJoinCodes/CODE1',code('CODE1')),
  write('teamJoinCodes/CODE2',code('CODE2')),
  write('teamJoinCodes/CODE3',code('CODE3')),
  write('teamAssignments/old',{userId:'p2',userEmail:'p2@test.com',userDisplayName:'Dos',teamId:'a',
    leagueId:'l',tournamentId:'t',role:'player',status:'active',assignedByUserId:'manager'}),
  write('teamAssignments/mgr',{userId:'manager',userEmail:'manager@test.com',userDisplayName:'Encargado',teamId:'a',
    leagueId:'l',tournamentId:'t',role:'teamManager',status:'active',assignedByUserId:'admin'}),
]),true,'seed fixture');

// Mismo batch que player_join_screen.dart.
const join = (uid, codeId, extra={}) => {
  const assignment = {userId:uid,userEmail:`${uid}@test.com`,userDisplayName:'Uno',teamId:'a',leagueId:'l',
    tournamentId:'t',role:'player',status:'active',assignedByUserId:'manager',joinCodeId:codeId,...extra};
  return commit(uid,[
    write(`teamAssignments/${codeId}`,assignment,null,['createdAt','acceptedAt','updatedAt']),
    write('teams/a',{lastPlayerJoinCodeId:codeId},['lastPlayerJoinCodeId','updatedAt'],['updatedAt'],
      [{fieldPath:'playerUserIds',appendMissingElements:{values:[{stringValue:uid}]}}]),
    write(`teamJoinCodes/${codeId}`,{status:'used',usedByUserId:uid},['status','usedByUserId','usedAt','updatedAt'],['usedAt','updatedAt']),
  ]);
};

await check(await join('p1','CODE1'),false,'joining without a face photo is rejected');
await check(await join('p1','CODE1',{userPhotoUrl:''}),false,'empty photo rejected');
await check(await join('p1','CODE1',{userPhotoUrl:'https://evil.example.com/x.jpg'}),false,'photo outside CanchaYA Cloudinary rejected');
await check(await join('p1','CODE1',{userPhotoUrl:'http://res.cloudinary.com/ns45i2wp/image/upload/v1/x.jpg'}),false,'non-HTTPS photo rejected');
await check(await join('p1','CODE1',{userPhotoUrl:'https://res.cloudinary.com/other/image/upload/v1/x.jpg'}),false,'photo from another Cloudinary account rejected');
await check(await join('p1','CODE1',{userPhotoUrl:PHOTO}),true,'player joins with a face photo');

// Jugadores que entraron antes: agregan su foto.
const setPhoto = (uid, id, data, mask) => commit(uid,[write(`teamAssignments/${id}`,data,mask,['updatedAt'])]);
await check(await setPhoto('p2','old',{userPhotoUrl:PHOTO2},['userPhotoUrl','updatedAt']),true,'existing player adds own photo');
await check(await setPhoto('p2','old',{userPhotoUrl:PHOTO},['userPhotoUrl','updatedAt']),true,'player replaces own photo');
await check(await setPhoto('p2','old',{userPhotoUrl:'https://evil.example.com/x.jpg'},['userPhotoUrl','updatedAt']),false,'invalid replacement rejected');
await check(await setPhoto('p2','old',{userPhotoUrl:PHOTO,role:'teamManager'},['userPhotoUrl','role','updatedAt']),false,'cannot change role with photo');
await check(await setPhoto('p2','old',{userPhotoUrl:PHOTO,userDisplayName:'Otro'},['userPhotoUrl','userDisplayName','updatedAt']),false,'cannot change name with photo');
await check(await setPhoto('p1','old',{userPhotoUrl:PHOTO},['userPhotoUrl','updatedAt']),false,'cannot set another player photo');
await check(await setPhoto('manager','old',{userPhotoUrl:PHOTO},['userPhotoUrl','updatedAt']),false,'manager cannot set player photo');
await check(await setPhoto('manager','mgr',{userPhotoUrl:PHOTO},['userPhotoUrl','updatedAt']),false,'manager assignment not covered by photo rule');
await check(await commit('p2',[write('teamAssignments/old',{userPhotoUrl:PHOTO},['userPhotoUrl','updatedAt'])]),false,'updatedAt must be request time');

// Alineación con fotos.
const players = ['p1','p2','p3','p4','p5','p6','p7'];
await check(await commit('owner',[write('teams/a',{name:'A',leagueId:'l',tournamentId:'t',status:'active',managerUserIds:['manager'],playerUserIds:players})]),true,'seed full roster');
const lineup = (overrides={}) => ({teamId:'a',leagueId:'l',tournamentId:'t',format:'football7',formation:'2-3-1',
  slots:['p1','p2','','','','',''],playerNames:['Uno','Dos','','','','',''],
  updatedByUserId:'manager',...overrides});
const save = (uid,data) => commit(uid,[write('teamLineups/a',data,null,['updatedAt'])]);
await check(await save('manager',lineup()),true,'lineup without photos still allowed');
await check(await save('manager',lineup({playerPhotoUrls:[PHOTO,PHOTO2,'','','','','']})),true,'lineup with photos allowed');
await check(await save('manager',lineup({playerPhotoUrls:[PHOTO]})),false,'photo list must match positions');
await check(await save('manager',lineup({playerPhotoUrls:'x'})),false,'photo list must be a list');
await check(await save('p1',lineup({updatedByUserId:'p1',playerPhotoUrls:[PHOTO,'','','','','','']})),false,'player cannot edit lineup photos');

console.log('ALL PLAYER PHOTO RULE TESTS PASSED');
