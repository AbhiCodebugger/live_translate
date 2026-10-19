# Measurements

Raw results behind the README's performance and size tables. Host benchmark times come from the JIT and are only for comparing before and after on the same machine.

## Host benchmarks

Machine: Mac with Apple A18 Pro, macOS 26.5, Flutter 3.47.7 (stable). Command: `flutter test --tags benchmark --run-skipped test/benchmark`. Mean µs per operation.

| Benchmark | Baseline (85dbd1b) | After tuning |
|---|---:|---:|
| motion 720 × 480 nv21 deg0 | 561.2 | no change (6.2 tried and reverted; see note below the table) |
| motion 720 × 480 nv21 deg90 | 522.0 | |
| motion 720 × 480 nv21 deg180 | 481.3 | |
| motion 720 × 480 nv21 deg270 | 486.5 | |
| motion 640 × 480 bgra deg0 | 519.0 | |
| motion 640 × 480 bgra deg90 | 511.6 | |
| motion 640 × 480 bgra deg180 | 541.3 | |
| motion 640 × 480 bgra deg270 | 500.8 | |
| colours 5 paragraphs, 720 × 480 nv21 | 540.2 | 415 (6.3, luminance computed once; two runs: 419.6, 410.2) |
| paint 5 labels, one shifted frame | 537.4 | 203 (6.1, label layout cache; two runs: 202.5, 203.9) |

Motion (6.2): with the thumbnail read through a precomputed offset table, two runs gave 444–668 µs across the eight cases, against 455–561 µs at baseline. That's noise, so no gain, and the change was reverted. The shift search dominates the cost.

Checks after the safe tuning (6.4, 2026-10-18): `dart format`, `flutter analyze` (package and example), 519 package tests, the golden test and 86 example tests all pass. Line coverage: geometry 93.3%, live 96.7%, motion 97.0%, still 98.4%, cache 100%, pipeline 98.4% (view 96.4%). Every core directory is above 90%.

## Size impact

Measured 2026-10-17 with `tool/size_impact.sh` (Flutter 3.47.7, Xcode release build without signing, package at 85dbd1b plus this change's uncommitted work). MB = 1,000,000 bytes. The example copies leave out the replay photos (2.9 MB of test assets).

| App | Android APK (arm64) | iOS app, zipped | iOS app, unzipped |
|---|---:|---:|---:|
| Bare Flutter app | 15.5 | 6.2 | 14.4 |
| Example, Latin only | 49.2 | 40.3 | 121.3 |
| Example, Latin and Devanagari | 49.9 | 41.3 | 122.8 |
| live_translate, Latin only (over bare) | +33.7 | +34.1 | +106.9 |
| Devanagari recognizer (over Latin only) | +0.6 | +1.0 | +1.5 |

Found while measuring: the README's Latin-only setup failed Android release builds, because R8 stops at the plugin's reference to the Devanagari recognizer. The README now adds `-dontwarn com.google.mlkit.vision.text.devanagari.**` for Latin-only apps, and the script does the same for its Latin-only copy.

## Device baseline

Build: 85dbd1b plus this change's measurement tools (groups 1–4), no tuning. Profile mode.

### Samsung Galaxy M17 (SM-M176B), Android 16 (build BP4A.251205.006.M176BXXS8CZI9)

Replay benchmark, 2026-10-17. Raw data: `data/replay_baseline_samsung_m17.json`. Model downloads took 5.9–6.7 s each (Hindi, Marathi, Spanish, French, German).

Median across the 15 photos, in ms:

| Read | Recognition | Translation | Sampling | Total |
|---|---:|---:|---:|---:|
| Cold (first read after the engines are built) | 197 | 211 | 1 | 429 |
| Warm, full photo (about 960 × 1280) | 111 | 2 | 1 | 114 |
| Warm, stream size (long side 720) | 72 | 2 | 1 | 77 |

Per photo, stream-size warm medians range from 51 ms (es_emergency_dark) to 95 ms (hi_notice, mixed_shop). The worst single stream read was 370 ms (hi_caution), an outlier among 5 reads whose median was 77 ms. The slowest cold read was 775 ms (hi_exit, the first photo, which also creates the Devanagari recognizer).

All 15 photos pass at full size. At stream size, 13 of 15 would pass:
- hi_caution reads 2 paragraphs instead of 1.
- fr_station reads 3 paragraphs instead of 4.

So a live read at `ResolutionPreset.medium` loses a little text that the full photo has.

Observations:
- Warm translation is 1–3 ms: the translation cache answers repeats. A held view's re-reads take this path. A new scene pays the cold translation cost (144–393 ms here).
- Recognition dominates every warm read. Devanagari photos, which run both recognizers, take about 1.5× as long as Latin-only ones (warm full size: 102–152 ms against 71–111 ms).
- Colour sampling is at most 4 ms per read (5 paragraphs).

Live, profile mode, debug HUD, holding still (one reading, 5-paragraph page): read 101 ms (ocr 98, translate 1, colours 2), camera at 30 fps, **frame cost 0.9 ms avg, 5.0 max**. The live read agrees with the replay's stream-size warm reads. Panning slowly with labels shown: **frame cost 1.2 ms avg, 6.0 max**. Both are far below the 8 ms line, so the view's per-frame work (motion estimate and settler) doesn't cause janky frames.

Live, profile mode, DevTools memory chart (screenshot 2026-10-18 01:10, about 5 minutes of scanning): the Dart heap stays at about 30–60 MB in a sawtooth with no upward trend. The process RSS stays flat at about 500–550 MB. That includes the camera buffers and ML Kit's native models and isn't Dart memory. **Memory: flat, no leak trend.** At the same time, the Performance tab's badge showed 466 janky frames since the session started. The session's length and activity aren't known, so this is broken down by holding and panning below.

DevTools Performance view **while panning slowly with labels shown** (screenshot 2026-10-18 01:20, Impeller, frames 12962–12978, 56 fps average against a 60 fps target): no janky frame in the window. UI-thread time per frame is about 1–3 ms, and raster time about 1–10 ms, with the longest raster frame (about 10 ms) still under the 16.7 ms budget. The CPU samples are led by the camera frame stream's microtasks (`_startMicrotaskLoop` → `_BufferingStreamSubscription` → the view's frame handler), then `_drawFrame`. The 466 janky frames in the badge are about 3.6% of the session's roughly 13,000 frames. Panning with labels shown is smooth. So the janky frames came from other parts of the session, such as startup or screen changes, and not from following the camera.

### iPhone 14, iOS 26.6.1 (23G83)

Replay benchmark, 2026-10-18. Raw data: `data/replay_baseline_iphone14.json`. Model downloads took 4.0–11.1 s each. They were detected by checking for the model once a second, because `google_mlkit_translation` 0.15.1 never completes a download's future on iOS (see "Found on iOS" below).

Median across the 15 photos, in ms:

| Read | Recognition | Translation | Sampling | Total |
|---|---:|---:|---:|---:|
| Cold (first read after the engines are built) | 43 | 65 | 1 | 116 |
| Warm, full photo (about 960 × 1280) | 40 | 0 | 1 | 41 |
| Warm, stream size (long side 640) | 34 | 0 | 1 | 35 |

The iPhone reads about 2–3× faster than the M17: stream warm medians run from 20 to 50 ms per photo. Devanagari photos (two recognizers) again take about twice as long as Latin-only ones (warm full size: 41–56 ms against 23–32 ms).

**Accuracy differs from Android:** 4 of 15 photos fail their expectations at full size on iOS, and all 15 pass on the M17. The failing photos are mr_no_parking, mixed_shop, de_wet_paint and en_garden. en_garden reads 6 paragraphs on iOS against 2 on Android, so the iOS recognizer groups lines into paragraphs differently. At stream size, 5 fail: hi_no_smoking, hi_notice, mixed_station, de_wet_paint and en_garden. The failure texts, from the run's console (the replay test now also writes them to the JSON as `frames[].failure`):

| Photo | What iOS read | Kind |
|---|---|---|
| mr_no_parking | "कृपया येथे **बाहन** उभे करू नये" (वाहन misread as बाहन) → "Please should not stand out at". "जाईल" is a paragraph of its own → "Will be". | Recognition error, plus a fragment |
| mixed_shop | "दवा की **दुरकान**" (दुकान misread) → "Drug". "तक" is a paragraph of its own → "Till". | Recognition error, plus a fragment |
| de_wet_paint | One paragraph, "Achtung! Frisch gestrichen Bitte nicht berühren. Die Farbe ist noch" → "Attention! Freshly **deleted** …". Android reads 5 paragraphs here and passes. | Grouping changes the translation |
| en_garden | 6 paragraphs against Android's 2. "Dogs" / "be kept on a lead at all times." are split, and "must" is missing (probably a one-word paragraph with no language found, so left untranslated). "The" → "0". | Fragmented paragraphs |

Conclusions:
- **ML Kit's iOS recognizer groups lines into blocks differently from Android's.** It splits some paragraphs into one-word fragments and merges others. Since a paragraph is a recognizer block, short fragments lose the context that language identification and translation need: a dropped word, "The" → "0". Long merged blocks change how the translation reads. Merging adjacent blocks with matching line height and alignment on our side could fix the fragments. That's a separate change (paragraph grouping), with replay photos as its test.
- **The iOS Devanagari recognizer misreads more** (व → ब, दुकान → दुरकान). We can't fix that; it's a README limitation.
- None of this affects the timings above.

Live, profile mode, debug HUD, holding still: read 40 ms (ocr 38), **frame cost 0.5 ms avg, 2.0 max**. Panning: the user reported the same reading, **0.5 ms avg, 2.0 max**. The live read agrees with the replay's warm reads.

### Found on iOS: model downloads never report completion

`google_mlkit_translation` 0.15.1 with `google_mlkit_commons` 0.13.0, on the iPhone 14:
- `downloadModel` never completes, although the model arrives (it later shows as downloaded). The plugin waits for ML Kit's download notification for its own model object, and it never arrives.
- Any other model call, even a check, replaces the plugin's single download manager, and the replaced manager answers its pending download with `cancelled`. The example's model manager then shows "Couldn't download" for a model that did download.

Effect on the package: on iOS, the live view's automatic download never reports ready, so the source status stays on downloading, and the held picture isn't re-read when the model arrives. This needs its own change before 1.0 (detect completion by checking for the model). It is out of scope for this change.

## Final pass

Build: groups 1–6 (label layout cache, colour luminance once; motion table reverted). Profile mode.

### Samsung Galaxy M17, Android 16

Replay benchmark, 2026-10-19. Raw data: `data/replay_final_samsung_m17.json`. Hindi, Spanish, French and German had to be downloaded again: Hindi took 65 s (network), and the others 5.9–6.3 s.

Median across the 15 photos, in ms, with the baseline in brackets:

| Read | Recognition | Translation | Sampling | Total |
|---|---:|---:|---:|---:|
| Cold | 202 (197) | 196 (211) | 0 (1) | 402 (429) |
| Warm, full photo | 109 (111) | 2 (2) | 0 (1) | 113 (114) |
| Warm, stream size | 72 (72) | 2 (2) | 0 (1) | 75 (77) |

As expected, the reads are unchanged within noise: the tuning touched label painting and colour sampling, not recognition or translation. Sampling's median drops from 1 to 0 ms. All 15 photos pass at full size again, and the same two (hi_caution, fr_station) would fail at stream size.

### iPhone 14, iOS 26.6.1, first final run

Replay benchmark, 2026-10-19 10:15. Raw data: `data/replay_final_iphone14_run1.json`. All models were already on the phone.

Median across the 15 photos, in ms, with the baseline in brackets:

| Read | Recognition | Translation | Sampling | Total |
|---|---:|---:|---:|---:|
| Cold | 70 (43) | 114 (65) | 0 (1) | 170 (116) |
| Warm, full photo | 67 (40) | 0 (0) | 0 (1) | 68 (41) |
| Warm, stream size | 59 (34) | 0 (0) | 0 (1) | 60 (35) |

Every photo is about 1.6–1.7× slower than at baseline, mostly in recognition, which this change didn't touch. That points to the phone's state, such as heat after a long session, Low Power Mode or battery level, rather than the code. Replaced by the rerun below, which is back at baseline. Accuracy is the same as at baseline: the same 4 photos fail at full size and the same 5 at stream size.

### iPhone 14, iOS 26.6.1, rerun on a cool phone (the final)

Replay benchmark, 2026-10-19 10:20, after the phone cooled down. Raw data: `data/replay_final_iphone14.json`. All five models were downloaded again, each detected after about 4 s.

Median across the 15 photos, in ms, with the baseline in brackets:

| Read | Recognition | Translation | Sampling | Total |
|---|---:|---:|---:|---:|
| Cold | 43 (43) | 65 (65) | 0 (1) | 124 (116) |
| Warm, full photo | 40 (40) | 0 (0) | 0 (1) | 41 (41) |
| Warm, stream size | 35 (34) | 0 (0) | 0 (1) | 35 (35) |

Back at baseline, which confirms that the first final run was slowed down by the phone's state. Reads are unchanged by the tuning, as on the M17. Accuracy is unchanged too: the same 4 photos fail at full size and the same 5 at stream size.

Live HUD, iPhone 14, tuned build (2026-10-19): reads of 73, 91, 95, 131 and 188 ms (median 95), ocr 71–92 ms (78, 90, 71, 85, 92, 75), camera at 30–31 fps, **frame cost 0.8–1.1 ms avg, with maxes of 0.8–2.9 ms** (2.9, 1.4, 1.1, 1.6, 1.2, 0.8 across the readings). **The phone was warm** (the user confirmed it), just after two replay runs. That explains recognition at about 2× the baseline's live 38 ms: the replay on a cool phone matched its baseline exactly. The user chose to keep these readings. The README reports the cool-phone replay numbers and notes that a warm phone reads up to about 2× slower.

Live HUD, M17, tuned build (2026-10-19), one reading: read 817 ms, ocr 697 ms, **frame cost 1.2 ms avg, 1.9 max**. The read is about 8× the baseline's live 101 ms. It's probably a cold read (the first after the app started, which builds the recognizers: the replay's first cold read took 380 ms of recognition on this phone) or a warm phone. A second read stayed high: read 653 ms, ocr 579 ms, frame cost 1.2 ms avg, 2.9 max. Cause: the camera was framing es_menu_lunch on the Mac screen together with the surrounding window and menu-bar text, 11 paragraphs instead of the photo's 5. **Controlled reading, with the photo full screen and filling the view (5 paragraphs): read 112 ms, ocr 98 ms.** That matches the baseline's 101 / 98 ms, so live reads are unchanged by the tuning. The 11-paragraph readings show how text outside the subject slows a read: about 6× here.

DevTools Performance view, M17, tuned build (2026-10-19, user's report): **80–85 fps on average, with fewer janky (slow) frame bars than at baseline.** At baseline the view showed 56 fps against a 60 fps target. 80–85 fps means the display ran at its 90 Hz refresh rate this time (an 11.1 ms frame budget instead of 16.7 ms), so the two fps figures aren't directly comparable: the tuned build is keeping up with a tighter budget. This was **while panning slowly with labels shown**, as at baseline. **None of the janky frames show package code** (the user checked the frames): they come from outside the view's per-frame work and label painting.

DevTools memory view, M17, tuned build (2026-10-19, user's report): over about 2 minutes of scanning, the Dart heap stays flat in the same sawtooth as at baseline, with **no upward trend**. The user didn't note heap figures this time; the baseline's range was 30–60 MB.

Note: the example app captures at `ResolutionPreset.high` (1280 × 720; `example/lib/camera_screen.dart:262`), while the package defaults to `medium` (720 × 480 on Android, 640 × 480 on iOS). Live HUD readings are therefore at `high`, and the replay's stream-size numbers at `medium`.

## Budget verdict

Checked against design decision 7 using the Samsung Galaxy M17's final-pass numbers.

| Budget line | Limit | M17 final | Verdict |
|---|---|---|---|
| Read time (warm median total at stream size) | ≤ 500 ms | 75 ms (replay) | **Pass** |
| UI frame cost | worst ≤ 8 ms while holding or panning, and no janky frames from the package | HUD worst 2.9 ms (1.2 ms avg). DevTools while panning with labels: 80–85 fps at 90 Hz, and no janky frame shows package code | **Pass** |
| Steady to labels | ≤ 800 ms | about 412 ms (300 ms settle + the controlled live read of 112 ms) | **Pass** |
| Memory | no upward trend over 2 minutes | flat sawtooth over 2 minutes, no upward trend (same as baseline) | **Pass** |

Every line passes. **No gated tuning needed** (task 8.1).
