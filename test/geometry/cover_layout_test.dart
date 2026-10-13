import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/geometry/coordinate_mapper.dart';

void main() {
  group('CoverLayout.fit', () {
    test('crops a wide frame left and right in a tall view', () {
      final layout = CoverLayout.fit(
        uprightSize: const Size(720, 1280),
        viewSize: const Size(360, 800),
      );
      expect(layout.scale, 0.625);
      expect(layout.offset, const Offset(-45, 0));
      expect(layout.previewRect, const Rect.fromLTRB(-45, 0, 405, 800));
    });

    test('needs no crop when the aspect ratios match', () {
      final layout = CoverLayout.fit(
        uprightSize: const Size(720, 1280),
        viewSize: const Size(360, 640),
      );
      expect(layout.scale, 0.5);
      expect(layout.previewRect, const Rect.fromLTWH(0, 0, 360, 640));
    });

    test('returns an empty layout for an empty view', () {
      final layout = CoverLayout.fit(
        uprightSize: const Size(720, 1280),
        viewSize: Size.zero,
      );
      expect(layout.scale, 0);
      expect(layout.previewRect, Rect.zero);
    });

    test('returns an empty layout for an empty frame', () {
      final layout = CoverLayout.fit(
        uprightSize: Size.zero,
        viewSize: const Size(360, 800),
      );
      expect(layout.scale, 0);
      expect(layout.previewRect, Rect.zero);
    });

    test('has value equality', () {
      CoverLayout fit() => CoverLayout.fit(
        uprightSize: const Size(720, 1280),
        viewSize: const Size(360, 800),
      );
      expect(fit(), fit());
      expect(fit().hashCode, fit().hashCode);
      expect(
        fit(),
        isNot(
          CoverLayout.fit(
            uprightSize: const Size(720, 1280),
            viewSize: const Size(360, 640),
          ),
        ),
      );
    });
  });
}
