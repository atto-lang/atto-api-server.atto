-- Durable single-use admission: privileged DB adapter boundary.
--
-- This function is intentionally SQL-only and has NO network or signing
-- behavior. It MUST be called only after the Oreslang API authenticates the
-- tenant, validates the original server-side challenge and active device key,
-- verifies the signed artifact bytes and stages the immutable quarantine blob.
--
-- The migration does NOT grant any API runtime role EXECUTE permission.
-- Provision the trusted role separately after reviewed integration.
BEGIN;

CREATE OR REPLACE FUNCTION admit_quarantined_build(
  p_challenge_id uuid,
  p_tenant_id text,
  p_device_key_id text,
  p_upload_token_sha256 bytea,
  p_artifact_sha256 text,
  p_object_key text,
  p_provenance_sha256 text
)
RETURNS TABLE(admitted_challenge_id uuid)
LANGUAGE sql
VOLATILE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $body$
  WITH consumed AS (
    UPDATE public.device_build_challenges AS c
      SET consumed_at = clock_timestamp()
    WHERE c.challenge_id = p_challenge_id
      AND c.tenant_id = p_tenant_id
      AND c.device_key_id = p_device_key_id
      AND c.upload_token_sha256 = p_upload_token_sha256
      AND c.consumed_at IS NULL
      AND c.expires_at > clock_timestamp()
      AND EXISTS (
        SELECT 1 FROM public.enrolled_device_keys AS k
        WHERE k.tenant_id = c.tenant_id
          AND k.device_key_id = c.device_key_id
          AND k.state = 'active'
      )
    RETURNING c.challenge_id,c.tenant_id
  )
  INSERT INTO public.quarantined_device_builds
    (challenge_id,tenant_id,artifact_sha256,object_key,signer_key_id,provenance_sha256)
  SELECT c.challenge_id,c.tenant_id,
         p_artifact_sha256,p_object_key,p_device_key_id,p_provenance_sha256
  FROM consumed AS c
  -- A unique-key collision MUST cause a statement error and roll back the
  -- UPDATE, not return a false success with a consumed challenge.
  RETURNING challenge_id;
$body$;

REVOKE ALL ON FUNCTION admit_quarantined_build(
  uuid,text,text,bytea,text,text,text
) FROM PUBLIC;

COMMIT;

-- For full integration, provision a narrowly scoped dedicated DB role with
-- only the necessary table UPDATE/INSERT/SELECT and function EXECUTE grants,
-- and deny direct writes from the HTTP/public device identity. This function
-- is SECURITY INVOKER rather than DEFINER to avoid privilege escalation.
-- The application DB role, schema ownership, RLS/tenant scoping, rotation,
-- backups and actual staging durability are separate audited deployment gates.
--
-- Admission is QUARANTINE only. This function cannot mark a release approved.
-- The caller must NOT use any client-provided tenant_id as authenticated scope.
-- The token is bound to the challenge digest; a SHA-256 token is not a signature.
