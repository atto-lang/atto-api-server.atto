// Structural security regression only. Does NOT compile or execute Oreslang.
// Real native compiler, HTTP, PostgreSQL and concurrency integration are required.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const server=fs.readFileSync(new URL('../src/main.ores',import.meta.url),'utf8');
const sql=fs.readFileSync(new URL('../migrations/001_device_build_admission.sql',import.meta.url),'utf8');

test('service is implemented as Oreslang native HTTP actor, not JavaScript server',()=>{
  assert.match(server,/define isoactor BuildApiHandler as/);
  assert.match(server,/http\.listen\("127\.0\.0\.1", 3000,/);
  assert.match(server,/http\.claim\(mail\.value\)/);
  assert.match(server,/handler\.dispatch\(request\)/);
  assert.doesNotMatch(server,/process\.env|require\(|express\(|node:http/);
});
test('liveness is separated from blocked readiness',()=>{
  assert.match(server,/target == "\/health"[\s\S]*?request\.respond\(200/);
  assert.match(server,/target == "\/ready"[\s\S]*?request\.respond\(503/);
});
test('every sensitive endpoint fails closed until actual secure adapters',()=>{
  for(const route of [
    '/v1/device-keys','/v1/device-keys/confirm','/v1/device-keys/revoke',
    '/v1/build-challenges','/v1/build-uploads',
    '/v1/zed/build-challenges','/v1/zed/build-uploads'
  ]) {
    const start=server.indexOf('target == "'+route+'"');
    assert.ok(start>=0,'missing '+route);
    const next=server.indexOf('request.respond(',start);
    assert.ok(next>=0 && next-start<80,'missing response '+route);
    assert.match(server.slice(next,next+50),/^request\.respond\(503,/,'unsafe active '+route);
  }
  assert.doesNotMatch(server,/request\.respond\(20[01],[^\n]*device_enrollment/);
});
test('schema includes binding to tenant/key/challenge and explicit quarantine',()=>{
  for(const field of ['tenant_id','device_key_id','upload_token_sha256','source_sha256',
    'toolchain_sha256','consumed_at','artifact_sha256','provenance_sha256','quarantined']) {
    assert.ok(sql.includes(field),'missing '+field);
  }
  assert.match(sql,/PRIMARY KEY \(tenant_id, device_key_id\)/);
  assert.match(sql,/challenge_id uuid PRIMARY KEY/);
  assert.match(sql,/challenge_id uuid PRIMARY KEY REFERENCES device_build_challenges/);
});
test('single-statement conditional consume has expiry, replay and active-key fences',()=>{
  assert.match(sql,/WITH consumed AS \(/);
  assert.match(sql,/consumed_at IS NULL AND c\.expires_at>clock_timestamp\(\)/);
  assert.match(sql,/k\.state='active'/);
  assert.match(sql,/INSERT INTO quarantined_device_builds/);
  assert.match(sql,/FROM consumed/);
  assert.match(sql,/REVOKE ALL ON device_build_challenges FROM PUBLIC/);
});
test('never claim a signed device artifact is a trusted release',()=>{
  assert.doesNotMatch(sql,/CHECK \(state = 'release-approved'\)/);
  assert.match(sql,/CHECK \(state = 'quarantined'\)/);
  assert.match(server,/trusted_adapters_unavailable/);
});

test('Zed audience cannot be silently substituted for generic Oreslang challenge',()=>{
  const zed = fs.readFileSync(new URL('../migrations/002_zed_build_audience.sql', import.meta.url),'utf8');
  assert.match(zed,/zed-pkg\/oreslang-build-api\/v1/);
  assert.match(zed,/zed_org IS NULL AND zed_package IS NULL AND zed_version IS NULL/);
  assert.match(zed,/zed_org ~ /);
  assert.match(zed,/zed_package ~ /);
  assert.match(zed,/verification_level = 'untrusted-self-report'/);
});
