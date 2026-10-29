#!/usr/bin/env bash
# Actual PostgreSQL test, NOT Oreslang HTTP or cryptographic verification.
set -euo pipefail
test -n "$DATABASE_URL"
for migration in migrations/001_device_build_admission.sql migrations/002_zed_build_audience.sql migrations/003_atomic_quarantine_admission.sql; do
  psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$migration"
done

psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" <<'SQL'
INSERT INTO enrolled_device_keys
 (tenant_id,device_key_id,ed25519_public_key,state,activated_at,revoked_at)
VALUES
 ('tenant-a','device-a',decode(repeat('a1',32),'hex'),'active',clock_timestamp(),NULL),
 ('tenant-a','revoked',decode(repeat('a2',32),'hex'),'revoked',NULL,clock_timestamp());

INSERT INTO device_build_challenges
 (challenge_id,tenant_id,device_key_id,nonce,upload_token_sha256,source_commit,
  source_sha256,toolchain_sha256,target,expires_at,audience,zed_org,zed_package,zed_version)
VALUES
 ('11111111-1111-1111-1111-111111111111','tenant-a','device-a',decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),repeat('a',40),repeat('b',64),repeat('c',64),'llvm',clock_timestamp()+interval '3 minutes','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3'),
 ('22222222-2222-2222-2222-222222222222','tenant-a','revoked',decode(repeat('b2',32),'hex'),decode(repeat('c2',32),'hex'),repeat('a',40),repeat('b',64),repeat('c',64),'llvm',clock_timestamp()+interval '3 minutes','oreslang-build-api/v1',NULL,NULL,NULL);
-- PostgreSQL CHECK accepts NULL expressions unless fields explicitly prohibit it.
DO $$
BEGIN
  BEGIN
    INSERT INTO device_build_challenges
      (challenge_id,tenant_id,device_key_id,nonce,upload_token_sha256,source_commit,
       source_sha256,toolchain_sha256,target,expires_at,audience,zed_org,zed_package,zed_version)
    VALUES
      ('33333333-3333-3333-3333-333333333333','tenant-a','device-a',
       decode(repeat('b3',32),'hex'),decode(repeat('c3',32),'hex'),
       repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
       clock_timestamp()+interval '3 minutes','zed-pkg/oreslang-build-api/v1','acme',NULL,'1.2.3');
    RAISE EXCEPTION 'SECURITY FAIL: NULL Zed package identity accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;
DO $$
BEGIN
  IF EXISTS(SELECT * FROM admit_quarantined_build(
    '11111111-1111-1111-1111-111111111111','tenant-b','device-a',
    decode(repeat('c1',32),'hex'),repeat('d',64),'quarantine/no-tenant',repeat('e',64)
  )) THEN RAISE EXCEPTION 'SECURITY FAIL: tenant substitution'; END IF;
  IF EXISTS(SELECT * FROM admit_quarantined_build(
    '11111111-1111-1111-1111-111111111111','tenant-a','device-a',
    decode(repeat('11',32),'hex'),repeat('d',64),'quarantine/wrong-token',repeat('e',64)
  )) THEN RAISE EXCEPTION 'SECURITY FAIL: token substitution'; END IF;
  IF EXISTS(SELECT * FROM admit_quarantined_build(
    '22222222-2222-2222-2222-222222222222','tenant-a','revoked',
    decode(repeat('c2',32),'hex'),repeat('d',64),'quarantine/revoked',repeat('e',64)
  )) THEN RAISE EXCEPTION 'SECURITY FAIL: revoked device key'; END IF;
END $$;
SQL

sql="SELECT admitted_challenge_id FROM admit_quarantined_build('11111111-1111-1111-1111-111111111111','tenant-a','device-a',decode(repeat('c1',32),'hex'),repeat('d',64),'quarantine/11111111-1111-1111-1111-111111111111',repeat('e',64));"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$sql" >"$tmp/first" &
a=$!
psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$sql" >"$tmp/second" &
b=$!
wait "$a"
wait "$b"
count="$(cat "$tmp/first" "$tmp/second" | grep -c '^11111111-1111-1111-1111-111111111111$' || true)"
test "$count" = 1 || { echo "SECURITY FAIL: $count winners"; exit 1; }
replay="$(psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$sql")"
test -z "$replay" || { echo "SECURITY FAIL: replay accepted"; exit 1; }

psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" <<'SQL'
DO $$
BEGIN
 IF (SELECT count(*) FROM quarantined_device_builds WHERE tenant_id='tenant-a') <> 1 THEN
   RAISE EXCEPTION 'SECURITY FAIL: expected one receipt';
 END IF;
 IF (SELECT consumed_at IS NULL FROM device_build_challenges WHERE challenge_id='11111111-1111-1111-1111-111111111111') THEN
   RAISE EXCEPTION 'SECURITY FAIL: challenge not consumed';
 END IF;
 IF (SELECT verification_level FROM quarantined_device_builds WHERE tenant_id='tenant-a') <> 'untrusted-self-report' THEN
   RAISE EXCEPTION 'SECURITY FAIL: unwarranted trust';
 END IF;
END $$;
SQL
echo "Postgres PASS: single winner; replay/tenant/token/revocation/audience checks; no crypto/HTTP claim"
