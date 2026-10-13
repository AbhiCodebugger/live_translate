# Proposal

## Why

On the device, picking a target language whose model isn't downloaded leaves the view blank: the held picture is never translated, even after the download finishes, until the user freezes or moves the camera. The `live-translation` spec already requires a completed download to refresh the held result. The view only honours that for **source** models, and it loses the event entirely if the download finishes while a read is running.

## What Changes

- **A finished target download re-reads the held or frozen frame**, just as a finished source download already does. Today a read that lacked the target model records only its source languages as missing. So when the target's download completes, the view doesn't recognise that the held result was waiting for it.
- **A download that finishes during a read is not lost.** Today the view ignores a model-ready event while a read is running. If that read was itself missing the model, the held result stays untranslated. After this change, the read's result is checked against the models that became ready while it ran, and it is read again if it lacked one.
- Not in this change:
  - performance work: keeping recognizers across settings changes, warming translators, loosening language confirmation;
  - measuring stage timings;
  - any online translation.

  These were discussed and deferred.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `live-translation`: "A completed download refreshes the held result" names both source and target models explicitly. It gains scenarios for a target download and for a download that finishes while a read is running.

## Impact

- **Changed code:**
  - `lib/src/pipeline/pipeline.dart` (a read that lacked the target model reports the target as missing)
  - `lib/src/view/live_translate_view.dart` (model-ready handling during a read)
  - `test/pipeline/pipeline_test.dart` and `test/view/live_translate_view_test.dart`
- **Public API:** unchanged.
- **Dependencies:** none.
- **Example app:** no code change. Picking an undownloaded target now shows translations once its model arrives, with the target chip's spinner during the download.
