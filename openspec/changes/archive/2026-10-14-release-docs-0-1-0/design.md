# Design

## Context

See proposal.md for the motivation. Facts the README must state, checked in the code and the example app:
- **Public API:**
  - `LiveTranslateView`: the target defaults to the device language (English if it has no model); Latin and Devanagari are read by default.
  - `LiveTranslateController`: `state`, `lines`, `targetLanguage`, `freeze`, `resume`, `setTargetLanguage`, `setScripts`, `setTorch`.
  - Also `TranslationModels`, `OverlayStyle`, `TranslatedLine`, `TextScript`, and the sealed `LiveTranslateException` with five subtypes.
- **Downloads:**
  - Automatic downloads use any network: `wifiOnly: false` in `LineTranslator`.
  - `TranslationModels.download` defaults to `wifiOnly: true`.
  - Each started download is reported once as `ModelNotDownloaded` through `onError`.
- **Example app's platform setup (it builds today):**
  - **Android:** `minSdk = 24` (the `camera` plugin needs 24; ML Kit needs 21), the `CAMERA` permission, and `com.google.mlkit:text-recognition-devanagari:16.0.1`.
  - **iOS:** `platform :ios, '15.5'`, `NSCameraUsageDescription`, and `pod 'GoogleMLKit/TextRecognitionDevanagari', '~> 9.0.0'`.
- **Behaviour the README must not overpromise:**
  - rear camera only;
  - Latin and Devanagari only;
  - horizontal text (rotated boxes are 1.1);
  - ML Kit needs a real iOS device;
  - each translation model is about 30 MB, so first use needs network.
- **Package files:** the repository is `github.com/AbhiCodebugger/live_translate_overlay`, with `main` as its default branch. `.pubignore` already excludes `openspec/`, `PLUGIN_PLAN.md` and `.claude/`.

## Goals / Non-Goals

**Goals:**
- The Week 4 exit check, proven locally: a fresh `flutter create` app that follows only the README's steps builds for Android and iOS, and runs the quick-start code.
- Every Dart snippet in the README compiles against the current API.
- The CHANGELOG lists what 0.1.0 gives users, not how it was built.

**Non-Goals:**
- Publishing, `topics`, CI, or the dry run (separate Week 4 items).
- Performance and size numbers (Week 5); FAQ and comparison (Week 6).

## Decisions

**D1. The GIF lives in the repository and is linked by absolute URL.**

- **Location:** `doc/images/demo.gif` (`.pubignore` already ignores only `doc/api/`).
- **Link:** `https://raw.githubusercontent.com/AbhiCodebugger/live_translate_overlay/main/doc/images/demo.gif`.
- **Packaging:** add `/doc/images/` to `.pubignore`, so the published archive doesn't carry a multi-megabyte image that pub.dev never serves from the package.
- **Recording guidance for the user:** about 10 seconds, under 5 MB, portrait, trimmed to about 360 px wide. Show a Hindi or Spanish sign translating in place, then a freeze.
- **As built:** the user recorded a 16-second screen video (French into Dutch). At 360 px and 12 fps the GIF was 14.7 MB, so it was converted with ffmpeg at 8 fps, 280 px wide and a 96-colour palette: 4.9 MB, still readable.

Alternatives:
- A relative link. pub.dev resolves those against the repository too, but GitHub-rendered and pub.dev-rendered READMEs then depend on that resolution. An absolute URL works everywhere.
- Shipping the GIF in the package. Rejected for its size.
- `pubspec.yaml` `screenshots`. Possible later; it's a separate pub.dev gallery, not the README's opening image.

**D2. README snippets are compile-checked, not just eyeballed.**

During implementation, every README Dart block is pasted into a throwaway file in `example/lib/`, wrapped in a widget where needed, and `flutter analyze` must report nothing. The file is then deleted. Snippets use only the public import. The `onFrozen` and `overlayBuilder` examples in plan §4.6 are 0.2 APIs and are left out.

**D3. Setup steps are proven on a fresh app.**

In the scratchpad:
1. `flutter create` an app.
2. Add the package by `path:`.
3. Follow the README's Android and iOS steps literally.
4. Paste the quick start.
5. Run `flutter build apk --debug` and `flutter build ios --no-codesign --debug`.

Any step the build needs but the README doesn't say goes into the README. The app is deleted afterwards. Running it on a phone stays the user's check.

**D4. The CHANGELOG has one entry, `0.1.0`.** It replaces the template's `0.0.1`, which was never released. The entry is a short user-facing list: the view, the controller, scripts, automatic language detection and downloads, settle-read-hold, freeze with page colours, models, and errors. It also states the known limitations.

## Risks / Trade-offs

- **[The GIF link 404s until the GIF is pushed to `main`]** → The tasks finish only once the user has added the GIF. The README renders on GitHub after the push, and on pub.dev only at publish time, by which point it's on `main`.
- **[Native version pins drift from the ML Kit plugins (Devanagari 16.0.1, pod ~> 9.0.0)]** → They're copied from the example app, which builds against the current plugins. D3's fresh-app build confirms them again. The README says to match the versions in `google_mlkit_text_recognition`'s own README when upgrading.
- **[An iOS build on this machine may need CocoaPods or Xcode setup unrelated to the package]** → If `flutter build ios` fails for environment reasons, record that in this design and rely on the example app's iOS setup. Don't change the README to suit local tooling.
