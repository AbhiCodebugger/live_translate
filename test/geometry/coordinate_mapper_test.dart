import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/geometry/coordinate_mapper.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';

const _frame = Size(1280, 720);
const _box = Rect.fromLTRB(100, 200, 300, 260);
const _epsilon = 1e-9;

Rect _map(
  Rect box, {
  Size frame = _frame,
  required ImageRotation rotation,
  required Size view,
}) => CoordinateMapper(
  imageSize: frame,
  rotation: rotation,
  viewSize: view,
).mapToView(box);

void main() {
  group('spec scenarios', () {
    test('back camera in portrait', () {
      expect(
        _map(_box, rotation: ImageRotation.deg90, view: const Size(360, 800)),
        const Rect.fromLTRB(17.5, 125, 142.5, 162.5),
      );
    });

    test('back camera in landscape', () {
      expect(
        _map(_box, rotation: ImageRotation.deg0, view: const Size(800, 360)),
        const Rect.fromLTRB(62.5, 80, 187.5, 117.5),
      );
    });

    test('270 degrees maps like 90 degrees', () {
      expect(
        _map(_box, rotation: ImageRotation.deg270, view: const Size(360, 800)),
        const Rect.fromLTRB(17.5, 125, 142.5, 162.5),
      );
    });

    test('a box in the cropped margin is not clipped', () {
      expect(
        _map(
          const Rect.fromLTRB(0, 0, 40, 40),
          rotation: ImageRotation.deg90,
          view: const Size(360, 800),
        ),
        const Rect.fromLTRB(-45, 0, -20, 25),
      );
    });

    test('an empty view gives an empty rect at the origin', () {
      expect(
        _map(_box, rotation: ImageRotation.deg90, view: Size.zero),
        Rect.zero,
      );
    });

    test('an empty frame gives an empty rect at the origin', () {
      expect(
        _map(
          _box,
          frame: Size.zero,
          rotation: ImageRotation.deg90,
          view: const Size(360, 800),
        ),
        Rect.zero,
      );
    });
  });

  group('invariants across every combination', () {
    const frames = [Size(1280, 720), Size(640, 480)];
    const views = [
      Size(360, 800), // portrait phone
      Size(800, 360), // landscape phone
      Size(768, 1024), // portrait tablet
      Size(1024, 768), // landscape tablet
    ];
    final cases = [
      for (final rotation in ImageRotation.values)
        for (final frame in frames)
          for (final view in views) (rotation, frame, view),
    ];

    test('covers all 32 combinations', () {
      expect(cases, hasLength(32));
    });

    for (final (rotation, frame, view) in cases) {
      final name =
          '${rotation.name} '
          'frame=${frame.width.toInt()}x${frame.height.toInt()} '
          'view=${view.width.toInt()}x${view.height.toInt()}';

      test(name, () {
        final mapper = CoordinateMapper(
          imageSize: frame,
          rotation: rotation,
          viewSize: view,
        );
        final upright = rotation.upright(frame);
        final layout = mapper.layout;
        final preview = layout.previewRect;
        final viewRect = Offset.zero & view;

        // (a) The full upright frame maps to the preview rectangle.
        expect(
          mapper.mapToView(Offset.zero & upright),
          rectMoreOrLessEquals(preview, epsilon: _epsilon),
        );

        // (b) The preview covers the view and matches it on at least one axis.
        expect(preview.left, lessThanOrEqualTo(_epsilon));
        expect(preview.top, lessThanOrEqualTo(_epsilon));
        expect(preview.right, greaterThanOrEqualTo(view.width - _epsilon));
        expect(preview.bottom, greaterThanOrEqualTo(view.height - _epsilon));
        final fitsWidth =
            (preview.left).abs() < _epsilon &&
            (preview.right - view.width).abs() < _epsilon;
        final fitsHeight =
            (preview.top).abs() < _epsilon &&
            (preview.bottom - view.height).abs() < _epsilon;
        expect(fitsWidth || fitsHeight, isTrue);

        // (c) The frame's centre maps to the view's centre.
        final centre = mapper.mapToView(
          Rect.fromCenter(
            center: upright.center(Offset.zero),
            width: 0,
            height: 0,
          ),
        );
        expect(centre.center.dx, closeTo(viewRect.center.dx, _epsilon));
        expect(centre.center.dy, closeTo(viewRect.center.dy, _epsilon));

        // (d) A mapped box keeps its size multiplied by the scale.
        final box = Rect.fromLTWH(
          upright.width * 0.1,
          upright.height * 0.2,
          upright.width * 0.3,
          upright.height * 0.1,
        );
        final mapped = mapper.mapToView(box);
        expect(mapped.width, closeTo(box.width * layout.scale, _epsilon));
        expect(mapped.height, closeTo(box.height * layout.scale, _epsilon));
        expect(mapped.left, lessThanOrEqualTo(mapped.right));
        expect(mapped.top, lessThanOrEqualTo(mapped.bottom));
      });
    }
  });

  test('exposes the layout the preview must use', () {
    final mapper = CoordinateMapper(
      imageSize: _frame,
      rotation: ImageRotation.deg90,
      viewSize: const Size(360, 800),
    );
    expect(mapper.layout.previewRect, const Rect.fromLTRB(-45, 0, 405, 800));
  });
}
