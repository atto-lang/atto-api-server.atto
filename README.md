> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/atto-lang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# atto-api-server.atto

Reference API server implementation and backend application patterns for AttoLang.

## Naming migration and language authority

This repository is maintained at [atto-lang/atto-api-server.atto](https://github.com/atto-lang/atto-api-server.atto); use `https://github.com/atto-lang/atto-api-server.atto.git` for Git remotes and canonical `.atto` source examples. The normative language contract is [atto-spec](https://github.com/atto-lang/atto-spec), with executable guest evidence tracked by [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance). Follow current ownership, borrowing, effects, actor, and syntax rules there; do not infer implemented features from a README or unexecuted CI.

## Project scope

API handler architecture, actor integration, and service lifecycle.

## Development and validation

Document the specific `.atto` source, expected results, supported backend/toolchain, and commands that have been executed.

## Status

This is a statement of intended scope, not a claim of completed implementation or production readiness. Source, CI, and checked-in examples are authoritative for actual supported features and commands.

## Ecosystem

- [AttoLang organization](https://github.com/atto-lang)
- [Language specification](https://github.com/atto-lang/atto-spec)
- [Platform conformance](https://github.com/atto-lang/atto-platform-conformance)

## Repository ownership and contribution routing

**Belongs here:** An idiomatic AttoLang API server application, handler lifecycle, request validation, actor coordination and documented host/deployment fixtures.

**Belongs elsewhere:** Routing library in atto-http-routing; simple pedagogical server in atto-demo-restful-server; cloud ingress/hosting in atto-co.

**Security and portability boundary:** Keep async-only I/O, request borrow windows, authentication/capability checks, bounded bodies and clean cancel/shutdown paths.

AttoLang is the canonical project name; new source, examples and documentation use `.atto` and the `atto-lang` repository organization. This README defines scope, not feature readiness.

**Acceptance:** name exact source SHA/tree, runtime/toolchain, positive and negative checks and execution receipt before claiming support. Host-only tests and empty CI steps do not prove guest execution.

## Legacy migration provenance and gates

The original `ores-truffle-oreslang/oreslang-api-server.ores` repository is archived; this repository imported its history rather than transferring the original numeric repository ID. Historical `.ores` examples and legacy package or CLI references are not evidence of current `.atto` compatibility. Verify any conversion against the normative specification and an executing compiler before claiming parity.

[atto-lang](https://github.com/atto-lang) owns language and guest application examples; [atto-co](https://github.com/atto-co) owns production multi-tenant infrastructure, registry, deployment, identity and billing. Any future managed-product carve-out or original-ID transfer requires separate owner authorization. For an actual transfer, inventory history, exact tree, repository ID, protections, PRs, releases, packages, permissions, CI/runners, secrets, webhooks, integrations and dependencies; verify preservation and retest consumer references afterward. Never disclose or mirror private source without authorization.

Security-critical capability issuance and one-use challenge consumption must fail closed until authenticated cryptographic and transactional-storage adapters pass integration tests. A client-signed upload is not proof of compilation. CI with no executed steps is not executed evidence.

## Verified build API scaffold (legacy source, not runnable evidence)

The imported `src/main.ores` is a historical actor HTTP scaffold, not a verified current AttoLang guest. Its intended behavior is loopback-only liveness at GET /health and HTTP 503 for GET /ready and all privileged operations. Authentication, device-key proof, secure randomness, the database adapter, DSSE verification and immutable object storage are not wired. A signed upload is an untrusted self-report, never release authority.

- [Protocol and trust contract](docs/BUILD_API_PROTOCOL_V1.md)
- [Initial PostgreSQL schema](migrations/001_device_build_admission.sql) and [hardened admission](migrations/004_harden_challenge_admission.sql)
- [Legacy HTTP scaffold](src/main.ores)
- [Structural tests](tests/admission-structure.test.mjs)

Run `node --test tests/admission-structure.test.mjs` for source assertions only. Run `bash tests/postgres-admission.sh` and `bash tests/postgres-admission-v2.sh` with separate fresh disposable PostgreSQL databases via DATABASE_URL for database-only evidence. Neither suite executes the guest. A current compiler, live HTTP tests, authenticated tenant/device verification, durable replay/race and crash recovery, verified quarantine and independent release attestation remain merge gates for the security feature. Historical `oreslang build` is a proposed artifact-emitting command, not evidence that checked-source bundles or build analysis emit executable artifacts.
