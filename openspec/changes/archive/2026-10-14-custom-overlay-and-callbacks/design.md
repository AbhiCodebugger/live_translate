# Design

## Context

See proposal.md for the motivation. In `_LiveTranslateViewState`, `build` computes `_shownLines` (view coordinates, after the held shift and the fade) inside its `LayoutBuilder`, because mapping needs the view's size. `_schedulePublish` then hands them to the controller in a post-frame callback, since listeners may call `setState`. It returns early when there is no controller. `publishToController` notifies only when state, lines or target differ. The painter gets its own `ParagraphLabel`s built from the same paragraphs, plus sampled colours and line heights that `TranslatedLine` doesn't carry. While the camera starts, `build` returns a centred `CircularProgressIndicator`.

## Goals / Non-Goals

**Goals:**
- One source of truth for lines: the controller, `onLinesChanged`, `onFrozen` and `overlayBuilder` all see the same `_shownLines` list.
- Every delta scenario is a widget test in `test/view/live_translate_view_test.dart`.

**Non-Goals:**
- Giving `TranslatedLine` the sampled page colours or line height. Custom overlays can't match the page's colours yet. Whether to expose them is a question for the API review before 1.0, together with renaming `TranslatedLine`.
- A builder for the camera error screen.
- Showing the placeholder while translation models download. Models download in the background while the camera runs, and lines appear as each model arrives. Hiding the camera until then would be worse.

## Decisions

**D1. One post-frame report step.**

`_schedulePublish` becomes `_scheduleReport`. It runs when there is a controller, an `onLinesChanged` or an `onFrozen`, and in one post-frame callback, in this order:
1. publishes to the controller, as today;
2. calls `onLinesChanged` if `_shownLines` differs (`listEquals`) from the last list it was called with, starting from `const []`;
3. calls `onFrozen` if a frozen result is pending (D3).

Callbacks are read from `widget` at call time, so a rebuilt widget's new callbacks are used. The view keeps its own "last reported" list for `onLinesChanged` rather than reading the controller's, so the callback works without a controller and can't drift if the controller is swapped.

Alternative: call the callbacks from `build`. Rejected: an app calling `setState` from them would throw during build. That is the reason the controller already publishes after the frame.

**D2. `onLinesChanged` fires on every change, not only on new text.**

It matches the controller exactly: new results, shifts, fade steps and clearing. Apps placing their own UI need the moved rectangles. An app that cares only about new text can compare `translatedText`. The cost is one call per frame while the labels move or fade, the same rate at which the controller notifies today.

Alternative: fire only when the set of texts changes. Rejected: it would differ from the controller's `lines`, and the spec would need a second notion of "changed".

**D3. `onFrozen` uses a pending flag.**

A `_frozenPending` flag is set when the frozen picture's result becomes final:
- in `freeze()` when the held labels are kept;
- in `freeze()` when there is no frame to read;
- when a read that started while frozen finishes without failing (including a `null` result, which shows nothing).

It is cleared when a new frozen read starts (settings change, model download), on `resume()`, on `_forget()` and when it fires. The report step fires it only while `_frozen && !_reading`, so it always sees laid-out lines for the final result. A failed read never sets it. A superseded read returns before setting it, because its token is stale.

Alternative: fire from `freeze()`'s future. Rejected: the lines aren't laid out yet at that point, and re-reads after a settings change don't go through `freeze()`.

**D4. `overlayBuilder` replaces the painter, not the stack.**

In the running `Stack`, the `CustomPaint` is swapped for `Positioned.fill(child: widget.overlayBuilder!(context, _shownLines))`. The preview stays below it and the frozen-read indicator above it. `Positioned.fill` makes the overlay's coordinate space the view's, which is what `TranslatedLine.rect` is in. When an overlay is given, `OverlayStyle` is unused. This is documented on both parameters. Lines at opacity 0, just before a fade drops them, are still passed, and the dartdoc says to honour `opacity`.

`OverlayBuilder` is a public typedef in `live_translate_view.dart`, exported by name next to `LiveTranslateView`.

**D5. `placeholderBuilder` fills the view.**

In the `!_running` branch, `build` returns `SizedBox.expand(child: widget.placeholderBuilder!(context))` when given, and otherwise the current indicator. The error branch comes first and is unchanged. Restarting after the background already sets `_running = false`, so the placeholder shows then too, without extra state.

## Risks / Trade-offs

- **[`onLinesChanged` is noisy while moving]** → Documented in its dartdoc, with the tip to compare texts. It has the same rate as controller notifications, which apps already handle.
- **[A custom overlay loses page colours]** → Documented as a known gap, and listed for the API review (Non-Goals).
- **[`onFrozen` fires again on a re-read]** → This is intended: the frozen translation changed. The dartdoc says so, so an app opening a sheet can update it instead of opening a second one.

## Migration Plan

Additive. The CHANGELOG gets an `## Unreleased` section. The version stays 0.1.0 until the 0.2.0 release change.
