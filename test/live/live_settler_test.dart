import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/live/live_settler.dart';
import 'package:live_translate/src/motion/motion_estimator.dart';

const _frame = Size(1280, 720);
const _still = Motion(Offset.zero, 2);

void main() {
  late DateTime now;
  late LiveSettler settler;

  setUp(() {
    now = DateTime(2026);
    settler = LiveSettler(now: () => now);
  });

  /// Feeds [motion] once, after [after] has passed.
  SettleAction frame([
    Motion motion = _still,
    Duration after = const Duration(milliseconds: 33),
  ]) {
    now = now.add(after);
    return settler.onFrame(motion, _frame);
  }

  /// Feeds still frames for [duration], returning every action.
  List<SettleAction> holdStill(Duration duration) => [
    for (var t = 0; t < duration.inMilliseconds; t += 33) frame(),
  ];

  /// Settles, reads and finishes the read successfully.
  void showResult() {
    expect(
      holdStill(const Duration(milliseconds: 400)),
      contains(SettleAction.read),
    );
    settler
      ..readStarted()
      ..readFinished(success: true);
  }

  test('a sweep never reads', () {
    final actions = [
      for (var i = 0; i < 60; i++) frame(const Motion(Offset(20, 0), 4)),
    ];
    expect(actions, everyElement(SettleAction.none));
  });

  test('200 ms steady reads nothing; 300 ms reads once', () {
    frame(Motion.unknown);
    expect(
      holdStill(const Duration(milliseconds: 200)),
      everyElement(SettleAction.none),
    );
    expect(
      holdStill(const Duration(milliseconds: 150)),
      contains(SettleAction.read),
    );
    settler.readStarted();
    expect(
      holdStill(const Duration(seconds: 1)),
      everyElement(SettleAction.none),
    );
  });

  test('nothing more is read while holding still', () {
    showResult();
    expect(
      holdStill(const Duration(seconds: 10)),
      everyElement(SettleAction.none),
    );
  });

  test('drifts add up into the offset', () {
    showResult();
    for (var i = 0; i < 3; i++) {
      frame(const Motion(Offset(-10, 0), 3));
    }
    expect(settler.offset, const Offset(-30, 0));
  });

  test("movement during a read is given to that read's result", () {
    holdStill(const Duration(milliseconds: 400));
    settler.readStarted();
    frame(const Motion(Offset(0, 10), 3));
    settler.readFinished(success: true);
    expect(settler.offset, const Offset(0, 10));
  });

  test('a fast jump clears, then waits to settle again', () {
    showResult();
    expect(frame(const Motion(Offset(192, 0), 5)), SettleAction.clear);
    expect(settler.hasResult, isFalse);
    expect(
      holdStill(const Duration(milliseconds: 250)),
      everyElement(SettleAction.none),
    );
    expect(
      holdStill(const Duration(milliseconds: 100)),
      contains(SettleAction.read),
    );
  });

  test('a new scene clears', () {
    showResult();
    expect(frame(const Motion(Offset.zero, 25)), SettleAction.clear);
  });

  test('a clear during a read discards it', () {
    holdStill(const Duration(milliseconds: 400));
    settler.readStarted();
    expect(frame(const Motion(Offset.zero, 25)), SettleAction.clear);
    settler.readFinished(success: true);
    expect(settler.hasResult, isFalse);
  });

  test('a pan of 20% of the height reads again once steady', () {
    showResult();
    for (var i = 0; i < 12; i++) {
      frame(const Motion(Offset(0, -12), 4)); // 144 = 20% of 720
    }
    expect(
      holdStill(const Duration(milliseconds: 400)),
      contains(SettleAction.read),
    );
  });

  test('a drift of 4% does not read again', () {
    showResult();
    for (var i = 0; i < 4; i++) {
      frame(const Motion(Offset(12.8, 0), 4)); // 51 = 4% of 1280
    }
    expect(
      holdStill(const Duration(seconds: 2)),
      everyElement(SettleAction.none),
    );
  });

  test('settling during a read asks nothing more', () {
    holdStill(const Duration(milliseconds: 400));
    settler.readStarted();
    expect(
      holdStill(const Duration(seconds: 2)),
      everyElement(SettleAction.none),
    );
  });

  test('a failed read waits for movement before reading again', () {
    holdStill(const Duration(milliseconds: 400));
    settler
      ..readStarted()
      ..readFinished(success: false);
    expect(
      holdStill(const Duration(seconds: 2)),
      everyElement(SettleAction.none),
    );
    frame(const Motion(Offset(40, 0), 4));
    expect(
      holdStill(const Duration(milliseconds: 400)),
      contains(SettleAction.read),
    );
  });

  test('freezing keeps the labels under 2%, not at 12%', () {
    showResult();
    frame(const Motion(Offset(10, 0), 3));
    expect(settler.canKeepOnFreeze, isTrue);
    for (var i = 0; i < 10; i++) {
      frame(const Motion(Offset(0, 8.64), 3)); // 86 = 12% of 720
    }
    expect(settler.canKeepOnFreeze, isFalse);
  });

  test('re-reading the held frame starts from its offset', () {
    showResult();
    frame(const Motion(Offset(6, 0), 3));
    settler
      ..readStarted(shiftSince: settler.offset)
      ..readFinished(success: true);
    expect(settler.offset, const Offset(6, 0));
  });
}
