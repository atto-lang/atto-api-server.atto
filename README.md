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
