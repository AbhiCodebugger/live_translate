# Tasks

## 1. Rename TranslatedLine to TranslatedParagraph

- [x] 1.1 Move `lib/src/models/translated_line.dart` to `translated_paragraph.dart` and rename the class, its docs ("one paragraph of camera text"; `id` stays the same while the paragraph is read in the same place; `opacity` drops as the labels clear) and `toString`, and update the export in `lib/live_translate.dart`; move `test/models/translated_line_test.dart` to `translated_paragraph_test.dart`. Verify `flutter analyze` is clean and the renamed model test passes
- [x] 1.2 Rename `LiveTranslateController.lines` to `paragraphs`, `LiveTranslateView.onLinesChanged` to `onParagraphsChanged`, and the `OverlayBuilder` parameter to `paragraphs`, updating every use in `lib/` and the tests (controller, view, public API); verify with `grep -rn "TranslatedLine\|onLinesChanged\|\.lines\b" lib test` finding no public-API uses, the "One import is enough" test asserting `TranslatedParagraph` resolves, and `flutter test` passing
- [x] 1.3 Update the example app (`camera_screen.dart`, `text_sheet.dart` and their tests) to the new names; verify `flutter analyze` and `flutter test` pass in `example/`
- [x] 1.4 Update `README.md` (freeze recipe, `onFrozen` recipe, overlay recipe and anything else naming the old API) and `example/README.md`, and add a CHANGELOG entry with the old-to-new mapping marked as breaking; verify `grep -n "TranslatedLine\|onLinesChanged\|controller.lines" README.md example/README.md` finds nothing outside the CHANGELOG mapping

## 2. Stable paragraph ids

- [x] 2.1 In `LiveTranslateView`, assign ids when a result is shown, using overlap matching against `_previous` (design §2), with `_nextId` for new ids; capture `_previous` before a result changes, including in `freeze()` before `_shown` is cleared; clear it on a clear, camera start or stop, and resume; keep it on a settings change. Build `TranslatedParagraph`s in `build()` from the stored ids. Verify with new `test/view/live_translate_view_test.dart` cases for each `paragraph-identity` scenario: a re-read while unsettled keeps the id, a new target keeps it, a pan with 60% overlap keeps it, a non-overlapping paragraph gets a never-seen id, the 90%/55% tie-break, a new scene gets new ids, freezing a held view keeps the id, and ids are unique within a result
- [x] 2.2 Document stable ids in the README's custom-overlay recipe (an id can key a widget across reads) and in the `TranslatedParagraph.id` dartdoc; verify the README states when ids stay the same and when they change

## 3. maxFontSize cap

- [x] 3.1 Cap the starting size in `paragraph_painter.dart` at `floor(maxFontSize)` (design §3) and update the `maxFontSize` dartdoc; verify with `test/view/paragraph_painter_test.dart` cases "Large heading" (50 high starts at 28) and "Larger maximum" (maximum 48 starts at 40), and that `flutter test` passes, including goldens (regenerate any golden whose heading was over 28 only after viewing the new image)
- [x] 3.2 Note in `README.md` that labels never exceed `OverlayStyle.maxFontSize` (default 28), and add it to the CHANGELOG entry; verify both mention the cap

## 4. Controller source languages

- [x] 4.1 Make source languages effective view state like `_scripts`, add `setSourceLanguages` to `ControllerHost` and `LiveTranslateController` (with dartdoc), and route the pipeline through it (design §4); verify in `test/controller/live_translate_controller_test.dart` that the call is forwarded, and in `live_translate_view_test.dart` that setting Hindi replaces the engines and skips identification, `null` goes back to detection, a later widget change wins, and equal sets keep the engines
- [x] 4.2 Mention `setSourceLanguages` in the README's controller description and the CHANGELOG; verify both list it

## 5. Integration checks

- [x] 5.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the root and in `example/`, `dart pub publish --dry-run` at the root, and `openspec validate api-review-for-1-0 --strict`; verify all pass
- [x] 5.2 Hand the build to the user for a manual check on the Samsung Galaxy: labels on a page held still don't flicker between re-reads, a large heading's label is no bigger than 28, and the example app still freezes, copies text and changes languages
