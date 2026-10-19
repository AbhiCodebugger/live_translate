import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';

void main() {
  test('offers exactly latin and devanagari', () {
    expect(TextScript.values, [TextScript.latin, TextScript.devanagari]);
  });

  test('names each script', () {
    expect(TextScript.latin.name, 'latin');
    expect(TextScript.devanagari.name, 'devanagari');
    expect(TextScript.devanagari.toString(), 'TextScript.devanagari');
  });

  test('works in const sets and as map keys', () {
    const scripts = {TextScript.latin, TextScript.devanagari};
    expect(scripts, hasLength(2));
    const names = {TextScript.latin: 'Latin'};
    expect(names[TextScript.latin], 'Latin');
    expect(names[TextScript.devanagari], isNull);
  });

  test('the usual view setup compiles', () {
    const view = LiveTranslateView(scripts: {TextScript.latin});
    expect(view.scripts, {TextScript.latin});
  });
}
