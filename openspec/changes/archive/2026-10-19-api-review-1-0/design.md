# Design

## Context

See proposal.md for why. The state of each item in the code today:
- **`TextScript`** is an enum. Internally `engines/mlkit/script_mapping.dart` maps it with an exhaustive `switch` expression, `engines/multi_script_text_engine.dart` iterates `TextScript.values`, and `engines/line_filter.dart` and `pipeline/line_translator.dart` use it as map keys and constants.
- **`TranslatedParagraph.sourceLanguage`** is copied in `live_translate_view.dart` (around line 977) from the internal `ReadParagraph.sourceLanguage`, a BCP-47 `String?`. A `ReadParagraph` only exists for a translated paragraph, and translation only runs once `BCP47Code.fromRawValue(source)` gives a language (`line_translator.dart`, `_translateLine`). So every shown paragraph's tag parses.
- **The camera session** is `late final`, created once in `initState` from `widget.resolution` through the `createSession` seam, with `_frameSubscription` on its frames. Lifecycle restarts use `_stop()` and `_start()` on the same session. `_start()` already clears labels, leaves freeze and shows the placeholder (`_running = false`). Frames carry a `generation`, and stale ones are dropped.
- **The controller** gets its state through `_publish(state, paragraphs, target, sourceStatus)`, called from `reportToController`.

## Goals / Non-Goals

**Goals:**
- Every change compiles existing apps unchanged, except the two listed breaks: a `switch` expression over `TextScript`, and code that reads or builds `TranslatedParagraph.sourceLanguage` as a `String`.
- Internal code keeps BCP-47 strings where untranslatable languages can occur (`ReadParagraph`, `LineTranslation`, `SourceUnsupported`, `UnsupportedLanguagePair`).

**Non-Goals:**
- Changing the camera plugin wrapper's API beyond what the restart needs.
- Any behaviour change besides the resolution restart.

## Decisions

### 1. `TextScript` is a final class with a private const constructor
`final class TextScript { const TextScript._(this.name); final String name; static const latin = TextScript._('latin'); static const devanagari = TextScript._('devanagari'); static const List<TextScript> values = [latin, devanagari]; toString => 'TextScript.$name'; }`. It doesn't override `==`: identity equality keeps the constants usable in const sets and as map keys, and there is exactly one instance of each. Internal `switch` expressions become map lookups or `if` chains with a `StateError` for an unknown script, which can't happen until a script is added.
- **Why:** Scripts can be added in 1.x without breaking consumers' exhaustive switches, the dot syntax and `values` keep working, and outside code can't create a script.
- **Alternative:** Keep the enum and add new scripts only in 2.0. Then CJK, planned for 1.1, would force a major version.
- **Alternative:** Keep the enum and document "may grow". Dart would still flag every exhaustive switch as an error on upgrade, which is a semver break whatever the docs say.

### 2. The view converts the tag once, when it builds `TranslatedParagraph`
`sourceLanguage: BCP47Code.fromRawValue(paragraph.sourceLanguage!)!`, with a comment pointing at the invariant. `ReadParagraph` keeps its `String?`, because the replay test and the still path compare tags. The constructor parameter becomes `required TranslateLanguage sourceLanguage`.
- **Why:** The conversion happens at the one boundary, and the internal types don't churn.
- **Alternative:** Make `ReadParagraph.sourceLanguage` a `TranslateLanguage` too. That touches the pipeline, still translation and the replay matching for no public gain.

### 3. A resolution change replaces the camera session
`_session` stops being `late final`. In `didUpdateWidget`, when `resolution` differs, the view calls `_restartCamera()`:
1. Cancel the frame subscription, stop and dispose the old session.
2. Create the new one through the same `createSession` seam (or `PluginCameraSession`) with the new resolution, and subscribe to its frames.
3. Run `_start()`, unless the app is in the background (`_suspended`). In that case the resume path starts the new session.

Restarts run one after another through a future chain, so quick repeated changes end on the latest resolution. The pipeline and engines are untouched.
- **Why:** It reuses the start path that already gives the restart behaviour the spec asks for (placeholder, cleared labels, leaving freeze, torch off). The test seam already takes the resolution, so tests can check which resolutions sessions were created with.
- **Alternative:** A `setResolution` on `CameraSession`. That's simpler for the view, but every session and fake would need a new method, and the plugin controller has to be rebuilt either way.

### 4. Controller getters are published with the rest of the state
`_publish` gains `scripts` and `sourceLanguages`. The view already calls `reportToController` after any settings change, so the getters follow both the widget and the controller. The controller stores unmodifiable copies (`Set.unmodifiable`). Both are `null` until the view's first report and after detaching, matching `targetLanguage`. For `sourceLanguages`, `null` also means "detecting", which the dartdoc states. An app that needs to tell the two apart checks `scripts`, which is non-null whenever attached.
- **Alternative:** A separate `isAttached` flag. That's more API for a rare need.

### 5. `OverlayStyle.copyWith` goes through the constructor
`copyWith` passes each field or its current value to `OverlayStyle(...)`, so the font-size asserts apply. `toString` lists all seven fields.

### 6. Docs and migration
- The README's API section gets:
  - the new `TranslatedParagraph.sourceLanguage` type
  - the controller getters
  - `copyWith`
  - the sealed-type and `TextScript` policy, in one short paragraph under "Other types"
  - a `resolution` row that drops the `key` advice
- The CHANGELOG's Unreleased entry gets a "Breaking" section with a before/after table, like 0.2.0's.

## Risks / Trade-offs

- [The `!` conversion in the view throws if the invariant ever breaks] → A test reads a shown paragraph's `sourceLanguage` through the real pipeline with fakes. A debug assert message names the tag, so a break shows up in tests, not as a vague null error.
- [A camera restart from a resolution change while a read runs] → `_start()` bumps nothing by itself, so the restart also bumps `_readToken` (as `resume` does), and stale frames are dropped by `generation` across sessions. A widget test changes resolution mid-read and checks that the old read's result isn't shown.
- [Identity equality on `TextScript`] → There's only one instance of each constant, and the constructor is private, so identity and value equality coincide.

## Migration Plan

Apps upgrading to 1.0.0:
- `paragraph.sourceLanguage` is now a `TranslateLanguage`: use `.bcpCode` where a string was used, and drop null checks.
- Tests that build `TranslatedParagraph` pass `sourceLanguage: TranslateLanguage.x`.
- A `switch` expression over `TextScript` needs a `_` case.

The CHANGELOG lists all three.
