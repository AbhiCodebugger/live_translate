import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/models/overlay_style.dart';
import 'package:live_translate/src/view/paragraph_painter.dart';

// The FlutterTest font draws every glyph one font size wide and a line one
// font size tall, so sizes below follow from character counts.

const _style = OverlayStyle();

double _fit(String text, Size inner, double lineHeight) => fitParagraphFontSize(
  text: text,
  inner: inner,
  lineHeight: lineHeight,
  style: _style,
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

    test('a 50-high heading starts at 40, above the live maximum', () {
      expect(_fit('Why', const Size(300, 50), 50), 40);
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
  });
}
