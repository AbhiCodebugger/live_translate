## What this changes

<!-- What users get, and why. Link the issue: "Fixes #123". -->

## Type

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change (needs a major version)
- [ ] Docs, tests or tooling only

## Checklist

- [ ] `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test --exclude-tags golden` pass.
- [ ] The example's `flutter analyze` and `flutter test` pass.
- [ ] New behaviour has tests.
- [ ] A behaviour change updates its spec in `openspec/specs/`.
- [ ] A public API or behaviour change updates `README.md` and adds a line under `## Unreleased` in `CHANGELOG.md`.
- [ ] Label painting changes: `flutter test --tags golden` passes on macOS, or the goldens are updated on macOS.
- [ ] Recognition, language detection or translation changes: the replay test passes on a device. Device and result:

## Notes for the reviewer

<!-- Anything tricky, alternatives you rejected, or what you couldn't test. -->
