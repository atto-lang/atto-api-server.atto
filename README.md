# Oreslang Verified Build API

Actor-native Oreslang HTTP service in `src/main.ores` for future device-key
enrollment, short-lived build capabilities and one-use quarantine admission.

**Status: intentionally fail-closed draft.** GET /health returns liveness;
GET /ready and ALL privileged endpoints return HTTP 503 while cryptographic,
transactional PostgreSQL and immutable object-storage adapters are missing.
This is not yet a production credential issuer or a compiled guest artifact
verification service.

- [HTTP protocol, trust levels and device build CLI contract](docs/BUILD_API_PROTOCOL_V1.md)
- [PostgreSQL schema and atomic consume/quarantine transaction](migrations/001_device_build_admission.sql)
- [Oreslang native actor HTTP server](src/main.ores)
- [Non-promoting structural security tests](tests/admission-structure.test.mjs)
- [Shared DSSE verifier draft](https://github.com/ores-truffle-oreslang/oreslang-platform-conformance/pull/223)

## Verification

Run `node --test tests/admission-structure.test.mjs` for **structural tests
only**. They do not execute Oreslang or PostgreSQL. Native HTTP runtime
testing must use the real Java/Graal Oreslang compiler with scoped network
permissions, then replay/multi-process tests against PostgreSQL and a signed
artifact verifier. If no real Oreslang runtime is present, do not call the
server runnable or the security API ready.

The intended on-device command is `oreslang build`; neither the existing
`oreslang-stack build` checked-source bundle nor Java `--build-analysis`
is proof of a compiled user artifact. That compiler feature needs a separate
backend implementation and real compiled-binary evidence.
