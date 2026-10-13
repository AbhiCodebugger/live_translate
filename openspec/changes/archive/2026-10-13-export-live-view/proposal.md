# Proposal

## Why

The package's main widget isn't public yet. `LiveTranslateView`, `LiveTranslateController` and `LiveTranslateState` are built, tested and checked on both phones, but the entry library doesn't export them. So an app that installs the package can't show a camera view at all. Even the bundled example reaches into `lib/src/` for them. Exporting them is the first Week 4 item and blocks the 0.1.0 README and the publish dry run.

## What Changes

- **Export the view, controller and state** from `package:live_translate_overlay/live_translate_overlay.dart`. Only `LiveTranslateView`, `LiveTranslateController` and `LiveTranslateState` are added. The controller's view-side plumbing (`ControllerHost`, `attachController`, `detachController`, `publishToController`), the camera session, the engines record and its ML Kit factory stay internal.
- **Mark the view's test seams internal.** `createSession`, `createEngines` and `now` stay on the constructor, because the package's widget tests depend on them. They gain `@internal` (from `package:meta`, a new direct dependency), so the analyzer warns any code outside this package that passes them. Their types stay unexported. This replaces `@visibleForTesting`, which only warned outside test folders.
- **`LiveTranslateController.targetLanguage`:** the language the attached view translates into, after the device-language default is applied. It is `null` while no view is attached. Listeners are notified when it changes, including when it first appears after attaching. Apps can show the current target without repeating the view's device-language rule.
- **Example app uses only the public API:**
  - The camera screen reads its default target from `controller.targetLanguage` instead of calling the internal `deviceTargetLanguage`.
  - Its `createSession` and `createEngines` seams, which named internal types, become one test-only view builder.
  - `example/lib/` has no `src/` imports and no `implementation_imports` ignore. The example's tests still use internal fakes, as the package's own tests do.
- **Docs:** the view and controller dartdoc drop "Internal until release 0.1.0".
- Not in this change: the README, the CHANGELOG, the version bump and the rest of Week 4.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-api`: the entry library also exports `LiveTranslateView`, `LiveTranslateController` and `LiveTranslateState`. The view's plumbing and test seams stay hidden from consumers.
- `controller`: the controller reports the view's effective target language.

## Impact

- **Changed code:**
  - `lib/live_translate_overlay.dart` (three `show` exports)
  - `lib/src/view/live_translate_view.dart` (`@internal` seams, publishing the target, dartdoc)
  - `lib/src/controller/live_translate_controller.dart` (`targetLanguage`, publish and detach carry it)
  - `example/lib/camera_screen.dart` (public imports only, target from the controller, view builder seam)
  - `example/test/camera_screen_test.dart` and `example/test/support/fakes.dart` (inject through the builder)
  - `test/public_api_test.dart` and `test/controller/live_translate_controller_test.dart`
- **Public API:** additive: three new exported types and one new getter. Nothing is removed from the public API. The `@internal` seams were never public.
- **Dependencies:** `meta` becomes a direct dependency. It is already resolved transitively through Flutter at 1.18.3.
- **Example behaviour:** unchanged. On the first frame, before the view attaches, the target chip briefly has no language. See design.
