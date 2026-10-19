## 1.0.0

The first stable release: from here on, breaking changes come only in a major version.

**Breaking:** two API changes from the 1.0 API review. Most apps need no changes.

| Before | Now | What to change |
|---|---|---|
| `TranslatedParagraph.sourceLanguage` was a `String?` BCP-47 code | a non-null `TranslateLanguage` | Use `.bcpCode` where a string was used, drop null checks, and pass `sourceLanguage:` when building one in tests. |
| `TextScript` was an enum | a final class with constants | Nothing for `TextScript.latin`, `TextScript.devanagari`, `values` or `name`. A `switch` expression over a `TextScript` needs a `_` case. |

`LiveTranslateException` and `SourceStatus` stay sealed. New subtypes will come only in a major version, while new scripts can come in a minor one.

Fixed:

* iOS: model downloads now finish. `google_mlkit_translation` never reports the end of a download on iOS, so the live view stayed on "downloading", the held picture wasn't read again when its model arrived, and `TranslationModels.download` hung or threw `ModelNotDownloaded` for a model that did download. On iOS, a download now completes once its model is on the device, checked once a second, and fails if the model hasn't arrived after 5 minutes. Android is unchanged.
* iOS: `TranslationModels.download`'s `wifiOnly` has no effect there, because ML Kit always downloads on any network. The README and API docs now say so.

New:

* Changing `LiveTranslateView.resolution` restarts the camera at the new resolution. Before, the change was ignored until the camera restarted for another reason.
* `LiveTranslateController.scripts` and `sourceLanguages`: what the view reads and expects, whether set through the widget or the controller.
* `OverlayStyle.copyWith` and `toString`.
* The debug HUD shows the view's own work per camera frame, as `N fps · frame A.A ms avg, W.W max`: measuring how the picture moved and deciding whether to read, over the last second.
* Labels repaint faster while the camera moves: their text layouts are kept between frames instead of being measured again (about 2.6× faster on the host benchmark). Picking up the page's colours is about 20% faster. Neither changes what's drawn.
* README: reorganised, with badges, a contents list, an API section covering every parameter of `LiveTranslateView`, `LiveTranslateController`, `TranslatedParagraph` and `OverlayStyle`, a comparison with alternatives, an FAQ and a contributing guide.
* README: new Performance section with read times, frame cost, jank and memory on a Samsung Galaxy M17 and an iPhone 14, and how to measure them; new Size impact section, with `tool/size_impact.sh` to measure it again.
* README: Latin-only Android apps need `-dontwarn com.google.mlkit.vision.text.devanagari.**` in `proguard-rules.pro`, or release builds fail in R8.

## 0.2.1

Docs only; no code changes.

* Android setup: release builds need three ProGuard rules. Without them, `flutter build apk --release` fails with "Missing classes detected while running R8", because `google_mlkit_text_recognition` refers to the Chinese, Japanese and Korean recognizers that apps don't include. The README shows the `android/app/proguard-rules.pro` to add, and the example app now has it.

## 0.2.0

**Breaking:** two names from 0.1.0 are renamed before 1.0 to say what they hold. Each item is a paragraph of text, not a single line:

| 0.1.0 | 0.2.0 |
|---|---|
| `TranslatedLine` | `TranslatedParagraph` |
| `LiveTranslateController.lines` | `LiveTranslateController.paragraphs` |

The fields of `TranslatedParagraph` are unchanged.

**Breaking:** `OverlayStyle.maxFontSize` (default 28) now caps a label's starting size. Large headings that used to get labels as big as the heading now stop at 28; raise `maxFontSize` to get them back.

New:

* `LiveTranslateView.overlayBuilder`: draw the translations yourself. The `OverlayBuilder` receives the shown paragraphs, in the view's coordinates, and replaces the built-in labels.
* `LiveTranslateView.onParagraphsChanged`: called whenever the shown paragraphs change, with or without a controller.
* `LiveTranslateView.onFrozen`: called with the frozen picture's paragraphs once its translation is shown, and again if it is read again.
* `LiveTranslateView.placeholderBuilder`: shown while the camera starts, in place of the progress indicator.
* `SourceStatus` and `LiveTranslateController.sourceStatus`: where finding the source language stands (searching, guessed, downloading, ready, unsupported, not found or download failed), to show progress before the first translation.
* `LiveTranslateController.setSourceLanguages`: change the expected source languages, or go back to detection with `null`, without restarting the camera. The most recent change wins, whether from the controller or the widget.
* `PipelineMetrics` and `LiveTranslateController.metrics`: how long each shown read took (recognition, translation, colour sampling and total), how many paragraphs it translated, and whether it was frozen.
* `LiveTranslateView.showDebugHud`: a small panel over the camera with the latest read's timings and the frame rate, for development.

Improved:

* Faster first translation: a steady picture whose language isn't settled is read again every second, so short text confirms its language without moving the phone. After three reads that find no language, the status says so.
* Paragraph ids now stay the same while the view keeps reading a paragraph in the same place: re-reads while the language settles, after a download or a target change, after a small pan, and on freeze. A new scene gets new ids, so an id can key a widget.
* Languages that can't be translated, such as lorem ipsum identified as Latin, no longer outvote a translatable language in the same script.
* A Devanagari paragraph identified only as a language ML Kit can't translate, such as a Hindi sign taken for Nepali, is now translated from Hindi or Marathi instead of being left untranslated. Before, a short Hindi sign could show nothing at all.
* The example app adds model management, a sheet to copy the read text, the source status on its language chip, and replay tests that run saved photos through the real pipeline on a device.

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
