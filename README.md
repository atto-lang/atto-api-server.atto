# Oreslang Verified Build API

## AttoLang naming and specification migration (2026-11-18)

**AttoLang** is the current name of **Oreslang**. This is a legacy-organization checkout, `ores-truffle-oreslang/oreslang-api-server.ores`, and new corresponding work belongs in [atto-lang/atto-api-server.atto](https://github.com/atto-lang/atto-api-server.atto). Matching names do **not** establish GitHub transfer, identical commits, issues/PRs, release history or feature completeness. Preserve this checkout's historical commands and paths where still applicable.

The **canonical language specification is [atto-spec](https://github.com/atto-lang/atto-spec)**; [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) owns portable executable positive/negative tests, [atto-common-source](https://github.com/atto-lang/atto-common-source) owns portable libraries, and `atto-source.*` owns backend implementation. Modern source targets include `.atto` and `snake_case`, explicit `borrow!`/`take!`/`copy!`/`copy!!`/`share!`, [implicit argument borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [file/module `define const` including one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [`<<<`/`>>>`/`ashr` bitwise shifts vs. `<<`/`>>` directional stream operations](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). They are language contract targets, **not** evidence every legacy backend supports them.

Keep working legacy `.ores`, CLI/package/ABI and wire identifiers until separately verified migrations. No Python tools, scripts or tests for new work; use Rust for support tools where appropriate. Feature parity claims require exact SHA/tree, target/toolchain, real compiled guest execution and positive/negative checks. Empty-step workflows and host-only tests are **not executed** guest parity evidence.

Actor-native Oreslang HTTP service for device-key enrollment and build-capability admission.

Security-critical capability issuance and one-use challenge consumption must fail closed until authenticated cryptographic and transactional-storage adapters have passed integration testing. This repository will not treat a client-signed upload as proof of compilation.

Implementation and rollout work is maintained through draft pull requests.
