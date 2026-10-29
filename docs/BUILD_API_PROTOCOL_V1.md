# Oreslang Device Build API v1 — admission contract

The HTTP service uses actual Oreslang source (src/main.ores), native http.listen,
http.claim and actor-owned HttpExchange. No Node.js server substitutes for it.

## Current status

- Implemented: Oreslang HTTP request-actor dispatch code with loopback listener;
  GET /health returns 200; GET /ready returns 503; security mutations fail
  closed with 503; PostgreSQL migration and documented atomic CTE.
- Not implemented: Oreslang DB adapter, authenticated tenancy, cryptographic
  key proof-of-possession, RNG, DSSE verification, immutable quarantine object
  store, secure token issuance or release authority. These must not be mocked
  into production readiness.
- Real Oreslang compiler execution, live API testing, and hardware attestation
  are not currently verified.

## Endpoints and authorization requirements

GET /health — liveness, 200 is not readiness.
GET /ready — 503 until every trusted adapter passes exact-head tests.
POST /v1/device-keys — authenticated tenant administrator enrolls a pending
32-byte Ed25519 public key, with server-generated independent 32-byte nonce.
POST /v1/device-keys/confirm — independently verify Ed25519 proof over a
domain-separated statement binding audience, tenant, key ID and nonce.
Atomically transition pending to active once; expire pending enrollment.
POST /v1/device-keys/revoke — authenticated admin revokes the key, blocking
future submissions; key IDs are never reused.
POST /v1/build-challenges — authenticated tenant obtains a server-minted
UUID challenge, 256-bit nonce, independent 256-bit upload capability and
short expiry (<=5 minutes). Persist SHA-256 of the upload capability only.
POST /v1/build-uploads — verify tenant, registered ACTIVE device key, nonce,
source-tree hash, compiler binary hash, target, exact uploaded bytes/digest and
DSSE signature, then durably stage immutable bytes and atomically commit
ONE consumed challenge and ONE quarantine receipt.
GET /v1/builds/{id}/verification — tenant-scoped receipt only. A signature
cannot independently promote a build to trusted release.

JSON input must have strict bounded sizes, duplicate-key rejection and
unknown-field rejection. Values from request bodies never establish tenancy.
Trusted auth middleware supplies tenant identity from verified credentials.
Only parameterized SQL calls may touch the database.

## Build input binding

Challenge must bind tenant, device key ID, source Git commit, independent
SHA-256 canonical source tree digest, toolchain binary SHA-256, target backend
(java, llvm, net, wasm, forge, js), and an immutable schema version. Future
flags/ABI/dependency inputs require a schema-version bump; do not silently
accept unbound build options. Only an authenticated user can request tokens;
token alone is upload authorization, not a signing key.

## Durable and single-use admission

The SQL migration under migrations/001_device_build_admission.sql provides
the tables and a single-statement compare-and-set CTE. The Oreslang server
must call it only AFTER a trusted crypto validator verifies signature and
challenge, and AFTER quarantine storage durably holds the hash-checked
artifact. Exactly one returned row is a successful quarantine receipt.
Concurrent submissions cannot each consume the same challenge.

Do not use an in-memory lock, a process-global actor or filesystem
check-then-write as a substitute for DB atomicity across API workers.
Do not assume fs.write_text_atomic implies fsync or crash durability.
Use synchronous_commit=on and test DB restart/failover, dual workers,
unknown commit outcomes, timed-out uploads and orphan blob cleanup.
No public DB privileges; dedicated service role and prepared statements.
Never send bearer tokens, tenant credentials or DB keys to a build worker.

## Trust levels

Authenticated upload -> QUARANTINE_UNTRUSTED_BUILD.
Independent rebuild or verified isolated builder -> eligible for additional
review, but NOT automatically release approved.
Release authority -> separately verifies source tree, actual compiler output,
toolchain, provenance, policy and code signing.

A signed self-report does not prove compilation. A TPM signing key by
itself does not prove that the correct compiler ran. Neither source bundle
nor --check/--build-analysis output is a compiled executable.

## On-device Oreslang build interface — future compiler integration

The desired user command is oreslang build, not oreslang-stack build.
It must compile locally into an actual backend artifact, hash the output,
record pinned source/dependency/toolchain hashes and target ABI, sign the
DSSE in-toto statement with the local device key, and optionally upload
using the short-lived capability over authenticated TLS. Do not put the
capability in command arguments logged by processes, source or artifact.
Each backend (Java/Graal, LLVM, WASM, .NET, Forge) must prove actual artifact
execution, not only analysis. Fail nonzero if unsupported.

The Java OresMain launcher presently supports --check and --build-analysis
rather than a completed artifact emitter. Do not claim oreslang build exists
until implementing and testing real compiler output.

Reference cryptographic validator draft:
https://github.com/ores-truffle-oreslang/oreslang-platform-conformance/pull/223

## Deployment

First deployment should bind 127.0.0.1:3000 behind a trusted TLS reverse
proxy, with Deno-like scoped permissions/flags-2-env, bounded ingress,
rate limits, tenant auth, audit logs without secrets, and readiness probes.
The prototype must remain non-ready while trusted adapters are absent.

Experimental local LLVM AOT build command implementation is drafted in:
https://github.com/ores-truffle-oreslang/oreslang-source.java/pull/2249
This PR is not merged or verified against the actual LLVM compiler yet.


## Zed Package signed-build integration (schema + refusal only)

Draft routes:
- POST /v1/zed/build-challenges
- POST /v1/zed/build-uploads

Both currently return HTTP 503. Migration 002 adds immutable audience binding
zed-pkg/oreslang-build-api/v1 plus required org/package/version fields to
the original one-use challenge rows. PostgreSQL CHECK constraints must not
allow NULL to bypass audience binding.

The Zed signed-build v1 format is domain-separated Ed25519 over the Zed
claims' canonical JSON bytes. It is NOT the DSSE/in-toto envelope used by the
earlier Oreslang reference verifier. A production Oreslang adapter must
explicitly verify whichever versioned signature scheme it accepts, using a
trusted registered key and the original durable server challenge. Never
silently reinterpret one format as another or accept a client-declared
Zed publisher key as an Oreslang-enrolled device key.

The Zed registry's verification endpoint checks active org publisher key
signatures and **actual published artifact bytes**, but its response is only
signed-self-report-not-compiled-proof. It never consumes this API's challenge.
A separate trust decision must verify original challenge, one-time admission,
and actual independently trustworthy compilation evidence before release.

Zed cross-repository draft changes:
- https://github.com/zed-pkg/zed-interfaces/pull/181
- https://github.com/zed-pkg/zed-cli/pull/542
- https://github.com/zed-pkg/zed-api-server.rs/pull/128


## Executable PostgreSQL atomic-admission boundary (migration 003)

`migrations/003_atomic_quarantine_admission.sql` now defines a real
`admit_quarantined_build` PostgreSQL function. It uses an atomic conditional
UPDATE + INSERT to quarantine; two independent database clients cannot both
consume the same challenge. EXECUTE is revoked from PUBLIC and not granted to
the API runtime until authenticated, signature-verified admission is wired.
The function is SECURITY INVOKER and cannot approve a release.

The separately executable `tests/postgres-admission.sh` applies migrations
001-003 to disposable PostgreSQL, seeds active/revoked keys, asserts wrong
tenant and upload-token rejection, NULL Zed package-audience rejection,
two concurrent clients yield exactly one winner, and a fresh-connection
replay fails. The `postgres-admission.yml` workflow exercises this on a
Postgres 16 service. **Passing this database-only test does not prove**
Oreslang HTTP, Ed25519, auth, object-store durability or independent
compilation verification. These remain blocked; /ready and privileged routes
must continue returning 503.


## Hardened database admission v2 (migration 004)

Migration `004_harden_challenge_admission.sql` replaces the draft 003
function with a SECURITY INVOKER operation. It must match the **original
server-issued row** on tenant and enrolled device key; challenge audience;
Zed org, package, and version (null-safe for non-Zed); source commit and
source SHA-256; toolchain SHA-256; target; 32-byte nonce; and upload-token
digest. Admission still requires unconsumed, unexpired state. A row lock
(`FOR SHARE`) on the active device key serializes revocation and admission.

The `postgres-admission.yml` workflow keeps the existing baseline
migration-003 tests and runs `tests/postgres-admission-v2.sh` against a
separate, newly created PostgreSQL 16 database. The v2 suite exercises
cross-audience substitution, cross-package substitution, toolchain/nonce
substitution, a two-client single-use race, persisted replay rejection,
and a concurrent revocation that wins the key lock before admission.

**No result is claimed without executed CI steps.** The migration has no
GRANT to a runtime/API role. HTTP routes remain 503; database admission
does not verify Ed25519 or DSSE, does not stage/rehash the actual artifact,
and does not independently certify compilation. It returns quarantine
identity only. Provision an authenticated Oreslang adapter and least-
privilege SQL rights only after verifying the full chain.
