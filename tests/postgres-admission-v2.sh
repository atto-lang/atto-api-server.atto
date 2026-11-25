#!/usr/bin/env bash
# Run on a FRESH disposable database, not the baseline 001-003 test database.
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL for a fresh disposable Postgres database}"
for f in migrations/001_device_build_admission.sql migrations/002_zed_build_audience.sql migrations/003_atomic_quarantine_admission.sql migrations/004_harden_challenge_admission.sql; do
  psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$f" >/dev/null
done
psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" <<'SQL'
INSERT INTO enrolled_device_keys (tenant_id,device_key_id,ed25519_public_key,state,activated_at)
 VALUES ('tenant-a','device-a',decode(repeat('a1',32),'hex'),'active',clock_timestamp());
INSERT INTO device_build_challenges
 (challenge_id,tenant_id,device_key_id,nonce,upload_token_sha256,source_commit,
  source_sha256,toolchain_sha256,target,expires_at,audience,zed_org,zed_package,zed_version)
 VALUES ('11111111-1111-1111-1111-111111111111','tenant-a','device-a',
  decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  clock_timestamp()+interval '3 minutes','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3');
DO $$
BEGIN
 IF EXISTS(SELECT * FROM admit_quarantined_build(
  '11111111-1111-1111-1111-111111111111','tenant-a','device-a',
  'oreslang-build-api/v1','acme','widget','1.2.3',
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),
  repeat('d',64),'quarantine/incorrect-audience',repeat('e',64)
 )) THEN RAISE EXCEPTION 'SECURITY FAIL: cross-audience replay'; END IF;
 IF EXISTS(SELECT * FROM admit_quarantined_build(
  '11111111-1111-1111-1111-111111111111','tenant-a','device-a',
  'zed-pkg/oreslang-build-api/v1','acme','other-pkg','1.2.3',
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),
  repeat('d',64),'quarantine/incorrect-package',repeat('e',64)
 )) THEN RAISE EXCEPTION 'SECURITY FAIL: package substitution'; END IF;
 IF EXISTS(SELECT * FROM admit_quarantined_build(
  '11111111-1111-1111-1111-111111111111','tenant-a','device-a',
  'zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',
  repeat('a',40),repeat('b',64),repeat('f',64),'llvm',
  decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),
  repeat('d',64),'quarantine/incorrect-toolchain',repeat('e',64)
 )) THEN RAISE EXCEPTION 'SECURITY FAIL: toolchain substitution'; END IF;
 IF EXISTS(SELECT * FROM admit_quarantined_build(
  '11111111-1111-1111-1111-111111111111','tenant-a','device-a',
  'zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  decode(repeat('ff',32),'hex'),decode(repeat('c1',32),'hex'),
  repeat('d',64),'quarantine/incorrect-nonce',repeat('e',64)
 )) THEN RAISE EXCEPTION 'SECURITY FAIL: nonce substitution'; END IF;
END $$;
SQL
call="SELECT admitted_challenge_id FROM admit_quarantined_build('11111111-1111-1111-1111-111111111111','tenant-a','device-a','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',repeat('a',40),repeat('b',64),repeat('c',64),'llvm',decode(repeat('b1',32),'hex'),decode(repeat('c1',32),'hex'),repeat('d',64),'quarantine/11111111',repeat('e',64));"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$call" >"$tmp/first" & a=$!
psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$call" >"$tmp/second" & b=$!
wait "$a"; wait "$b"
winners="$(grep -h -c '^11111111-1111-1111-1111-111111111111$' "$tmp/first" "$tmp/second" | awk '{sum+=$1} END{print sum+0}')"
test "$winners" = 1 || { echo "SECURITY FAIL: $winners concurrent winners"; exit 1; }
replay="$(psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "$call")"
test -z "$replay" || { echo "SECURITY FAIL: replay accepted"; exit 1; }
# A collision during the quarantine INSERT must roll back challenge
# consumption; never swallow it with ON CONFLICT DO NOTHING.
psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" <<'SQL'
INSERT INTO device_build_challenges
 (challenge_id,tenant_id,device_key_id,nonce,upload_token_sha256,source_commit,
  source_sha256,toolchain_sha256,target,expires_at,audience,zed_org,zed_package,zed_version)
 VALUES ('33333333-3333-3333-3333-333333333333','tenant-a','device-a',
  decode(repeat('b3',32),'hex'),decode(repeat('c3',32),'hex'),
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  clock_timestamp()+interval '3 minutes','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3');
DO $collision$
BEGIN
  BEGIN
    PERFORM admit_quarantined_build(
      '33333333-3333-3333-3333-333333333333','tenant-a','device-a',
      'zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',
      repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
      decode(repeat('b3',32),'hex'),decode(repeat('c3',32),'hex'),
      repeat('d',64),'quarantine/11111111',repeat('e',64)
    );
    RAISE EXCEPTION 'SECURITY FAIL: duplicate immutable object key accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  IF EXISTS (
    SELECT 1 FROM device_build_challenges
    WHERE challenge_id='33333333-3333-3333-3333-333333333333'
      AND consumed_at IS NOT NULL
  ) THEN RAISE EXCEPTION 'SECURITY FAIL: partial challenge consumption after collision'; END IF;
  IF EXISTS (
    SELECT 1 FROM quarantined_device_builds
    WHERE challenge_id='33333333-3333-3333-3333-333333333333'
  ) THEN RAISE EXCEPTION 'SECURITY FAIL: receipt persisted after collision'; END IF;
  IF NOT EXISTS (SELECT * FROM admit_quarantined_build(
      '33333333-3333-3333-3333-333333333333','tenant-a','device-a',
      'zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',
      repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
      decode(repeat('b3',32),'hex'),decode(repeat('c3',32),'hex'),
      repeat('d',64),'quarantine/33333333',repeat('e',64)
  )) THEN RAISE EXCEPTION 'SECURITY FAIL: retry after rolled-back collision rejected'; END IF;
END $collision$;
SQL
psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" <<'SQL'
INSERT INTO enrolled_device_keys (tenant_id,device_key_id,ed25519_public_key,state,activated_at)
 VALUES ('tenant-a','device-b',decode(repeat('a2',32),'hex'),'active',clock_timestamp());
INSERT INTO device_build_challenges
 (challenge_id,tenant_id,device_key_id,nonce,upload_token_sha256,source_commit,
  source_sha256,toolchain_sha256,target,expires_at,audience,zed_org,zed_package,zed_version)
 VALUES ('22222222-2222-2222-2222-222222222222','tenant-a','device-b',
  decode(repeat('b2',32),'hex'),decode(repeat('c2',32),'hex'),
  repeat('a',40),repeat('b',64),repeat('c',64),'llvm',
  clock_timestamp()+interval '3 minutes','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3');
SQL
# Force revocation to acquire the device row lock before trying admission.
psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" >/dev/null <<SQL &
BEGIN;
UPDATE enrolled_device_keys SET state='revoked',revoked_at=clock_timestamp()
 WHERE tenant_id='tenant-a' AND device_key_id='device-b';
\! touch "$tmp/revocation-locked"
SELECT pg_sleep(2);
COMMIT;
SQL
revoker=$!
for attempt in $(seq 1 100); do
  test -f "$tmp/revocation-locked" && break
  sleep 0.05
done
test -f "$tmp/revocation-locked" || { echo "SECURITY FAIL: no revoker lock"; exit 1; }
blocked="$(psql -X -q -A -t -v ON_ERROR_STOP=1 "$DATABASE_URL" -c "SELECT admitted_challenge_id FROM admit_quarantined_build('22222222-2222-2222-2222-222222222222','tenant-a','device-b','zed-pkg/oreslang-build-api/v1','acme','widget','1.2.3',repeat('a',40),repeat('b',64),repeat('c',64),'llvm',decode(repeat('b2',32),'hex'),decode(repeat('c2',32),'hex'),repeat('d',64),'quarantine/22222222',repeat('e',64));")"
wait "$revoker"
test -z "$blocked" || { echo "SECURITY FAIL: admitted after revocation"; exit 1; }
echo "Postgres hardened PASS: exact challenge binding, single winner, replay and revocation prevented; DB ONLY"
