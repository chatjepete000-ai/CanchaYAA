// Ciudad elegida en el perfil (users/{uid}.preferredLocation).
// Run only against the demo emulator.
//
// firebase emulators:exec --only firestore --project demo-canchaya \
//   --config firebase.emulators.json "node test/firestore_users_location_rules_test.mjs"
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
  write('users/u1',{role:'player',adminScope:'none',status:'active',displayName:'Uno'}),
  write('users/u2',{role:'player',adminScope:'none',status:'active',displayName:'Dos'}),
]),true,'seed fixture');

const linares = {city:'Linares',state:'Nuevo León',latitude:24.8597,longitude:-99.5664};
const saveLocation = (uid, target, location) =>
  commit(uid,[write(`users/${target}`,{preferredLocation:location},['preferredLocation'],['updatedAt'])]);

await check(await saveLocation('u1','u1',linares),true,'user saves own city with coordinates');
await check(await saveLocation('u1','u1',{city:'Allende',state:'',latitude:null,longitude:null}),true,'city without coordinates is allowed');
await check(await saveLocation('u2','u1',linares),false,'cannot change another user city');
await check(await saveLocation('u1','u1',{...linares,city:''}),false,'empty city rejected');
await check(await saveLocation('u1','u1',{...linares,city:'x'.repeat(101)}),false,'oversized city rejected');
await check(await saveLocation('u1','u1',{...linares,latitude:120}),false,'latitude out of range rejected');
await check(await saveLocation('u1','u1',{...linares,longitude:null}),false,'half coordinates rejected');
await check(await saveLocation('u1','u1',{...linares,extra:'x'}),false,'unknown location fields rejected');
await check(await saveLocation('u1','u1','Linares'),false,'location must be a map');
await check(await commit('u1',[write('users/u1',{role:'admin'},['role'])]),false,'role still cannot be changed');
await check(await commit('u1',[write('users/u1',{displayName:'Nuevo'},['displayName'],['updatedAt'])]),true,'profile editing still works');

console.log('All user location security tests passed.');
