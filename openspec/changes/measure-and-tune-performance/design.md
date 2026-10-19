# Design

## Context

See proposal.md for motivation. What shapes the approach in the current code:

- **Per-frame UI-thread work.** `_LiveTranslateViewState._onFrame` runs `MotionEstimator.measure` and `LiveSettler.onFrame` for every streamed frame. The camera delivers frames to Dart on the UI isolate. The thumbnail (64 samples on the long side) is built through a per-sample closure and a `uprightToRaw` record, and then a coarse search (13 × 13 shifts) and a fine search (5 × 5 shifts) run over it.
- **Labels following the camera.** While a result is held, every frame whose shift moved at least 1 px calls `setState`. The rebuild creates a new `ParagraphPainter` whose label rects differ, so `shouldRepaint` is true. `paint` then calls `placeParagraphLabels`, which makes up to 3 `_fits` layouts per label, and `fitParagraphFontSize`, which makes one layout per font size from the starting size down. It then lays out a probe and the final text, and disposes all of them. A held label that only moved is fitted from scratch on every frame. The fade animation repaints the same way on each tick.
- **Colour sampling** runs once per paragraph per read, not per frame. Its sort comparator recomputes WCAG luminance, two `pow` calls per comparison, for up to 768 samples.
- **Recognition** sends the frame's bytes to every selected script's recognizer in parallel (`MultiScriptTextEngine`). With Latin and Devanagari, each read crosses the platform channel twice with the same bytes.
- **Replay test** (`example/integration_test/replay_test.dart`) already times a cold read and one warm read per photo and writes them to `build/integration_response_data.json` under `flutter drive --profile`. The photos are about 960 × 1280. `ResolutionPreset.medium` streams 720 × 480 on Android and 640 × 480 on iOS.
- **Size.** The example adds the Devanagari recognizer through `example/android/app/build.gradle.kts` and `example/ios/Podfile`. The README tells Latin-only apps to leave both out.
- Device work is the user's: Claude builds but doesn't install or launch on a phone. The devices are the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1).

## Goals / Non-Goals

**Goals:**
- Numbers that can be reproduced: every figure in the README comes with the command or the steps that produced it.
- Tuning that changes no output. The existing unit, widget, golden and replay tests must pass unchanged after each step.
- Before/after evidence for each tuning step, from host benchmarks and from the second device pass.

**Non-Goals:**
- Publishing host benchmark times. They come from the JIT on a Mac and only show relative change.
- A frame cost metric in the public API (`PipelineMetrics`). The HUD is enough to diagnose problems, and adding a field later only adds to the API.
- Isolates for motion estimation, unless the second device pass shows the per-frame cost is still a problem (see decision 7).

## Decisions

### 1. Order: tooling, baseline, safe tuning, re-measure, gated tuning, docs
The measurement tools come first, so the device baseline uses the same tools as the final numbers. Device passes are the expensive step, so there are exactly two planned: a baseline and a final pass. A third pass happens only if gated tuning lands.
- **Alternative:** Tune first and measure once. It's cheaper, but it can't show which change helped, and the case study needs before/after numbers.

### 2. Frame cost is timed with a stopwatch seam, only while the HUD is on
When `_hud != null`, `_onFrame` reads an internal `elapsed` clock (a `Stopwatch` by default, a `@internal` constructor parameter like `now`) before the motion estimate and after the settler decision, exactly twice per frame. It keeps each frame's cost beside its arrival time in the one-second window `_frameTimes` already uses for the frame rate. The HUD's last line becomes `N fps · frame A.A ms avg, W.W max`, falling back to `N fps` with no frames. The cost stays inside `DebugHudData`, which is internal.
- **Why:** A monotonic, microsecond stopwatch is the right tool to time sub-millisecond work. A separate seam read exactly twice per frame lets widget tests script exact costs (the spec's 2.2 / 6.5 ms scenario) without disturbing the view's `now` clock, which the settler also reads. Timing only while the HUD is on keeps the off path unchanged, as the spec requires.
- **Alternative:** Reading the view's `now` clock. It's one seam fewer, but the settler reads that clock a varying number of times per frame, so tests couldn't set a frame's cost precisely.

### 3. Label layouts are kept across frames by a cache the view owns
A `LabelLayoutCache`, created in the view state and passed to `ParagraphPainter`, memoises the two kinds of text measurement the painter makes. It records whether text fits a size at a font size, which covers `_fits` and each step of `fitParagraphFontSize`. It also keeps the final laid-out `TextPainter`, keyed by text, font size, max width, max lines, ink colour, style and direction. It's an LRU of about 64 painters that disposes what it evicts. It's cleared when the style changes, and disposed with the view. `placeParagraphLabels` and `fitParagraphFontSize` take the cache as an optional parameter, so their current pure use in tests still works.
- **Found while building it:** Two things limit what the cache can reuse. First, a label that grew to the view's edge changes width as it pans, so it is fitted again on each frame. Only labels that fit in their own rect, and labels away from the edge, reuse their layouts. Second, the view's scaled float rects can change a moved label's exact width by a rounding error. Text is therefore laid out at its width rounded to 1/100 px, with or without the cache, so a pure move keeps exactly the same key and the same layout.
- **Why:** Panning only moves rects. Inner sizes, and therefore every layout, stay the same unless a label meets the view's edge, so nearly every frame hits the cache. The output is unchanged by construction: the same measurements, just not repeated. `paragraph_labels.png` and the painter tests guard this.
- **Alternatives:** (a) Paint once and translate the canvas by the shift. Labels are clamped to and grow against the view's edges, so a shifted label near an edge would be placed differently from today, which is a behaviour change. (b) A `RepaintBoundary` with a `Transform` has the same edge problem. (c) A static global cache has no clear owner to dispose its `TextPainter`s.

### 4. The motion thumbnail reads through a precomputed index table
For a given (image width, height, stride, format, rotation), the estimator builds once an `Int32List` of the raw byte offset of each thumbnail sample. It's the same `uprightToRaw` sample points and clamping as today. It reuses the table while frames keep that shape. NV21 reads `bytes[offset]` and BGRA computes the same weighted luma from `offset..offset+2`. The coarse and fine search is unchanged.
- **Why:** It removes about 3,000 closure calls and record allocations per frame. The motion values come out bit-identical, so the existing motion and settler tests stay valid. A new test checks the table against the old per-sample path for all four rotations and both formats.
- **Alternative:** A smaller thumbnail or a narrower search would be cheaper, but they change motion behaviour, which the settler's thresholds depend on. That's only a candidate under decision 7.

- **Outcome:** Built and tested bit-identical, then reverted. The host benchmark didn't change beyond noise (about 420–670 µs per frame before and after). Reading the thumbnail is a small share of the cost. The coarse-to-fine shift search, about 200,000 sample comparisons per frame, is most of it. On the devices the whole per-frame cost is already 0.5–1.2 ms on average, so a faster search isn't needed now.

### 5. Colour samples carry their luminance
`_Rgb` computes its luminance once (a `late final` field), and the sort uses it. The bucket and mean logic is unchanged, so the output is identical.

### 6. Replay: repeated warm reads and a stream-size variant
For each photo, the replay test does one cold read and then 5 warm reads. It reports the median and worst of each stage. It then repeats the warm reads on the photo scaled so its long side is 720 (Android) or 640 (iOS), the sizes `ResolutionPreset.medium` streams. Pass/fail assertions stay on the full-size photo, where the expectations were written. At stream size the test only reports whether the expectations would have passed. The reported data gains `warm` (median and max per stage), `stream` (the same, plus `passed`) and a `summary` (the median across frames of each stage, for cold, warm and stream). The printed table shows the summary row last.
- **Why:** The median of 5 removes one-off stalls such as GC and a first JIT warm-up of a platform path. Stream size is what a live read actually gets. The stream-size pass/fail also tells us early whether the medium resolution loses text, which bears on decision 7.
- **Alternative:** Recording real camera frames for the replay. It's more faithful, but it adds a capture tool and assets for little gain over scaled photos.

### 7. Gated tuning is decided from the numbers, not now
After the second device pass, each budget line in PLUGIN_PLAN §10 is checked on the Samsung (the Android device):
- **Read time:** stream-size warm median total over 500 ms.
- **UI frame cost:** worst frame cost over 8 ms while holding or panning, or janky frames in DevTools that come from the package.
- **Steady to labels:** over 800 ms.
- **Memory:** an upward trend over 2 minutes.

For each line missed, the cause is found from the stage timings or the profile, and a fix is added to this change with `/opsx:update`, including any spec delta, before it is built. Candidates already seen, in rough order of likely payoff: recognizing each script one after the other instead of in parallel, or recognizing Devanagari only when the Latin pass finds non-Latin glyph boxes (a recognition behaviour change, so the `recognize` spec would change); a lower default resolution if stream-size accuracy holds; moving the thumbnail to a background isolate. If every line passes, no gated tuning is done and the change says so.

### 8. Size impact comes from a script that builds temporary copies
`tool/size_impact.sh` copies `example/` to a temporary directory and points its `live_translate` path dependency at the repo. It builds the copy twice: once as is (Latin and Devanagari) and once with the Devanagari lines removed from the copy's `build.gradle.kts` and `Podfile` (Latin only). It also creates a bare `flutter create` app with the same minimum SDK and iOS platform as the baseline. For each it runs `flutter build apk --release --split-per-abi` and reports the arm64 APK, then `flutter build ios --release --no-codesign` and reports `Runner.app` both zipped (about an IPA) and unzipped. It prints a Markdown table, including the differences: the package over the bare app, and Devanagari over Latin only. The repo's `example/` is never edited.
- **Why:** Editing and restoring `example/` in place would leave the checkout dirty if a build failed half way. A temporary copy can't. Release builds need nothing from a device, so Claude can run this.
- **Alternative:** A Gradle `-P` flag and a Podfile environment variable in the real example. That leaves size-only switches in the shipped example app that its users would have to read past.

### 9. Where the results live
Raw results from each device pass (replay JSON summaries, HUD readings, DevTools observations, device model and OS, Flutter version) go in `openspec/changes/measure-and-tune-performance/measurements.md`, which is committed with the change. The README gets the final pass's table and the size table, with the date, device, OS, build mode and package version.

## Risks / Trade-offs

- [The Samsung may not be mid-range] → The README names the exact model and doesn't call it mid-range unless it is. If a cheaper Android phone becomes available later, adding its row only adds to the docs.
- [Scaled photos differ from camera frames: no sensor noise or motion blur, upright rather than rotated by 90°] → The README says replay numbers are photo-based. The live HUD readings from the second device pass are reported next to them.
- [The layout cache could hold stale painters if a key misses an input] → The key includes everything the painter passes to `_layout`. The golden and painter tests run with the cache. A test changes each key field and expects a new layout.
- [Timing in `_onFrame` adds work] → It only happens while the HUD is on. That is two stopwatch reads, one clock read and a queue push, and it's what the HUD exists for.
- [Host benchmarks may be noisy] → They're used only for before/after on the same machine, with many iterations and a warm-up. They're never published.
- [A gated fix may change behaviour late in the week] → It goes through `/opsx:update` with a spec delta and its own tests before it's built, and is dropped to 1.1 if it doesn't fit the week.

## Migration Plan

No API or behaviour change for apps. Rollback is reverting the commits. The HUD's extra line is debug-only.

## Open Questions

- The Samsung Galaxy's exact model and its tier (for the README row). The user supplies it during the baseline pass.
