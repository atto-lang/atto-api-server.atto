-- Harden atomic build admission after migrations 001-003.
-- Do not grant this function to an HTTP identity. Call only after authenticated,
-- verified device signature and durable uploaded-byte digest checks.
BEGIN;
DROP FUNCTION IF EXISTS public.admit_quarantined_build(uuid,text,text,bytea,text,text,text);
CREATE FUNCTION public.admit_quarantined_build(
 p_challenge_id uuid, p_tenant_id text, p_device_key_id text,
 p_audience text, p_zed_org text, p_zed_package text, p_zed_version text,
 p_source_commit text, p_source_sha256 text, p_toolchain_sha256 text,
 p_target text, p_nonce bytea, p_upload_token_sha256 bytea,
 p_artifact_sha256 text, p_object_key text, p_provenance_sha256 text
) RETURNS TABLE(admitted_challenge_id uuid)
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = pg_catalog, public
AS $body$
WITH locked_key AS MATERIALIZED (
 SELECT k.tenant_id, k.device_key_id
 FROM public.enrolled_device_keys AS k
 WHERE k.tenant_id=p_tenant_id AND k.device_key_id=p_device_key_id
   AND k.state='active'
 FOR SHARE
), consumed AS (
 UPDATE public.device_build_challenges AS c SET consumed_at=clock_timestamp()
 WHERE c.challenge_id=p_challenge_id AND c.tenant_id=p_tenant_id
   AND c.device_key_id=p_device_key_id AND c.audience=p_audience
   AND c.zed_org IS NOT DISTINCT FROM p_zed_org
   AND c.zed_package IS NOT DISTINCT FROM p_zed_package
   AND c.zed_version IS NOT DISTINCT FROM p_zed_version
   AND c.source_commit=p_source_commit AND c.source_sha256=p_source_sha256
   AND c.toolchain_sha256=p_toolchain_sha256 AND c.target=p_target
   AND c.nonce=p_nonce AND c.upload_token_sha256=p_upload_token_sha256
   AND c.consumed_at IS NULL AND c.expires_at>clock_timestamp()
   AND EXISTS (
     SELECT 1 FROM locked_key k
     WHERE k.tenant_id=c.tenant_id AND k.device_key_id=c.device_key_id
   )
 RETURNING c.challenge_id, c.tenant_id
)
INSERT INTO public.quarantined_device_builds
 (challenge_id,tenant_id,artifact_sha256,object_key,signer_key_id,provenance_sha256)
SELECT c.challenge_id,c.tenant_id,p_artifact_sha256,p_object_key,
       p_device_key_id,p_provenance_sha256
FROM consumed c
RETURNING challenge_id;
$body$;
REVOKE ALL ON FUNCTION public.admit_quarantined_build(
 uuid,text,text,text,text,text,text,text,text,text,text,bytea,bytea,text,text,text
) FROM PUBLIC;
COMMIT;
-- Successful admission grants quarantine-only state. Revocation serializes
-- with admission via row locks. Only verified original-challenge values belong
-- in the parameters. NEVER treat a signed self-report as compilation proof.
