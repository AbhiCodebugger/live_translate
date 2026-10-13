# Tasks

## 1. Pin the moved behaviours with tests

- [x] 1.1 In `test/pipeline/line_translator_test.dart`, add or extend tests so each scenario of the two new requirements has a dedicated assertion:
  - "First frame with the target missing": under the `{hindi}` hint, with the Hindi model present and English missing, one Hindi frame starts `(english, wifiOnly: true)`;
  - "Download requested over Wi-Fi only": that download is requested with Wi-Fi required, and exactly one `ModelNotDownloaded(english)` is reported;
  - "Retry is reported again": extend the existing retry test to assert two `ModelNotDownloaded(hindi)` reports.

  Verify the new assertions pass **without changing any code under `lib/`**. If one fails, stop: the split would have changed the spec's meaning, and the delta must be revisited.

## 2. Checks

- [x] 2.1 Run the checks. Verify that:
  - `openspec validate split-model-download-requirement --strict` passes;
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test` passes;
  - `git diff --stat lib/` is empty (no code changed).

## Workflow follow-up

- Archive the change with spec sync, then confirm that `openspec validate translate --type spec --strict` passes and that `translate` has 10 requirements.
