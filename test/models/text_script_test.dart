import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/models/text_script.dart';

void main() {
  test('offers exactly latin and devanagari', () {
    expect(TextScript.values, [TextScript.latin, TextScript.devanagari]);
  });
}
