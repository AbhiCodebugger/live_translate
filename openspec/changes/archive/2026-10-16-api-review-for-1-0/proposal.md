# Proposal

## Why

1.0 promises a stable API, so anything awkward has to change before it ships. Three parts of today's API don't describe what the package does:

- `TranslatedLine` holds a whole paragraph, not a line. Its `id` is the paragraph's position in each read (`p0`, `p1`…), so it changes from one read to the next even though its documentation says it stays the same. An overlay can't key or animate a paragraph across reads.
- `OverlayStyle.maxFontSize` is validated but unused, and its own documentation says so.
- The controller can change the target and scripts without restarting the camera, but not the expected source languages, which only the widget can set.

## What Changes

- **BREAKING** Rename `TranslatedLine` to `TranslatedParagraph`. For consistent naming, `LiveTranslateController.lines` becomes `paragraphs`, `LiveTranslateView.onLinesChanged` becomes `onParagraphsChanged`, and the `OverlayBuilder` and `onFrozen` callbacks receive `List<TranslatedParagraph>`. There are no deprecated aliases. The CHANGELOG gives the old-to-new mapping.
- **Stable paragraph ids.** A paragraph keeps its `id` when a later read of the same scene finds a paragraph in the same place. This covers a re-read while the language settles, after a download, after a settings change, after a pan, and on freeze. A new scene gets new ids.
- **`OverlayStyle.maxFontSize` caps label size.** Labels still start from the original text's size, but never above `maxFontSize` (default 28). A large heading's label now stops at 28 instead of growing to match the heading.
- **New `LiveTranslateController.setSourceLanguages`.** It changes the expected source languages without restarting the camera, like `setScripts`. The most recent change wins, whether it came from the controller or the widget.
- Docs: correct `TranslatedParagraph.opacity` (it fades when the labels clear, not when a line leaves the frame), and update the README recipes, example app and CHANGELOG to the new names.

Out of scope: the version bump and publishing, other renames (`OverlayStyle`, the errors and `SourceStatus` stay as they are), and new scripts.

## Capabilities

### New Capabilities
- `paragraph-identity`: how a shown paragraph's `id` is assigned and kept across reads.

### Modified Capabilities
- `public-api`: `TranslatedParagraph` replaces `TranslatedLine` in the exports and the value-type requirements, and `maxFontSize` is documented as a cap.
- `controller`: `paragraphs` replaces `lines`, and `setSourceLanguages` joins the settings the controller can change.
- `live-view`: `onParagraphsChanged` replaces `onLinesChanged`, `onFrozen` receives paragraphs, and source languages can change through the controller.
- `overlay-rendering`: the starting font size is capped at the style's maximum, and the app overlay receives `TranslatedParagraph`s.

## Impact

- `lib/src/models/translated_line.dart` is renamed to `translated_paragraph.dart`; `lib/live_translate.dart`.
- `lib/src/controller/live_translate_controller.dart`: `paragraphs` and `setSourceLanguages`, plus the `ControllerHost` interface.
- `lib/src/view/live_translate_view.dart`: id matching, the renamed callback, and source languages becoming effective state like the target and scripts.
- `lib/src/view/paragraph_painter.dart`: the font-size cap.
- `example/lib/` (camera screen, text sheet), `README.md`, `example/README.md`, `CHANGELOG.md`, and the tests that use these names.
- Apps on 0.x must rename their uses, following the CHANGELOG mapping.
