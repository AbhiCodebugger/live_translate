import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/models/overlay_style.dart';
import 'package:live_translate/src/view/paragraph_painter.dart';

// The FlutterTest font draws every glyph one font size wide and a line one
// font size tall, so sizes below follow from character counts.

const _style = OverlayStyle();

double _fit(
  String text,
  Size inner,
  double lineHeight, {
  OverlayStyle style = _style,
}) => fitParagraphFontSize(
  text: text,
  inner: inner,
  lineHeight: lineHeight,
  style: style,
  direction: TextDirection.ltr,
);

void main() {
  group('fitParagraphFontSize', () {
    test('20-high lines start at size 16', () {
      expect(_fit('Short', const Size(300, 44), 20), 16);
    });

    test('a longer text shrinks to the first size that fits', () {
      // A 19- and a 20-letter word in 300 × 44: at 16, 18 characters fit a
      // line, so each word wraps and overflows; at 15, 20 fit, so the words
      // take two lines, 30 high.
      expect(_fit('${'a' * 19} ${'b' * 20}', const Size(300, 44), 20), 15);
    });

    test('a too-long text stops at the minimum', () {
      expect(_fit('word ' * 200, const Size(300, 44), 20), 10);
    });

    test('a 50-high heading stops at the default maximum of 28', () {
      expect(_fit('Why', const Size(300, 50), 50), 28);
    });

    test('a larger maximum lets a 50-high heading start at 40', () {
      expect(
        _fit(
          'Why',
          const Size(300, 50),
          50,
          style: const OverlayStyle(maxFontSize: 48),
        ),
        40,
      );
    });
  });

  group('placeParagraphLabels', () {
    ParagraphLabel label(Rect rect, String text, {double lineHeight = 24}) =>
        ParagraphLabel(
          rect: rect,
          lineHeight: lineHeight,
          text: text,
          background: const Color(0xFFF8F8F4),
          ink: const Color(0xFF141419),
        );

    List<Rect> place(List<ParagraphLabel> labels) => placeParagraphLabels(
      labels,
      const Size(360, 800),
      style: _style,
      direction: TextDirection.ltr,
    );

    test('a paragraph wider than the view is limited to it', () {
      // At size 16 the text needs more than one line of 320.
      final placed = place([
        label(
          const Rect.fromLTRB(40, 600, 460, 680),
          'word ' * 12,
          lineHeight: 20,
        ),
      ]);
      expect(placed.single, const Rect.fromLTRB(40, 600, 360, 680));
    });

    test('a short heading grows right and keeps its size', () {
      // 24-high lines start at size 19. "Where is it from?" is 17
      // characters, 323 wide: too wide for 120, but fits once widened to 340.
      const text = 'Where is it from?';
      final placed = place([
        label(const Rect.fromLTRB(20, 100, 140, 124), text),
      ]);
      expect(placed.single, const Rect.fromLTRB(20, 100, 360, 124));
      expect(
        fitParagraphFontSize(
          text: text,
          inner: placed.single.size,
          lineHeight: 24,
          style: _style,
          direction: TextDirection.ltr,
        ),
        19,
      );
    });

    test('growth stops at a label beside it, then goes down', () {
      final placed = place([
        label(const Rect.fromLTRB(20, 100, 140, 124), 'Where is it from?'),
        label(const Rect.fromLTRB(200, 90, 340, 130), 'Neighbour'),
      ]);
      expect(placed.first, const Rect.fromLTRB(20, 100, 200, 148));
      expect(placed.last, const Rect.fromLTRB(200, 90, 340, 130));
    });

    test('downward growth stops at the label below', () {
      final placed = place([
        label(const Rect.fromLTRB(20, 100, 140, 124), 'Where is it from?'),
        label(const Rect.fromLTRB(200, 90, 340, 130), 'Neighbour'),
        label(const Rect.fromLTRB(10, 136, 340, 160), 'Below'),
      ]);
      expect(placed.first, const Rect.fromLTRB(20, 100, 200, 136));
    });

    test('a translation that fits keeps its rectangle', () {
      final placed = place([
        label(const Rect.fromLTRB(20, 100, 140, 124), 'Why'),
      ]);
      expect(placed.single, const Rect.fromLTRB(20, 100, 140, 124));
    });
  });

  group('ParagraphPainter', () {
    const label = ParagraphLabel(
      rect: Rect.fromLTRB(20, 100, 300, 144),
      lineHeight: 20,
      text: 'It has long been known',
      background: Color(0xFFF8F8F4),
      ink: Color(0xFF141419),
    );

    void Function(Canvas) painting(
      List<ParagraphLabel> labels, {
      OverlayStyle style = _style,
    }) =>
        (canvas) => ParagraphPainter(
          labels: labels,
          style: style,
          textDirection: TextDirection.ltr,
        ).paint(canvas, const Size(360, 800));

    test('covers the paragraph in its page colour, fully opaque', () {
      expect(
        painting([
          const ParagraphLabel(
            rect: Rect.fromLTRB(20, 100, 300, 144),
            lineHeight: 20,
            text: 'It has long been known',
            background: Color(0x80F8F8F4),
            ink: Color(0xFF141419),
          ),
        ]),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTRB(16, 98, 304, 146),
            const Radius.circular(6),
          ),
          color: const Color(0xFFF8F8F4),
        ),
      );
    });

    test("ignores the style's colours", () {
      expect(
        painting([
          label,
        ], style: const OverlayStyle(backgroundColor: Color(0xFFFFEB3B))),
        paints..rrect(color: const Color(0xFFF8F8F4)),
      );
    });

    test('half opacity halves both alphas', () {
      expect(
        painting([
          const ParagraphLabel(
            rect: Rect.fromLTRB(20, 100, 300, 144),
            lineHeight: 20,
            text: 'It has long been known',
            background: Color(0xFFF8F8F4),
            ink: Color(0xFF141419),
            opacity: 0.5,
          ),
        ]),
        paints..rrect(color: const Color(0xFFF8F8F4).withValues(alpha: 0.5)),
      );
    });

    test('opacity 0 draws nothing', () {
      expect(
        painting([
          const ParagraphLabel(
            rect: Rect.fromLTRB(20, 100, 300, 144),
            lineHeight: 20,
            text: 'It has long been known',
            background: Color(0xFFF8F8F4),
            ink: Color(0xFF141419),
            opacity: 0,
          ),
        ]),
        paintsNothing,
      );
    });

    test('repaints only when something changes', () {
      ParagraphPainter make([List<ParagraphLabel> labels = const [label]]) =>
          ParagraphPainter(
            labels: labels,
            style: _style,
            textDirection: TextDirection.ltr,
          );
      expect(make().shouldRepaint(make()), isFalse);
      expect(make().shouldRepaint(make(const [])), isTrue);
    });
  });

  group('LabelLayoutCache', () {
    const size = Size(360, 800);

    ParagraphLabel label({
      Offset shift = Offset.zero,
      String text = 'It has long been known that readable text distracts',
      double lineHeight = 20,
      Color ink = const Color(0xFF141419),
    }) => ParagraphLabel(
      rect: const Rect.fromLTRB(20, 100, 300, 144).shift(shift),
      lineHeight: lineHeight,
      text: text,
      background: const Color(0xFFF8F8F4),
      ink: ink,
    );

    void paint(
      LabelLayoutCache cache,
      List<ParagraphLabel> labels, {
      OverlayStyle style = _style,
      TextDirection direction = TextDirection.ltr,
    }) {
      final recorder = PictureRecorder();
      ParagraphPainter(
        labels: labels,
        style: style,
        textDirection: direction,
        layoutCache: cache,
      ).paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }

    test('labels that only moved are not laid out again', () {
      final cache = LabelLayoutCache();
      addTearDown(cache.dispose);
      // Short enough to fit without growing, so moving keeps its size.
      const text = 'Readable text';
      paint(cache, [label(text: text)]);
      final first = cache.layouts;
      expect(first, greaterThan(0));
      // Fractional shifts, as the camera gives, change the rect's exact
      // width by rounding errors.
      for (var dx = 0.1; dx <= 30; dx += 0.7) {
        paint(cache, [label(text: text, shift: Offset(dx, dx / 3))]);
      }
      expect(cache.layouts, first);
    });

    test('a label grown to the edge is fitted again as its width changes', () {
      final cache = LabelLayoutCache();
      addTearDown(cache.dispose);
      paint(cache, [label()]);
      final first = cache.layouts;
      paint(cache, [label(shift: const Offset(5, 0))]);
      expect(cache.layouts, greaterThan(first));
    });

    test('a change to anything the layout depends on lays out again', () {
      final cache = LabelLayoutCache();
      addTearDown(cache.dispose);
      paint(cache, [label()]);
      for (final change in <void Function()>[
        () => paint(cache, [label(text: 'Something else entirely')]),
        () => paint(cache, [label(lineHeight: 30)]),
        () => paint(cache, [label(ink: const Color(0xFFFFFFFF))]),
        () => paint(cache, [
          label(shift: const Offset(200, 0)), // narrowed by the view's edge
        ]),
        () => paint(cache, [
          label(),
        ], style: const OverlayStyle(fontWeight: FontWeight.w300)),
        () => paint(cache, [label()], direction: TextDirection.rtl),
      ]) {
        final before = cache.layouts;
        change();
        expect(cache.layouts, greaterThan(before));
      }
    });

    testWidgets('paints the same pixels as without a cache', (tester) async {
      final cache = LabelLayoutCache();
      addTearDown(cache.dispose);
      final labels = [
        label(),
        label(shift: const Offset(0, 200), text: 'Platform closed'),
      ];
      Future<List<int>> render(LabelLayoutCache? cache) async {
        final recorder = PictureRecorder();
        ParagraphPainter(
          labels: labels,
          style: _style,
          textDirection: TextDirection.ltr,
          layoutCache: cache,
        ).paint(Canvas(recorder), size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 800);
        final bytes = await image.toByteData();
        image.dispose();
        picture.dispose();
        return bytes!.buffer.asUint8List();
      }

      await tester.runAsync(() async {
        final uncached = await render(null);
        // Twice: once filling the cache, once from it.
        expect(await render(cache), uncached);
        expect(await render(cache), uncached);
      });
    });

    test('keeps at most its capacity of laid-out translations', () {
      final cache = LabelLayoutCache(capacity: 2);
      addTearDown(cache.dispose);
      for (var i = 0; i < 5; i++) {
        paint(cache, [label(text: 'Translation number $i')]);
      }
      expect(cache.painterCount, 2);
    });

    test('dispose drops everything', () {
      final cache = LabelLayoutCache();
      paint(cache, [label()]);
      cache.dispose();
      expect(cache.painterCount, 0);
      final before = cache.layouts;
      paint(cache, [label()]);
      expect(cache.layouts, greaterThan(before));
      cache.dispose();
    });
  });

  testWidgets('golden: page-coloured paragraphs', (tester) async {
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: 320,
            height: 240,
            child: ColoredBox(
              color: const Color(0xFF808080),
              child: CustomPaint(
                painter: ParagraphPainter(
                  labels: const [
                    // Grows right: the translation is longer than the heading.
                    ParagraphLabel(
                      rect: Rect.fromLTWH(10, 10, 90, 24),
                      lineHeight: 24,
                      text: 'Where from?',
                      background: Color(0xFFF8F8F4),
                      ink: Color(0xFF141419),
                    ),
                    ParagraphLabel(
                      rect: Rect.fromLTWH(10, 50, 300, 60),
                      lineHeight: 20,
                      text:
                          'It has long been known that readable text '
                          'distracts from the layout.',
                      background: Color(0xFFF8F8F4),
                      ink: Color(0xFF141419),
                    ),
                    // Cropped: runs past the right edge of the 320-wide view.
                    ParagraphLabel(
                      rect: Rect.fromLTWH(160, 130, 300, 60),
                      lineHeight: 20,
                      text: 'Platform closed for repairs, use the bridge',
                      background: Color(0xFF143CC8),
                      ink: Color(0xFFFFFFFF),
                    ),
                  ],
                  style: _style,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/paragraph_labels.png'),
    );
    // Recorded on macOS: other platforms anti-alias slightly differently.
  }, tags: ['golden']);
}
