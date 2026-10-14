## Unreleased

* `LiveTranslateView.overlayBuilder`: draw the translations yourself. The new `OverlayBuilder` receives the shown lines, in the view's coordinates, and replaces the built-in labels.
* `LiveTranslateView.onLinesChanged`: called whenever the shown lines change, with or without a controller.
* `LiveTranslateView.onFrozen`: called with the frozen picture's lines once its translation is shown, and again if it is read again.
* `LiveTranslateView.placeholderBuilder`: shown while the camera starts, in place of the progress indicator.
* `PipelineMetrics` and `LiveTranslateController.metrics`: how long each shown read took (recognition, translation, colour sampling and total), how many paragraphs it translated, and whether it was frozen.
* `LiveTranslateView.showDebugHud`: a small panel over the camera with the latest read's timings and the frame rate, for development.

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
