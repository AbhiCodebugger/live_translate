import 'dart:ui' show Offset, Size;

import '../motion/motion_estimator.dart';

/// A frame is steady when it shifted by less than this share of the frame's
/// width, and changed by less than [steadyChange].
const steadyShift = 0.01;

/// A steady frame's largest change beyond its shift.
const steadyChange = 10.0;

/// A frame that shifted by more than this share of the frame's width is a
/// fast movement, which clears the labels.
const sceneShift = 0.08;

/// A change beyond the shift above this is a new scene, which clears the
/// labels.
const sceneChange = 18.0;

/// How long the picture must stay steady before it is read.
const settleTime = Duration(milliseconds: 300);

/// While the source language isn't settled, a steady picture is read again
/// this long after the previous read finished.
const rereadInterval = Duration(seconds: 1);

/// Once the labels have followed more than this share of the frame's width
/// or height, a steady picture is read again.
const panShare = 0.10;

/// Freezing keeps the shown labels while they have followed less than this
/// share of the frame's width and height.
const freezeKeepShare = 0.02;

/// What the live view should do after a frame.
enum SettleAction {
  /// Nothing new.
  none,

  /// Read this frame.
  read,

  /// Fade out the labels, and discard any read in progress.
  clear,
}

/// Decides when the live view reads and how its labels follow the picture:
/// read once the picture settles, hold the result while the labels follow
/// small movements, read again after a pan or while [unsettled], clear on
/// fast movement or a new scene.
final class LiveSettler {
  /// Creates a settler reading the time from [now].
  LiveSettler({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  DateTime? _steadySince;
  DateTime? _finishedAt;
  bool _hasResult = false;
  bool _reading = false;
  bool _waitForMovement = false;
  Offset _shownOffset = Offset.zero;
  Offset _pendingOffset = Offset.zero;
  Size _frameSize = Size.zero;

  /// Whether the shown result's source language isn't settled yet, so a
  /// steady picture is read again every [rereadInterval]. Set by the view
  /// after each read.
  bool unsettled = false;

  /// How far the shown labels have to be moved: the picture's total shift
  /// since the frame they were read from.
  Offset get offset => _shownOffset;

  /// The total shift since the frame being read, to give its result.
  Offset get pendingOffset => _pendingOffset;

  /// Whether a read is running.
  bool get reading => _reading;

  /// Whether a result is shown.
  bool get hasResult => _hasResult;

  /// Whether freezing can keep the shown labels without reading: a result is
  /// shown, no read is running, and the picture has barely moved since.
  bool get canKeepOnFreeze =>
      _hasResult &&
      !_reading &&
      _shownOffset.dx.abs() < freezeKeepShare * _frameSize.width &&
      _shownOffset.dy.abs() < freezeKeepShare * _frameSize.height;

  /// Takes in one frame's [motion] in an upright frame of [frameSize].
  SettleAction onFrame(Motion motion, Size frameSize) {
    _frameSize = frameSize;
    final width = frameSize.width;

    if (!motion.isKnown) {
      _steadySince = null;
      return _clear();
    }
    if (motion.shift.distance > sceneShift * width ||
        motion.change > sceneChange) {
      _steadySince = null;
      _waitForMovement = false;
      return _clear();
    }

    if (_hasResult) _shownOffset += motion.shift;
    if (_reading) _pendingOffset += motion.shift;

    final steady =
        motion.shift.distance < steadyShift * width &&
        motion.change < steadyChange;
    if (!steady) {
      _steadySince = null;
      _waitForMovement = false;
      return SettleAction.none;
    }
    final now = _now();
    final since = _steadySince ??= now;
    if (_reading || _waitForMovement || now.difference(since) < settleTime) {
      return SettleAction.none;
    }
    if (!_hasResult) return SettleAction.read;
    if (unsettled && now.difference(_finishedAt ?? now) >= rereadInterval) {
      return SettleAction.read;
    }
    final panned =
        _shownOffset.dx.abs() > panShare * width ||
        _shownOffset.dy.abs() > panShare * frameSize.height;
    return panned ? SettleAction.read : SettleAction.none;
  }

  /// Notes that a read started, of the frame that was just measured, or of
  /// an earlier frame whose shift since is [shiftSince].
  void readStarted({Offset shiftSince = Offset.zero}) {
    _reading = true;
    _pendingOffset = shiftSince;
  }

  /// Notes that the running read finished, showing its result if
  /// [success].
  ///
  /// After a failure, the picture has to move and settle again before it is
  /// read again, so a lasting failure isn't retried on every settle.
  void readFinished({required bool success}) {
    if (!_reading) return;
    _reading = false;
    if (success) {
      _hasResult = true;
      _finishedAt = _now();
      _shownOffset = _pendingOffset;
    } else {
      _waitForMovement = true;
    }
  }

  /// Notes that the running read was abandoned by the view, for example
  /// because the settings changed. Unlike a failure, the next settle may
  /// read straight away.
  void readCancelled() => _reading = false;

  /// Forgets the shown result and any read, as when the camera restarts.
  void reset() {
    _steadySince = null;
    _finishedAt = null;
    unsettled = false;
    _hasResult = false;
    _reading = false;
    _waitForMovement = false;
    _shownOffset = Offset.zero;
    _pendingOffset = Offset.zero;
  }

  SettleAction _clear() {
    final hadSomething = _hasResult || _reading;
    _hasResult = false;
    _reading = false;
    _shownOffset = Offset.zero;
    _pendingOffset = Offset.zero;
    return hadSomething ? SettleAction.clear : SettleAction.none;
  }
}
