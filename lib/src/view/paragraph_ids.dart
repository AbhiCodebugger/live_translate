import 'dart:ui' show Rect;

/// A shown paragraph's id and where it is in the current picture.
typedef PlacedParagraph = ({String id, Rect box});

/// The share of the smaller box two paragraphs must overlap by to be taken
/// as the same paragraph.
const sameParagraphOverlap = 0.5;

/// Ids for paragraphs found at [boxes], keeping the id of a [previous]
/// paragraph in the same place.
///
/// A box takes the id of the previous paragraph it overlaps most, when the
/// overlap covers at least [sameParagraphOverlap] of the smaller box's
/// area. Each previous id goes to one box, the largest overlaps first. Every
/// other box gets an id from [newId].
List<String> matchParagraphIds(
  List<Rect> boxes,
  List<PlacedParagraph> previous,
  String Function() newId,
) {
  final pairs = <({int box, int previous, double area})>[];
  for (final (i, box) in boxes.indexed) {
    for (final (j, old) in previous.indexed) {
      final overlap = box.intersect(old.box);
      if (overlap.width <= 0 || overlap.height <= 0) continue;
      final area = overlap.width * overlap.height;
      final smaller = _area(box) < _area(old.box) ? _area(box) : _area(old.box);
      if (smaller > 0 && area >= sameParagraphOverlap * smaller) {
        pairs.add((box: i, previous: j, area: area));
      }
    }
  }
  pairs.sort((a, b) => b.area.compareTo(a.area));
  final ids = List<String?>.filled(boxes.length, null);
  final taken = <int>{};
  for (final pair in pairs) {
    if (ids[pair.box] != null || taken.contains(pair.previous)) continue;
    ids[pair.box] = previous[pair.previous].id;
    taken.add(pair.previous);
  }
  return [for (final id in ids) id ?? newId()];
}

double _area(Rect rect) => rect.width * rect.height;
