# Tasks

## 1. Report step and `onLinesChanged`

- [x] 1.1 Replace `_schedulePublish` with `_scheduleReport` (design D1). It runs when there is a controller or a callback, publishes to the controller, then calls `onLinesChanged` when the lines differ from the last ones it reported. Add the `onLinesChanged` parameter with dartdoc noting that it fires on every move and fade step (D2). Add `onLinesChanged` to the test `app()` helper. Verify with one test per "Changed lines are reported to the app" scenario in `test/view/live_translate_view_test.dart` (new `group('callbacks')`). Verify that the existing controller tests still pass unchanged.

## 2. `onFrozen`

- [x] 2.1 Add the `onFrozen` parameter and the `_frozenPending` flag, set and cleared as design D3 lists, and fired from the report step only while frozen and not reading. Dartdoc: when it fires, and that a re-read fires it again. Verify with one test per "The frozen result is reported to the app" scenario, including the failed read (via the fake text engine throwing) and resuming before the read finishes.

## 3. `placeholderBuilder`

- [x] 3.1 Add the `placeholderBuilder` parameter and use it in the `!_running` branch of `build` (design D5). Verify with one test per "Custom placeholder while the camera starts" scenario. Use `FakeCameraSession.startGate` to hold the camera in its starting state, `startError` for the error case, and the lifecycle hooks for the restart.

## 4. `overlayBuilder`

- [x] 4.1 Add the public `OverlayBuilder` typedef and the `overlayBuilder` parameter in `live_translate_view.dart`, replacing the `CustomPaint` with a `Positioned.fill` overlay when given (design D4). Dartdoc on both explains that `OverlayStyle` is then unused, that rectangles are in the overlay's coordinates, and that `opacity` should be honoured. Verify with one test per "An app overlay replaces the built-in labels" scenario. Check that no `ParagraphPainter` is in the tree, record the lines the builder receives, and check the overlay's laid-out rect with `tester.getRect`.
- [x] 4.2 Export `OverlayBuilder` by name from `lib/live_translate.dart`. Extend `test/public_api_test.dart` to build a `LiveTranslateView` with an `OverlayBuilder` variable, `onLinesChanged`, `onFrozen` and `placeholderBuilder` through the entry import only. Verify that the test passes.

## 5. Docs

- [x] 5.1 Add README recipes: "Custom labels" (`overlayBuilder` placing each line with `Positioned.fromRect`, honouring `opacity`) and "Act on a freeze" (`onFrozen` opening a sheet of translations), plus a sentence on `placeholderBuilder` and `onLinesChanged`. Add an `## Unreleased` CHANGELOG section listing the four parameters. Verify each new Dart block as in 0.1.0: paste it into a throwaway `example/lib/readme_check.dart`, check that `flutter analyze` in `example/` reports no issues, then delete the file.

## 6. Integration check

- [x] 6.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root and in `example/`. Run `openspec validate custom-overlay-and-callbacks --strict`. Verify that all pass.

## Workflow follow-up

- On-device check by the user: freeze on both test phones with a custom overlay and an `onFrozen` sheet.
- Archive the change once reviewed.
