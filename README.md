# atto-api-server.atto

Reference API server implementation and backend application patterns for AttoLang.

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

AttoLang is the public name; preserve existing Oreslang/.ores compatibility and use canonical .atto for new portable library source. This README defines scope, not feature readiness.

**Acceptance:** name exact source SHA/tree, runtime/toolchain, positive and negative checks and execution receipt before claiming support. Host-only tests and empty CI steps do not prove guest execution.
