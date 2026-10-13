# Design

## Context

See proposal.md for the motivation. What exists now:
- `LiveTranslateView` takes a required `targetLanguage` and `scripts` (default `{latin}`), and keeps the effective `_target` and `_scripts`. The most recent change wins, whether it came from the widget or the controller.
- A new `Pipeline` (and with it a new `LineTranslator`) is built whenever the target, scripts or source languages change.
- `LineTranslator._ensureModel(language, source:)` checks a model and, if it's missing, calls `_onMissing`:
  - for the target (`source == null`), it downloads at once;
  - for a source language, it waits for confirmation, then downloads only if `_SourceRole.expected` (the language is in the hint); otherwise it reports `ModelNotDownloaded` once through `_reportedMissing`.
  - Every download is `wifiOnly: true`, and source downloads run one at a time (`_sourceDownloadRunning`).
- The target is first checked on the first line of the first frame.
- `BCP47Code.fromRawValue(code)` from ML Kit maps a language code such as `en` or `hi` to a `TranslateLanguage`, or `null` when there's no on-device model.

## Goals / Non-Goals

**Goals:**
- An English phone pointed at Hindi, with no target or scripts given, translates Hindi into English. The English model starts downloading at start, the Hindi model once Hindi is confirmed, and neither waits for Wi-Fi.
- Every changed scenario is a unit or widget test, with fake engines and model store, and with the device locale set through `tester.platformDispatcher.localeTestValue`.

**Non-Goals:**
- A language picker. That's the next change, and it will set the target through the existing controller and widget paths.
- Following a device-language change while the view is running. The language is read when the view starts, and again only when the widget's `targetLanguage` goes back to `null`.
- Download progress beyond the existing `ModelNotDownloaded` report, and deleting models that were downloaded automatically.
- Scripts beyond Latin and Devanagari.

## Decisions

**D1. Device language: `deviceTargetLanguage(Locale)`, a pure function.**

A new `lib/src/models/device_language.dart` returns `BCP47Code.fromRawValue(locale.languageCode) ?? TranslateLanguage.english`. It uses the language code alone, so `en_US`, `en_GB` and `en` all give English.

The view reads `WidgetsBinding.instance.platformDispatcher.locale`:
- in `initState` when `widget.targetLanguage` is `null`;
- in `didUpdateWidget` when the widget's target changes to `null`.

A target from the widget or the controller still wins, as in D3 of `live-controller`.

*Alternative:* `Localizations.localeOf(context)`. Rejected because it gives the app's locale, which is limited to the languages the app supports (often only English). The user's device language is what matters here.

**D2. The target model is fetched when a pipeline is built.**

`LineTranslator` gets `prepare(TranslateLanguage target)`, which runs `_ensureModel(target)` without waiting for it. The `Pipeline` constructor calls it for its `target`. A pipeline is built when the view starts and on every settings change, so a target change fetches the new target at once. The existing `_states` and `_checks` mean the first frame's own `_ensureModel(target)` shares that check or download instead of starting another.

If that early check throws, for example when the platform plugin is missing, `prepare` reports a `PipelineFailure` instead of leaving an unhandled error. That matches a failure on a frame. The example's widget test therefore answers ML Kit's model check itself.

*Alternative:* a separate download from the view through `ModelStore`. Rejected because it would bypass the translator's state, so the first frame would check the model again and report a second `ModelNotDownloaded`.

**D3. Confirmed source languages always download; `_SourceRole` and `_reportedMissing` go.**

`_onMissing` for a source keeps the confirmation check and the one-at-a-time rule, then downloads. `_ensureModel` loses its `source:` role object and takes `isSource: bool`. A missing source that isn't confirmed yet is left until it is. Unconfirmed sightings never download.

**D4. All automatic downloads use `wifiOnly: false`.**

This is one constant in `LineTranslator`. `ModelStore.download` keeps its required `wifiOnly` parameter, and `TranslationModels.download` keeps its `true` default for downloads the app starts itself.

**D7. One language per script per frame, and confirmation by leading.**

On the device, Hindi text downloaded Marathi as well. Each short line is identified on its own, and ML Kit sometimes calls a Hindi line Marathi at 0.9, so Marathi reached 3 confident sightings in 10 frames too.

`translateLines` now works in two passes:
1. **Guess:** each line gets its qualifying guesses (identification, filtered by the hint as before; a single hint skips identification as before).
2. **Settle:** lines are grouped by script with `hasLetterOf`: Devanagari first, then Latin. Lines in neither script keep their own best guess.
   - In each group, the guesses' confidences are summed per language. The top language becomes the frame's language for that script.
   - Each line with a qualifying guess is assigned the frame's language, unless its own best guess is the target, so target-language lines are still dropped.
   - The frame's language is sighted for confirmation when its average confidence over the lines that identified it is at least `confirmConfidence`. A stray Marathi line in the group therefore doesn't pull Hindi below the bar.
   - `_sightings` records one winner per script per frame, together with the script it won.
   - `_isConfirmed(tag)` additionally requires the tag's count in the window to beat every other tag sighted for the same script. Lines in neither script are sighted on their own and compete with no one.

Translation and model checks then run per line, as before.

*Alternative:* raise the confirmation threshold (say 5 of 10). Rejected because a steady stray guess would still confirm, just later, while first use of the right language would be slower.

*Alternative:* pick one language for the whole frame. Rejected because a Hindi sign with an English or Spanish line beside it is common, and different scripts can't be the same language.

**D5. Default scripts: `{TextScript.latin, TextScript.devanagari}`.**

`MultiScriptTextEngine` already alternates between scripts, frame by frame. No other code changes.

**D6. Example app and README.**
- `example/lib/main.dart` drops `targetLanguage` and `scripts`, so it runs on the defaults. The "Hindi only" chip goes too, so the screen is just the camera with the freeze and torch buttons.
- Each `ModelNotDownloaded` now means a download has started, so the message becomes "Downloading the ‹language› model…" for every language.
- The README gets a short "Getting started" section with the native Devanagari setup (the Gradle dependency and the pod) that the default now needs. The rest of the template text stays for the release change.

## Risks / Trade-offs

- [Two genuinely different languages in one script, in one view, are treated as one, such as a Hindi and a Marathi sign side by side] → The language with more confidence wins. The other's lines are translated as if they were in that language, which for closely related languages is usually still readable. Different scripts are unaffected.

- [An app without the native Devanagari model gets a recognition failure on every Devanagari frame] → The README section documents the setup, and the failures arrive as `PipelineFailure` through `onError`, which is visible during development. Turning a missing script model into a one-time report is left for later.
- [Two scripts halve how often each script is read] → An app that reads only one script can pass `scripts`. Line tracking already keeps labels steady between readings.
- [Mobile-data downloads cost the user about 30 MB per model] → Downloads happen only for the target and for languages confirmed in 3 of 10 frames, one source at a time. An app that must avoid mobile data can pre-download with `TranslationModels.download`, which waits for Wi-Fi by default.
- [A settings change while the target is downloading builds a new translator, which may report the same download again] → ML Kit merges duplicate download requests for one model, so only the report repeats. This already happens today on the first frame.

## Migration Plan

Nothing is published and the view isn't exported. When archiving, update the `translate` spec's Purpose, which still says the package "never downloads a model over mobile data unasked".

## On-device results

Exit check on 2026-10-11: the example app reinstalled (so no translation models on the device), both phones set to English, on mobile data, pointed at Hindi text.

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| English model downloads at launch | Pass | Pass |
| Hindi download starts when pointing at Hindi | Pass | Pass |
| No Marathi download follows | Pass | Pass |
| Hindi lines show English labels once downloaded | Pass | Pass |

The first run, before the per-script fix (D7), also downloaded Marathi. That led to D7. On that run the English download message wasn't noticed, possibly because the model was already on the device.

Evidence: the author's report that the change works after the fix. No recordings were attached.
