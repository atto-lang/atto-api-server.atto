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
