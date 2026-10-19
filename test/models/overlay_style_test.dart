import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/models/overlay_style.dart';

void main() {
  group('OverlayStyle', () {
    test('has the documented defaults', () {
      const style = OverlayStyle();
      expect(style.backgroundColor, const Color(0xCC000000));
      expect(style.textColor, const Color(0xFFFFFFFF));
      expect(style.borderRadius, 6);
      expect(
        style.padding,
        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      );
      expect(style.minFontSize, 10);
      expect(style.maxFontSize, 28);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('is equal when all fields are equal', () {
      const a = OverlayStyle(textColor: Color(0xFFFFFF00), maxFontSize: 20);
      const b = OverlayStyle(textColor: Color(0xFFFFFF00), maxFontSize: 20);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('is not equal when any field differs', () {
      expect(
        const OverlayStyle(fontWeight: FontWeight.bold),
        isNot(const OverlayStyle()),
      );
    });

    test('rejects a minFontSize larger than maxFontSize', () {
      expect(
        () => OverlayStyle(minFontSize: 30, maxFontSize: 20),
        throwsAssertionError,
      );
    });

    test('rejects a non-positive minFontSize', () {
      expect(() => OverlayStyle(minFontSize: 0), throwsAssertionError);
    });

    test('accepts equal min and max font sizes', () {
      expect(OverlayStyle(minFontSize: 14, maxFontSize: 14).minFontSize, 14);
    });
  });

  group('copyWith', () {
    test('replaces one field and keeps the rest', () {
      final style = const OverlayStyle().copyWith(maxFontSize: 48);
      expect(style.maxFontSize, 48);
      expect(style.minFontSize, 10);
      expect(style.borderRadius, 6);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.backgroundColor, const Color(0xCC000000));
    });

    test('with no arguments is equal to the original', () {
      const style = OverlayStyle(borderRadius: 2, maxFontSize: 40);
      expect(style.copyWith(), style);
    });

    test('checks the font size bounds', () {
      expect(
        () => const OverlayStyle().copyWith(minFontSize: 40),
        throwsAssertionError,
      );
    });
  });

  test('describes every field', () {
    final text = const OverlayStyle().toString();
    expect(text, startsWith('OverlayStyle('));
    expect(text, contains('maxFontSize: 28.0'));
    expect(text, contains('minFontSize: 10.0'));
    expect(text, contains('fontWeight: FontWeight.w600'));
  });
}
