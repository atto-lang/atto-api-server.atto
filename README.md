# Oreslang Verified Build API

Actor-native Oreslang HTTP service for device-key enrollment and build-capability admission.

Security-critical capability issuance and one-use challenge consumption must fail closed until authenticated cryptographic and transactional-storage adapters have passed integration testing. This repository will not treat a client-signed upload as proof of compilation.

Implementation and rollout work is maintained through draft pull requests.

## Repository ownership and migration (2026-11-08)

This original `ores-truffle-oreslang/oreslang-api-server.ores` repository is still in the Oreslang organization. The public name of the language is **AttoLang**; retain working `.ores` source and existing package, CLI and repository references until an individually verified migration.

- **This repository contains/should own:** AttoLang API-server guest examples, request/response policy and security fixtures.
- **Do not place here:** commercial API gateway management or production availability guarantees.
- **Responsibility split:** [atto-lang](https://github.com/atto-lang) owns the language, portable source libraries and demonstrators; [atto-co](https://github.com/atto-co) owns production multi-tenant cloud infrastructure, deployment, registry, identity and billing. The presence of similarly named `atto-*` repos does not certify transferred source identity or guest parity.
- **Proposed first destination:** `atto-lang/oreslang-api-server.ores` via owner-approved GitHub transfer of the **existing numeric repo ID and complete history**, preserving the old repo name. No direct legacy-org transfer to `atto-co` is authorized; later managed-product carve-outs need separate approval.

**Safe transfer steps:** coordinate in [issue #26](https://github.com/ores-truffle-oreslang/.github/issues/26) and use private [transfer runbook draft #25](https://github.com/ores-truffle-oreslang/.github/pull/25). Identify source/target admins, an independent security reviewer and rollback owner; capture exact head SHA/tree, numeric ID, branch protections/rulesets, PRs, releases, packages, permissions, Actions/runners, secrets, webhooks, GitHub Apps, Pages and dependencies. Never mirror private source without authorization. After real transfer, verify same ID/history/tree and permissions, migrate consumer references separately, then test the exact new head with executed CI steps. Zero-step jobs (`steps=[]`/`null`) are `NOT_EXECUTED`, and host-only/static tests do not prove native guest execution or production server capability.
