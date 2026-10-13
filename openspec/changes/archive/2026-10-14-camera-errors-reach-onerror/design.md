# Design

## Context

See proposal.md for the motivation. In `PluginCameraSession`, `_start` maps failures from listing cameras and from `initialize()`, but not from `_startStream`. `pause()` and `resume()` map nothing. Every operation runs through `_serially`. In the view, `_start` catches `LiveTranslateException` and reports it, but `freeze()` and `resume()` await the session without a `try`.

## Goals / Non-Goals

**Goals:** every `capture` delta scenario is tested. Camera failures can't escape the controller's `freeze()` or `resume()`.

**Non-Goals:**
- Retrying a failed camera.
- New error types: a failure that isn't about permission stays `CameraUnavailable`, as `mapCameraError` already decides.

## Decisions

**D1. One mapping point.**

`start`, `pause` and `resume` pass their operation through a `_mapped` wrapper inside `_serially`, which rethrows any failure as `mapCameraError(error)`. `stop` and `setTorch` already swallow camera failures by design, so they're unchanged. One wrapper means a new failure point inside these operations, such as the stream, is mapped automatically.

**D2. A failed pause still freezes.** By the time it pauses, the view has already marked itself frozen and stopped using frames, so the labels hold still. Only the preview may keep moving. Reporting and staying frozen is the least surprising outcome for the app's freeze button.

Alternative: revert to running. Rejected: the result already on screen would be thrown away for a cosmetic failure.

**D3. A failed resume is an error state.** The camera's preview and stream state are unknown, so the view sets `_error`, as a failed start does, and reports. The existing lifecycle restart (background, then return) starts the camera again and clears the error.

## Risks / Trade-offs

- **[The plugin's stream-start failure isn't unit-tested]** → Driving a real `CameraController` through `initialize` needs a full fake `CameraPlatform`. The wrapper is tested through the camera-listing hook with a non-camera failure, and stream start goes through the same wrapper by construction (D1).
- **[A failed pause leaves the preview moving under frozen labels]** → Rare (the camera is failing). It's reported, so the app can tell the user.
