-- PostgreSQL reference schema for a future trusted adapter.
-- Prepared, parameterized calls only. This file is NOT executed by Oreslang
-- until a reviewed Oreslang database binding is available.
-- Run migrations with a dedicated administrator, never the API runtime role.
BEGIN;

CREATE TABLE IF NOT EXISTS enrolled_device_keys (
  tenant_id text NOT NULL CHECK (length(tenant_id) BETWEEN 1 AND 128),
  device_key_id text NOT NULL CHECK (length(device_key_id) BETWEEN 1 AND 128),
  ed25519_public_key bytea NOT NULL CHECK (octet_length(ed25519_public_key) = 32),
  enrollment_nonce_digest bytea CHECK (enrollment_nonce_digest IS NULL OR octet_length(enrollment_nonce_digest)=32),
  enrollment_expires_at timestamptz,
  state text NOT NULL CHECK (state IN ('pending','active','revoked')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  activated_at timestamptz,
  revoked_at timestamptz,
  PRIMARY KEY (tenant_id, device_key_id),
  CHECK (
    (state='pending' AND enrollment_nonce_digest IS NOT NULL AND enrollment_expires_at IS NOT NULL AND activated_at IS NULL AND revoked_at IS NULL)
    OR (state='active' AND enrollment_nonce_digest IS NULL AND enrollment_expires_at IS NULL AND activated_at IS NOT NULL AND revoked_at IS NULL)
    OR (state='revoked' AND enrollment_nonce_digest IS NULL AND enrollment_expires_at IS NULL AND revoked_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS device_build_challenges (
  challenge_id uuid PRIMARY KEY,
  tenant_id text NOT NULL,
  device_key_id text NOT NULL,
  nonce bytea NOT NULL CHECK (octet_length(nonce) = 32),
  upload_token_sha256 bytea NOT NULL CHECK (octet_length(upload_token_sha256) = 32),
  source_commit text NOT NULL CHECK (source_commit ~ '^[0-9a-f]{40}$'),
  source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
  toolchain_sha256 text NOT NULL CHECK (toolchain_sha256 ~ '^[0-9a-f]{64}$'),
  target text NOT NULL CHECK (target IN ('java','llvm','net','wasm','forge','js')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  CONSTRAINT challenge_device_key FOREIGN KEY (tenant_id,device_key_id)
    REFERENCES enrolled_device_keys (tenant_id,device_key_id),
  CHECK (expires_at > created_at AND expires_at <= created_at + interval '5 minutes')
);

CREATE UNIQUE INDEX IF NOT EXISTS device_build_challenge_nonce_unique
  ON device_build_challenges (tenant_id, nonce);
CREATE INDEX IF NOT EXISTS device_build_challenge_expiry
  ON device_build_challenges (expires_at) WHERE consumed_at IS NULL;

CREATE TABLE IF NOT EXISTS quarantined_device_builds (
  challenge_id uuid PRIMARY KEY REFERENCES device_build_challenges(challenge_id),
  tenant_id text NOT NULL,
  artifact_sha256 text NOT NULL CHECK (artifact_sha256 ~ '^[0-9a-f]{64}$'),
  -- Opaque internally assigned immutable/quarantined object-storage pointer:
  object_key text NOT NULL UNIQUE CHECK (length(object_key) BETWEEN 1 AND 512),
  signer_key_id text NOT NULL,
  provenance_sha256 text NOT NULL CHECK (provenance_sha256 ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'quarantined' CHECK (state = 'quarantined'),
  admitted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- The app DB role is provisioned separately with minimal permissions.
-- Explicitly revoke public rights; do not give untrusted upload identities
-- direct SQL/table/row-level privileges.
REVOKE ALL ON enrolled_device_keys FROM PUBLIC;
REVOKE ALL ON device_build_challenges FROM PUBLIC;
REVOKE ALL ON quarantined_device_builds FROM PUBLIC;

COMMIT;

-- AUTHENTICATED DEVICE KEY ENROLLMENT (future adapter):
--  1) Server authenticates tenant and authorization to enroll a key.
--  2) Validate 32-byte Ed25519 public key; generate 32-byte nonce server-side.
--  3) INSERT pending key with SHA-256(nonce) and short expiry.
--  4) Verify an Ed25519 signature over a DOMAIN-SEPARATED enrollment statement
--     including tenant, key ID, nonce and server audience. Never accept a bare
--     signature over an attacker-controlled message.
--  5) Execute the following UPDATE with parameters; require exactly one row.
--
-- UPDATE enrolled_device_keys SET
--   state='active', enrollment_nonce_digest=NULL, enrollment_expires_at=NULL,
--   activated_at=clock_timestamp()
-- WHERE tenant_id=$1 AND device_key_id=$2 AND state='pending'
--   AND enrollment_nonce_digest=$3::bytea AND enrollment_expires_at>clock_timestamp()
-- RETURNING device_key_id;
--
-- REVOCATION: authenticate tenant + appropriate admin role, then UPDATE
-- enrolled_device_keys SET state='revoked', revoked_at=clock_timestamp(),
-- enrollment_nonce_digest=NULL, enrollment_expires_at=NULL
-- WHERE tenant_id=$1 AND device_key_id=$2 AND state IN ('pending','active');
-- No reactivation of the same key ID. New enrollment must use a new key ID.

-- ATOMIC SINGLE-USE QUARANTINE COMMIT (future adapter):
-- Before calling: authenticate tenant; validate expiry and server challenge;
-- verify registered ACTIVE Ed25519 key + signed DSSE predicate; recompute
-- SHA256 over the uploaded bytes; store staged bytes under a durable immutable
-- quarantine object key, and verify stored digest. No user-provided object URL.
-- Stage artifact BEFORE SQL commit, garbage collect orphans after crashes.
--
-- In ONE parameterized SQL statement (atomic across concurrent DB workers):
--
-- WITH consumed AS (
--   UPDATE device_build_challenges AS c
--     SET consumed_at=clock_timestamp()
--   WHERE c.challenge_id=$1::uuid AND c.tenant_id=$2
--     AND c.device_key_id=$3 AND c.upload_token_sha256=$4::bytea
--     AND c.consumed_at IS NULL AND c.expires_at>clock_timestamp()
--     AND EXISTS (
--       SELECT 1 FROM enrolled_device_keys AS k
--       WHERE k.tenant_id=c.tenant_id AND k.device_key_id=c.device_key_id
--         AND k.state='active'
--     )
--   RETURNING c.challenge_id,c.tenant_id
-- )
-- INSERT INTO quarantined_device_builds
--   (challenge_id,tenant_id,artifact_sha256,object_key,signer_key_id,provenance_sha256)
-- SELECT challenge_id,tenant_id,$5,$6,$3,$7 FROM consumed
-- RETURNING challenge_id;
--
-- Exactly one returned row => admitted into QUARANTINE ONLY.
-- Zero returned rows => stale, expired, revoked, replay, or tenant mismatch.
-- No automatic release trust. Never retry a commit with an invented challenge.
-- For unknown commit outcome query challenge_id read-only; never issue another
-- "successful" admission using the same challenge. Database transaction must
-- be durable (PostgreSQL synchronous_commit on; backups/recovery tested).
