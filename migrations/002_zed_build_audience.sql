-- Zed Package extension for Oreslang-issued one-use device challenges.
-- This is a schema-only migration. No API routes are enabled by this file.
-- Apply after 001 using the designated migration role, and only after tests.
BEGIN;

ALTER TABLE device_build_challenges
  ADD COLUMN audience text NOT NULL DEFAULT 'oreslang-build-api/v1',
  ADD COLUMN zed_org text,
  ADD COLUMN zed_package text,
  ADD COLUMN zed_version text;

ALTER TABLE device_build_challenges
  ADD CONSTRAINT zed_build_challenge_audience_ck CHECK (
    (audience = 'oreslang-build-api/v1'
       AND zed_org IS NULL AND zed_package IS NULL AND zed_version IS NULL)
    OR
    (audience = 'zed-pkg/oreslang-build-api/v1'
       AND zed_org ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
       AND zed_package ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
       AND length(zed_version) BETWEEN 1 AND 128
       AND zed_version !~ '[/[:cntrl:]]')
  );

-- Prevent accidental reuse of a nonce across package coordinates or across
-- the standalone Oreslang and Zed Package challenge audiences.
-- Existing UNIQUE (tenant_id, nonce) from migration 001 remains stronger.

ALTER TABLE quarantined_device_builds
  ADD COLUMN verification_level text NOT NULL DEFAULT 'untrusted-self-report'
  CHECK (verification_level = 'untrusted-self-report');

COMMIT;

-- IMPORTANT: an admitted signed Zed receipt is NOT a build certificate.
-- Verify in one atomic transaction against the ORIGINAL immutable challenge
-- row: tenant ID, active device key ID, audience, org/package/version,
-- source/tree digest, compiler digest, target, nonce, expiration, bearer hash.
-- Never allow an independently signed JSON field to substitute for a
-- database-issued expected challenge, or let one audience consume another's.
-- Required business logic is still NOT implemented; HTTP must remain 503.
