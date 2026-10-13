# Design

## Context

See proposal.md for the motivation. What exists now:
- `lib/live_translate_overlay.dart` exports the models, errors, `TranslationModels`, `TranslateLanguage` and `ResolutionPreset`.
- `lib/src/view/live_translate_view.dart` declares:
  - `LiveTranslateView`, whose dartdoc says it is internal until 0.1.0;
  - the `LiveTranslateEngines` record typedef;
  - `mlKitEngines()`.
  - The constructor's test seams are `@visibleForTesting`: `createSession` (returns `CameraSession`, internal), `createEngines` (returns `LiveTranslateEngines`, internal) and `now`.
- `lib/src/controller/live_translate_controller.dart` declares:
  - `LiveTranslateController`;
  - the `ControllerHost` interface;
  - the library-level `attachController`, `detachController` and `publishToController`. These reach the controller's private fields because they share its library.
- The view publishes `state` and `lines` to its controller in a post-frame callback (`_schedulePublish`), because listeners may call `setState`. It resolves its target in `initState` from the widget's `targetLanguage`, or else from `deviceTargetLanguage(platformDispatcher.locale)`, and keeps it in `_target`.
- `example/lib/camera_screen.dart` imports four `src/` files, under an `implementation_imports` ignore:
  - the view and the controller, which are about to become public;
  - `camera_session.dart`, only to type its `createSession` test seam;
  - `device_language.dart`, to start its target chip at the device language.
- `example/test/camera_screen_test.dart` passes fake sessions and engines through `CameraScreen`. It also imports `src/` files for engine and painter types.
- `meta` 1.18.3 is resolved transitively through Flutter, but isn't a direct dependency.

## Goals / Non-Goals

**Goals:**
- An app using only the entry library can build, drive and observe the live view.
- `example/lib/` compiles with no `src/` import and no lint ignores for internal imports.
- The exported surface is exactly plan §4 as built (see `public-api`), with nothing extra leaking through `export`.

**Non-Goals:**
- Making engines or camera sessions pluggable for consumers (plan §2 "Revisit if"). The seams stay internal.
- Removing `src/` imports from the example's *tests*: fakes of internal interfaces are expected there.
- README, CHANGELOG, version bump, CI and the other Week 4 items.

## Decisions

**D1. Export with `show` lists.**

```dart
export 'src/controller/live_translate_controller.dart' show LiveTranslateController;
export 'src/controller/live_translate_state.dart' show LiveTranslateState;
export 'src/view/live_translate_view.dart' show LiveTranslateView;
```

The controller and view libraries also declare `ControllerHost`, the attach/publish functions, `LiveTranslateEngines` and `mlKitEngines`, so `show` is required, not stylistic. Alternative: move the plumbing into separate libraries and export the files whole. Rejected: the attach functions must share the controller's library to reach its private fields. `show` states the contract in one place.

**D2. Seams use `@internal` from `package:meta`.**

Apply `@internal` to the three seam fields and their constructor parameters, replacing `@visibleForTesting`. The analyzer then reports `invalid_use_of_internal_member` for uses outside this package. Tests inside the package aren't affected, test folders elsewhere still are, and consumers can't name the types anyway. Add `meta` as a direct dependency (`^1.16.0`, which Flutter's pinned 1.18.3 satisfies), since `depend_on_referenced_packages` requires it once `lib/` imports it.

Alternatives (offered to the user and declined):
- Keep `@visibleForTesting`: example `lib/` would keep importing `camera_session.dart`.
- Export the seam types: a larger surface to keep stable before 1.0.

`now` only uses public types, but it is a test seam like the other two, so it gets the same marking.

The dartdoc of each seam says it is for this package's tests. Checked with `dart doc` (task 1.2): the seam fields get no property pages, but the constructor signature still lists `createSession`, `createEngines` and `now`, so the "for this package's tests only" comment is what readers see.

**D3. The controller learns the target through the existing publish.**

`publishToController` gains a required `target` (`TranslateLanguage`). The equality check that skips no-op notifications compares it too. `detachController` resets it to `null` together with state and lines. The getter returns the published value.

Because publishing is already post-frame, `targetLanguage` is `null` during the first frame and appears with the first publish. This avoids notifying during `initState`, which would make a listener's `setState` throw during build.

Alternative: a getter that reads `_host.target` live. Rejected:
- it would change without notifying;
- it would disagree with `state` and `lines` for up to a frame.

**D4. The example's target: the user's choice, else the controller's.**

`_CameraScreenState` replaces `late TranslateLanguage _target` with `TranslateLanguage? _chosenTarget`, which is null until the user picks. It passes `_chosenTarget` to the view, so a `null` lets the view apply its device-language rule: one rule in one place. The chip and the picker's `selected` use `_chosenTarget ?? _controller.targetLanguage`.

The chips' download indicators, which split pending models into the target's and the others', use the same expression.

The `example-app` spec's behaviour is unchanged. Its "Starting target language" scenarios hold once the first frame has published.

Alternative: keep reading the locale in the example. Rejected: it duplicates the view's rule, which is the reason for the getter.

**D5. The example's test seam is one view builder.**

`CameraScreen` drops `createSession` and `createEngines`. It gains:

```dart
@visibleForTesting
final LiveTranslateView Function({
  required LiveTranslateController controller,
  required TranslateLanguage? targetLanguage,
  required Set<TranslateLanguage>? sourceLanguages,
  required Set<TextScript> scripts,
  required ResolutionPreset resolution,
  required ValueChanged<LiveTranslateException> onError,
})? buildView;
```

When `buildView` is null, the screen calls the `LiveTranslateView` constructor with those arguments. Tests pass a closure that builds the same view plus the fake `createSession`, `createEngines` and `now`, ignoring `invalid_use_of_internal_member` in the test file only. `models` stays as is, since `TranslationModels` is public.

Alternatives:
- Typing the seams with exported types (not available, see D2).
- `Widget Function(Widget)` wrapping. Rejected: tests need to construct the view, not wrap it.

## Risks / Trade-offs

- **[`@internal` on a field-formal named parameter isn't checked at call sites, or `invalid_internal_annotation` rejects it]** → Task 1.1 verifies this first, with a scratch consumer outside the package. Fallback: keep `@visibleForTesting` on the seams as well. The example `lib/` no longer passes them after D5, so it still needs no ignore, and the types remain unexported.
- **[A one-frame empty target chip in the example]** → Acceptable for a demo. A widget test pins the chip's text after the first pump. If it shows on device, the chip can render its last label width with no text.
- **[Consumers see seam parameters in the constructor's signature]** → Documented as package-internal. The analyzer warns if they're used. The types can't be named outside the package, so in practice they can only pass `null`.
- **[Export list drifts from the spec]** → `test/public_api_test.dart` resolves every exported type through the entry library alone. The `show` lists make additions deliberate.

## Migration Plan

None: nothing public is removed. The example changes in the same commit.
