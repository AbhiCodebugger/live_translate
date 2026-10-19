import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/pipeline/pipeline_metrics.dart';
import 'package:live_translate/src/view/debug_hud.dart';

PipelineMetrics _metrics({int paragraphs = 1, bool frozen = false}) =>
    PipelineMetrics(
      recognition: const Duration(milliseconds: 120),
      translation: const Duration(milliseconds: 80),
      sampling: const Duration(milliseconds: 10),
      total: const Duration(milliseconds: 214),
      paragraphs: paragraphs,
      frozen: frozen,
    );

void main() {
  test('before any read', () {
    expect(
      DebugHud.linesFor((latest: null, framesPerSecond: 30, frameCost: null)),
      ['no read yet', '30 fps'],
    );
  });

  test('after a read', () {
    expect(
      DebugHud.linesFor((
        latest: _metrics(),
        framesPerSecond: 30,
        frameCost: null,
      )),
      [
        'read 214 ms',
        'ocr 120 · translate 80 · colours 10',
        '1 paragraph · 30 fps',
      ],
    );
  });

  test('a frozen read with several paragraphs', () {
    final lines = DebugHud.linesFor((
      latest: _metrics(paragraphs: 3, frozen: true),
      framesPerSecond: 0,
      frameCost: null,
    ));
    expect(lines.first, 'read 214 ms (frozen)');
    expect(lines.last, '3 paragraphs · 0 fps');
  });

  test('the frame cost follows the frame rate', () {
    final lines = DebugHud.linesFor((
      latest: null,
      framesPerSecond: 30,
      frameCost: (
        mean: const Duration(microseconds: 2150),
        worst: const Duration(microseconds: 6500),
      ),
    ));
    expect(lines.last, '30 fps · frame 2.2 ms avg, 6.5 max');
  });

  test('the frame cost rounds to a tenth of a millisecond', () {
    final lines = DebugHud.linesFor((
      latest: _metrics(),
      framesPerSecond: 12,
      frameCost: (
        mean: const Duration(microseconds: 940),
        worst: const Duration(microseconds: 12049),
      ),
    ));
    expect(lines.last, '1 paragraph · 12 fps · frame 0.9 ms avg, 12.0 max');
  });

  testWidgets('shows the data and follows changes', (tester) async {
    final data = ValueNotifier<DebugHudData>((
      latest: null,
      framesPerSecond: 0,
      frameCost: null,
    ));
    addTearDown(data.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DebugHud(data: data),
      ),
    );
    expect(find.text('no read yet\n0 fps'), findsOneWidget);

    data.value = (latest: _metrics(), framesPerSecond: 30, frameCost: null);
    await tester.pump();
    expect(find.textContaining('ocr 120'), findsOneWidget);
    expect(find.byType(IgnorePointer), findsWidgets);
  });

  testWidgets('stays clear of the status bar', (tester) async {
    final data = ValueNotifier<DebugHudData>((
      latest: null,
      framesPerSecond: 0,
      frameCost: null,
    ));
    addTearDown(data.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DebugHud(data: data),
        ),
      ),
    );
    // The panel's background starts below the 40 px inset, plus its margin.
    expect(tester.getTopLeft(find.byType(DecoratedBox)).dy, 48);
  });
}
