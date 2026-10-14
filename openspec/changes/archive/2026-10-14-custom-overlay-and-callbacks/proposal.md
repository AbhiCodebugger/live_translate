# Proposal

## Why

0.1.0 draws its labels one way and tells the app about results only through a `LiveTranslateController`. Apps that want their own label look, want to react when a freeze has been translated (for example to open a copy sheet), or want their own loading screen have no way to do it. These four view parameters were promised for 0.2.0 and are the first part of that release.

## What Changes

- **`overlayBuilder`**: a new `LiveTranslateView` parameter of the new exported type `OverlayBuilder` (`Widget Function(BuildContext, List<TranslatedLine>)`). When given, it replaces the built-in paragraph labels: it is laid over the whole view and receives the lines the controller would report, with rectangles in the view's coordinates. The camera preview and the progress indicator during a frozen read stay.
- **`onLinesChanged`**: called with the shown lines whenever they change, the same changes a controller's listeners hear (new results, labels following the camera, fades, clearing). Works without a controller.
- **`onFrozen`**: called with the frozen picture's lines once its result is known: right away when the held labels are kept, after the read otherwise, and again when the frozen picture is read again after a settings change or a model download. Not called when the read fails.
- **`placeholderBuilder`**: a `WidgetBuilder` shown in place of the default progress indicator while the camera starts or restarts. Camera errors are still shown as today.
- Dartdoc, README recipe and an unreleased CHANGELOG entry for the four parameters.

Not in this change: `PipelineMetrics` and the debug HUD, the example app's additions, replay tests, measurements and the 0.2.0 publish. They follow as separate changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `live-view`: new requirements for reporting changed lines, reporting the frozen result, and a custom placeholder while the camera starts.
- `overlay-rendering`: new requirement that an app-provided overlay replaces the built-in labels.
- `public-api`: "Single entry library" also lists `OverlayBuilder`.

## Impact

- **Changed code:**
  - `lib/src/view/live_translate_view.dart` (four parameters, the `OverlayBuilder` typedef, post-frame reporting that no longer depends on a controller)
  - `lib/live_translate.dart` (export `OverlayBuilder`)
  - `test/view/live_translate_view_test.dart`, `test/public_api_test.dart`
  - `README.md`, `CHANGELOG.md`
- **Public API:** additive only. Existing code compiles and behaves the same.
- **Dependencies:** none.
