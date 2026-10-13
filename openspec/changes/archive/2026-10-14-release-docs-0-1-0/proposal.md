# Proposal

## Why

The package's public API is now complete for 0.1.0, but its README is still the `flutter create` template, apart from one Devanagari setup snippet. Its CHANGELOG reads "TODO: Describe initial release." The README is the pub.dev landing page, and the plan's Week 4 exit check is that 0.1.0 "installs into a fresh Flutter app with only the README's steps". So the README has to carry the whole setup.

## What Changes

- **README v1**, replacing the template:
  - one line on what the package does, and a demo GIF;
  - features;
  - install;
  - platform setup for Android and iOS (camera permission, minimum OS versions, the Devanagari recognizer, real device only);
  - quick start, and recipes: Hindi signage, freezing through the controller, managing models from your own UI, handling errors;
  - supported scripts and languages, and how models download;
  - limitations;
  - a short "how it works";
  - license.
- **Demo GIF:**
  - the user records it from the example app on their phone;
  - it lives in the repository at `doc/images/demo.gif`;
  - the README links it by its GitHub URL;
  - it's excluded from the published package (`.pubignore`).
- **CHANGELOG:** a 0.1.0 entry describing the first release. It replaces the 0.0.1 template entry, since 0.0.1 was never published.
- **Version:** `pubspec.yaml` goes from `0.0.1` to `0.1.0`. Nothing is published by this change.
- Not in this change:
  - measured performance and size tables (Week 5);
  - FAQ and comparison with alternatives (Week 6);
  - `topics`, CI and the publish dry run (separate Week 4 items);
  - dartdoc beyond what exists.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This change is documentation and package metadata only; no behaviour changes, so it sets `skip_specs: true`.

## Impact

- **Changed files:** `README.md`, `CHANGELOG.md`, `pubspec.yaml` (version) and `.pubignore` (the GIF folder).
- **New file:** `doc/images/demo.gif`, supplied by the user.
- **Code and public API:** unchanged.
- **Depends on the user:** recording the GIF. The change isn't complete until it's in place.
