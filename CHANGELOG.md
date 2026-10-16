## Unreleased

**Breaking:** the API is renamed before 1.0 to say what it holds. Rename:

| Before | After |
|---|---|
| `TranslatedLine` | `TranslatedParagraph` |
| `LiveTranslateController.lines` | `LiveTranslateController.paragraphs` |
| `LiveTranslateView.onLinesChanged` | `LiveTranslateView.onParagraphsChanged` |
| `OverlayBuilder`'s `lines` parameter | `paragraphs` |

The fields of `TranslatedParagraph` are unchanged, and `onFrozen` keeps its name.

* Paragraph ids now stay the same while the view keeps reading a paragraph in the same place: re-reads while the language settles, after a download or a target change, after a small pan, and on freeze. A new scene gets new ids.
* `LiveTranslateController.setSourceLanguages`: change the expected source languages, or go back to detection with `null`, without restarting the camera. The most recent change wins, whether from the controller or the widget.
* `OverlayStyle.maxFontSize` now caps a label's starting size (default 28). Large headings that used to get labels as big as the heading now stop at 28; raise `maxFontSize` to get them back.

* `LiveTranslateView.overlayBuilder`: draw the translations yourself. The new `OverlayBuilder` receives the shown lines, in the view's coordinates, and replaces the built-in labels.
* `LiveTranslateView.onLinesChanged`: called whenever the shown lines change, with or without a controller.
* `LiveTranslateView.onFrozen`: called with the frozen picture's lines once its translation is shown, and again if it is read again.
* `LiveTranslateView.placeholderBuilder`: shown while the camera starts, in place of the progress indicator.
* `PipelineMetrics` and `LiveTranslateController.metrics`: how long each shown read took (recognition, translation, colour sampling and total), how many paragraphs it translated, and whether it was frozen.
* `LiveTranslateView.showDebugHud`: a small panel over the camera with the latest read's timings and the frame rate, for development.
* `SourceStatus` and `LiveTranslateController.sourceStatus`: where finding the source language stands (searching, guessed, downloading, ready, unsupported, not found or download failed), to show progress before the first translation.
* A steady picture whose language isn't settled is read again every second, so short text confirms its language without moving the phone. After three reads that find no language, the status says so.
* Languages that can't be translated, such as lorem ipsum identified as Latin, no longer outvote a translatable language in the same script.
* A Devanagari paragraph identified only as a language ML Kit can't translate, such as a Hindi sign taken for Nepali, is now translated from Hindi or Marathi instead of being left untranslated. Before, a short Hindi sign could show nothing at all.

## 0.1.0

First preview release.

* `LiveTranslateView`: a camera view that recognises text, translates it on the device and paints the translation over the original, in place.
  * Reads once the picture holds still and keeps the result on the page while the camera moves a little. A fast movement or a new scene fades the labels out.
  * Translates whole paragraphs and draws them in the colours sampled from the page, with `OverlayStyle` as the fallback.
  * Reads Latin and Devanagari text at the same time. Choose with `scripts`, and expect specific languages with `sourceLanguages`.
  * Translates into the phone's language by default, or into `targetLanguage`. Right-to-left targets are drawn right to left.
* `LiveTranslateController`: reports `state`, the shown `lines` and the `targetLanguage`. It also freezes and resumes, changes the target and scripts without restarting the camera, and turns the torch on and off.
* Language detection per paragraph, with translation models downloaded automatically: the target at once, a detected language once confirmed. Paragraphs appear as soon as their model arrives.
* `TranslationModels`: check, download and delete translation models from your own UI.
* `LiveTranslateException`: a sealed set of errors (`CameraPermissionDenied`, `CameraUnavailable`, `ModelNotDownloaded`, `UnsupportedLanguagePair`, `PipelineFailure`), delivered through `onError`.
* Known limitations: rear camera only, Latin and Devanagari only, horizontal text only, and a real device is needed on iOS.
