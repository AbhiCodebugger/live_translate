import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/view/paragraph_ids.dart';

void main() {
  late int next;
  String newId() => 'n${next++}';

  setUp(() => next = 0);

  const box = Rect.fromLTWH(0, 0, 100, 20);

  test('a box in the same place keeps its id', () {
    expect(matchParagraphIds([box], [(id: 'a', box: box)], newId), ['a']);
  });

  test('half of the smaller box is enough', () {
    final moved = box.shift(const Offset(50, 0));
    expect(matchParagraphIds([moved], [(id: 'a', box: box)], newId), ['a']);
    final further = box.shift(const Offset(51, 0));
    expect(matchParagraphIds([further], [(id: 'a', box: box)], newId), ['n0']);
  });

  test('a small box inside a large one matches', () {
    const small = Rect.fromLTWH(10, 5, 20, 10);
    expect(matchParagraphIds([small], [(id: 'a', box: box)], newId), ['a']);
  });

  test('the largest overlap takes a contested id', () {
    final ninety = box.shift(const Offset(10, 0));
    final fiftyFive = box.shift(const Offset(-45, 0));
    expect(
      matchParagraphIds([fiftyFive, ninety], [(id: 'a', box: box)], newId),
      ['n0', 'a'],
    );
  });

  test('each box takes the previous paragraph it overlaps most', () {
    final below = box.shift(const Offset(0, 30));
    expect(
      matchParagraphIds(
        [below, box],
        [(id: 'a', box: box), (id: 'b', box: below)],
        newId,
      ),
      ['b', 'a'],
    );
  });

  test('no previous paragraphs gives new ids', () {
    expect(matchParagraphIds([box, box], const [], newId), ['n0', 'n1']);
  });
}
