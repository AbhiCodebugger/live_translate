# Design

## Context

See proposal.md for motivation. What shapes the approach in the current code:

- `LineTranslator` is the only place that knows a read's guesses, whether a language is confirmed (`_isConfirmed`), and each model's state (`_states`: checking, available, missing, downloading). Download completion reaches the view only through `Pipeline.modelsReady`. Download start reaches the app only as a `ModelNotDownloaded` error, and a failed download isn't surfaced at all: it just resets the state to missing.
- `ReadResult` carries only translated paragraphs, plus `untranslatedLanguages`.
- `LiveSettler` is a pure state machine driven by `onFrame` and an injected clock. After a successful read it stops reading a steady picture (`_hasResult` and no pan).
- `LiveTranslateController` gets its values from the view through `_publish`. It already exposes `targetLanguage` the same way the new `sourceStatus` will be exposed.

## Goals / Non-Goals

**Goals:**
- Status updates between reads for download start, completion and failure, without waiting for the next read.
- Keep `LiveSettler` and the status logic testable with a fake clock and fake engines, like the existing tests.

**Non-Goals:**
- A byte-level download percentage. ML Kit doesn't report one.
- An `onSourceStatusChanged` view callback. The controller is enough for now and a callback can be added later without changing the stages.
- Changing confirmation thresholds (3 of 10 reads, 0.8, 20 letters).

## Decisions

### 1. `SourceStatus` is a sealed class with value equality
Subtypes: `SourceSearching`, `SourceGuessed(language)`, `SourceDownloading(language)`, `SourceReady(language)`, `SourceUnsupported(tag)`, `SourceNotFound`, `SourceDownloadFailed(language)`. Languages are `TranslateLanguage`. Unsupported carries a `String` tag, because it has no `TranslateLanguage` by definition.
- **Why:** It matches the existing sealed `LiveTranslateException` hierarchy, and lets apps `switch` exhaustively. Value equality lets the controller skip notifying when nothing changed.
- **Alternative:** An enum plus a nullable language field. It's simpler, but `language` would be null for some values and not others, and the compiler can't check which.

### 2. `LineTranslator` produces each read's status; the view owns the parts that span reads
After `translateLines`, the translator reports a per-read status. It picks the language as "One language named for the picture" says, then maps that language's state: confirmed with no model, unsupported; missing and unconfirmed, guessed; downloading, downloading; available, ready. If no paragraph has a language, it reports "none". `Pipeline.read` puts this on `ReadResult` as an internal field.

The view then adds:
- **Not found:** it counts consecutive reads of the current scene that came back "none". On the third, the status becomes `SourceNotFound`. The count resets on a clear (new scene or fast movement), a settings change, and any read with a language.
- **Scene resets:** a clear sets `SourceSearching`.
- **Between-read events:** `LineTranslator` exposes a `modelEvents` stream (started, ready, failed per language), and the pipeline forwards it beside `modelsReady`, which stays so the `createTranslator` signature is unchanged. A failed download is usually retried on the next read, so download failed mostly shows between reads. When the event is for the named language, the view moves to downloading, ready or download failed right away.

- **Why:** Confirmation and model state already live in the translator. Duplicating them in the view would drift. "Not found" and scene resets depend on the settler's notion of a scene, which only the view has.
- **Alternative:** Compute everything in the view from `ReadResult` and errors. It can't tell guessed from downloading for a language whose `ModelNotDownloaded` was reported earlier and then failed, so it would recreate the translator's state.

### 3. The settler re-reads while the view says the language is unsettled
`LiveSettler` gets an `unsettled` flag the view sets after each read: true for searching and guessed. In `onFrame`, a steady picture with a held result returns `read` when `unsettled` is set and at least `rereadInterval` (1 s) has passed since `readFinished`. Movement keeps the existing rules: not steady, no read; 300 ms settle again after movement. `readFinished` records the time.
- **Why:** The settler already owns all read timing and is tested with a fake clock. A one-flag input keeps it unaware of languages.
- **Why 1 s:** A read takes roughly 200–600 ms. One second keeps reads from running back to back (battery, heat), and still confirms short text in about 3 s: the 300 ms settle plus 3 reads, close to the 5 s target.
- **Alternative:** Re-read on every steady frame as soon as the last read ends. That's faster, but it keeps OCR busy all the time.

### 4. Only translatable languages vote, when any line has one
In `_settle`, a tag counts as translatable when `BCP47Code.fromRawValue(tag) != null`, which is ML Kit's translation set. The per-script totals include only translatable tags when at least one line of the group has one. Lines left without the winner keep their own best guess, so lorem ipsum stays `la` and is reported unsupported after confirmation, as today.
- **Alternative:** Vote per paragraph, with no grouping. That brings back the Hindi/Marathi flip-flop the group vote exists to fix.

### 5. Example source chip renders `controller.sourceStatus`
`detectedLanguage()` and its tally of translated lines go away. The existing `_pending` download indicator stays for the target chip. The source chip shows the indicator when the status is downloading. Unsupported tags get a name from a small table of ML Kit language-ID tags with no translation model (`la` is Latin, plus others such as `hi-Latn`), and otherwise show the tag.

## Risks / Trade-offs

- [Re-reading a steady picture gives nearly the same OCR text, so 3 sightings are weaker evidence than 3 reads after movement] → The 0.8 confidence bar still applies to every read, and only one source download runs at a time. A stray download is a ~30 MB cost, not a wrong translation. We accept this so the stall goes away.
- [Extra reads use battery] → They happen only while the status is searching or guessed, and stop after not found (3 reads). A settled scene reads once, as before.
- [Not found also fires on a blank wall] → The wording "No supported text found" is true in both cases.
- [Status flicker when a frame's paragraphs change between reads] → The tie rule keeps the current language, and the controller notifies only on a change.

## Migration Plan

This is additive. `sourceStatus` is new, and existing `lines`, `onError` and `ModelNotDownloaded` behaviour stays. The re-read and vote changes are behaviour fixes that need no app changes. Update the README and CHANGELOG in the same change. Rollback is reverting the change.
