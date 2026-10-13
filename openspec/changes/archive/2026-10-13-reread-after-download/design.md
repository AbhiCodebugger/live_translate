# Design

## Context

See proposal.md for the motivation. What the code does today:
- **Missing model in `LineTranslator._translateLine`:** it awaits both the source and target model checks. If either isn't ready, it returns `LineTranslation(line, sourceLanguage: source)`, with no record of *which* model was missing.
- **`Pipeline.read`:** it builds `ReadResult.untranslatedLanguages` from the `sourceLanguage` of every untranslated paragraph. A paragraph waiting only for the target therefore lists its source (say `es`), never the target (`de`).
- **`_LiveTranslateViewState._onModelReady(language)`:**
  - returns at once if nothing is shown or `_reading` is true;
  - otherwise calls `_reread()` when `untranslatedLanguages` contains `language.bcpCode`.

  So it misses a target download every time, and a download that completes mid-read.
- **Order on completion:** `LineTranslator` marks a model `available` *before* it emits `onModelReady`, so a read started from that callback sees the model ready.
- **What a target change does:** it builds a new pipeline whose `prepare(target)` starts the download at once, then calls `_reread()`. That re-read is the one that returns untranslated.

## Goals / Non-Goals

**Goals:**
- Every scenario in the `live-translation` delta is a widget test with fake engines and a gated download.
- A model that becomes ready never leaves a held or frozen result untranslated.

**Non-Goals:**
- Showing anything new while the target downloads. Paragraphs stay hidden (untranslated paragraphs aren't drawn, as today). The example's target chip shows its spinner.
- Re-reading a held result that is empty for other reasons, such as no text or an unsupported language.
- Any latency work (see proposal).

## Decisions

**D1. A translation records the models it lacked.**

`LineTranslation` gains `missingModels` (`Set<TranslateLanguage>`, default empty), included in `==` and `hashCode`. `_translateLine` fills it from the two readiness results: the source when its check returned false, and the target likewise. `Pipeline.read` then adds the `bcpCode` of every missing model to `untranslatedLanguages`, alongside the source tags it collects today. That keeps today's entries, including unsupported sources, which never become ready and so never trigger anything.

Alternative: add the target whenever any paragraph with a known source is untranslated. Rejected: it's imprecise (it would list the target when only the source is missing), and `untranslatedLanguages` should mean "models this read lacked or couldn't use".

Alternative: let the view ask the translator whether the target is ready. Rejected: it couples the view to translator state, and the result already exists to carry this.

**D2. Models that become ready during a read are remembered until it finishes.**

- The view keeps `_readyDuringRead` (`Set<String>` of BCP-47 tags), cleared whenever a read starts (`_read`).
- `_onModelReady` behaves differently depending on state:
  - while `_reading`, it adds the tag and returns;
  - otherwise it keeps today's check against the shown result.
- When a current read finishes successfully, if its `untranslatedLanguages` intersects `_readyDuringRead`, the view clears the set and calls `_reread()`. Superseded reads (stale token) are ignored as today. The next read clears the set anyway.

Alternative: always re-read once after any model becomes ready mid-read. Rejected: it adds a needless read when the running read had already picked the model up.

**D3. No new loop guard.**

A re-read is triggered only by a model *becoming* ready, and each download completes once. So D2 can't re-read repeatedly. A re-read that still lacks a model (for example, the source is downloading too) waits for that model's own completion.

## Risks / Trade-offs

- **[The re-read after a target switch rebuilt the pipeline, so `modelsReady` comes from the new pipeline]** → Subscriptions are rebuilt with the pipeline (`_buildPipeline`), and the download is started by the new pipeline's `prepare`, so the event reaches the current subscription. One test covers switching the target and then completing the download.
- **[A switch away from a downloading target leaves its download running]** → Unchanged from today. Its completion event belongs to a disposed pipeline and is dropped. Harmless.
- **[`LineTranslation` equality now includes `missingModels`]** → Only tests compare translations. Existing expectations build translations without missing models, so they hold wherever both models are present. Any that compare untranslated results are updated in task 1.1.
