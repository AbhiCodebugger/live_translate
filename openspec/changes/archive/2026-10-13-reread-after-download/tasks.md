# Tasks

## 1. Reads record the models they lacked

- [x] 1.1 Add `missingModels` (`Set<TranslateLanguage>`, default `const {}`, part of `==`/`hashCode` and documented) to `LineTranslation`. Fill it in `LineTranslator._translateLine` from the source and target readiness checks. In `Pipeline.read`, add each missing model's `bcpCode` to `untranslatedLanguages`, next to today's source tags (design D1). Verify with new cases in `test/pipeline/pipeline_test.dart`, then run `flutter test test/pipeline/` and fix any equality expectations it breaks:
  - target German missing and source Spanish present: the paragraph is untranslated and `untranslatedLanguages` contains `de`;
  - target present and Hindi missing: it stays `{'hi'}` (the existing test);
  - both models present: `untranslatedLanguages` is empty.

## 2. The view re-reads after every completed download

- [x] 2.1 In `_LiveTranslateViewState`, add `_readyDuringRead`. Clear it when a read starts; fill it in `_onModelReady` while `_reading`. When a current read finishes, call `_reread()` if its `untranslatedLanguages` intersects the set (design D2). Verify with new cases in `test/view/live_translate_view_test.dart`, one per `live-translation` delta scenario, using `engines.models.downloadGate`, `engines.reads` and a gated text engine:
  - **target model arrives after switching:** hold Spanish in English, rebuild the widget with German missing, complete the download without delivering moving frames; `engines.reads` goes up by one and the label reads `[de] Salida`;
  - **download finishes during a read:** hold a Hindi paragraph (model downloading) and a Spanish one whose translation is gated (new `FakeTranslateEngine.gate`), complete the Hindi download, then release the gate; one more read follows and both paragraphs are translated;
  - **frozen view:** freeze through the controller, switch to German with the model missing, complete the download; the label reads `[de] Salida` and the state stays `frozen`;
  - **regression:** the existing "a completed download reads the held frame again" (Hindi source) still passes.

## 3. Integration check

- [x] 3.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root, and `flutter test` plus `flutter build apk --debug` in `example/`. Verify all succeed. Then tell the user it's ready for the on-device check: hold the camera on text, pick a target language that isn't downloaded, and the translation should appear once the chip's spinner stops, without freezing or moving.

## Workflow follow-up

- After the on-device check, archive the change, syncing the `live-translation` delta into the main spec.
