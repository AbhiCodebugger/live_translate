# Design

## Context

See proposal.md for the motivation. Where the old names appear (tracked files, excluding archived changes):
- **`live_translate_overlay`:**
  - `pubspec.yaml` (name, repository, issue_tracker);
  - the entry library's file name;
  - every package test's import;
  - README (title, install, imports, GIF URL);
  - the `public-api` spec (purpose and two requirements).
- **`live_translate_overlay_example`:**
  - `example/pubspec.yaml`, `example/pubspec.lock` and the example's Dart imports;
  - the Android `namespace` and `applicationId`;
  - the Kotlin folder `kotlin/dev/ranjan/live_translate_overlay_example/` and its `package` line;
  - the Android `android:label`;
  - `example/README.md`.
- **`liveTranslateOverlayExample`:** iOS `PRODUCT_BUNDLE_IDENTIFIER`, six entries in `project.pbxproj` including `.RunnerTests`.
- **"Live Translate Overlay Example":** iOS `CFBundleDisplayName`.

Not tracked, so nothing to change: the `.iml` files and the generated `.dart_tool/`. The tracked `Podfile.lock` and `.metadata` files don't contain the name.

## Goals / Non-Goals

**Goals:**
- After the change, `git grep -I live_translate_overlay` and `git grep liveTranslateOverlay` find nothing outside `openspec/changes/archive/`.
- The package and example analyze, test and build exactly as before.

**Non-Goals:**
- Renaming Dart symbols.
- Rewriting archived changes.
- Renaming the GitHub repository (the user does that in GitHub settings).

## Decisions

**D1. Rename the library with `git mv`, then replace text longest-first.**

`git mv lib/live_translate_overlay.dart lib/live_translate.dart` keeps the file's history. Text replacements run in this order, over tracked files outside `openspec/changes/archive/`:
1. `live_translate_overlay_example` becomes `live_translate_example`;
2. `liveTranslateOverlayExample` becomes `liveTranslateExample`;
3. `live_translate_overlay` becomes `live_translate`;
4. `Live Translate Overlay Example` becomes `Live Translate` (the iOS display name).

Then the Android `android:label` is set to `Live Translate`. Doing it longest-first stops step 3 from leaving a stray `live_translate_example` half-done. The package README's `# live_translate_overlay` title becomes `# live_translate` through step 3.

**D2. Move the Kotlin package folder with `git mv`.**

The folder becomes `kotlin/dev/ranjan/live_translate_example/`. Its `package` line changes through D1's step 1. Android requires the folder to match `namespace`.

**D3. Regenerate rather than hand-edit lockfiles.**

`flutter pub get` at the root and in `example/` rewrites `example/pubspec.lock`'s path-dependency entry. `flutter clean` in `example/` first drops cached build outputs that still carry the old app ID.

**D4. Repository URLs point at the renamed repository.**

`https://github.com/AbhiCodebugger/live_translate` and `…/live_translate/issues`, plus the README GIF at `https://raw.githubusercontent.com/AbhiCodebugger/live_translate/main/doc/images/demo.gif`. The old repository was deleted and git reinitialised locally, so the new repository's remote is added with `git remote add origin https://github.com/AbhiCodebugger/live_translate.git`. There are no redirects from the old name.

## Risks / Trade-offs

- **[A text replacement hits something it shouldn't]** → The only matches are the names listed in Context. Review the diff of every file before committing, and rerun the full test suite and both platform builds.
- **[The example installs as a second app on the phones]** → Expected with new IDs. The user deletes the old "Live Translate Overlay Example" app. iOS automatic signing registers the new bundle ID on first install.
- **[The README GIF and the pubspec URLs 404 until the new repository exists and `main` holds `doc/images/demo.gif`]** → Task 4.2 checks that the GIF URL serves after the first push.
- **[A fresh `git init` loses `.git/info/exclude` and history]** → Nothing private depended on it. `.gitignore` keeps `PLUGIN_PLAN.md` out, and `.claude/` is meant to be tracked (repo-only, excluded from the package by `.pubignore`). Before the first commit, `git status` shows exactly what will be added.
