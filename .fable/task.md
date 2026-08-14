# Current Task: NoType 0.2.0 Documentation Refresh

## Goal

Bring the project documentation into alignment with the published NoType 0.2.0 release, including friend installation, bundled-model behavior, developer workflows, release operations, limitations, and current architecture.

## Acceptance Criteria

- README contains a reliable direct download link for the published release and exact install steps.
- README clearly states that the model/tokenizer are bundled and that friends do not run a setup script.
- README documents system requirements, permissions, disk space, Gatekeeper behavior, architecture limits, and known limitations.
- README documents test, local build, release build, checksum, signing, and release-upload workflows without developer-only assumptions being presented as friend setup.
- CHANGELOG records the shipped 0.2.0 changes.
- ADR-002 records the published release evidence and remaining notarization follow-up.
- Documentation links and version/release references are internally consistent.

## Requirements List (Append Only)

1. Update the project's README comprehensively for the current release.
2. Update related project documentation that is now stale or incomplete.
3. Explain the friend installation path separately from the developer/build path.
4. Record what is included in the ZIP and what remains unfinished for formal public distribution.
5. Preserve historical design documents and avoid rewriting completed implementation plans.

## Decision Log

- Keep the root README as the canonical user/developer entry point.
- Add a concise CHANGELOG instead of duplicating release notes across multiple documents.
- Update ADR-002 with shipped-release evidence while preserving its original decision and alternatives.

## Evidence

- Published release: `build-2026-08-14` / `NoType 0.2.0`.
- Direct asset: `NoType-0.2.0-arm64.zip`.
- Published release source baseline: `07c6364` on `main` and `origin/main`.
- Root README, CHANGELOG, and ADR-002 updated; all added external links returned HTTP 200 on 2026-08-14.
