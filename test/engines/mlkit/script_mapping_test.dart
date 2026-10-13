import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show TextRecognitionScript;
import 'package:live_translate/src/engines/mlkit/script_mapping.dart';
import 'package:live_translate/src/models/text_script.dart';

void main() {
  group('TextScript.recognitionScript', () {
    test('maps latin to the Latin recognizer', () {
      expect(TextScript.latin.recognitionScript, TextRecognitionScript.latin);
    });

    test('maps devanagari to the Devanagari recognizer', () {
      expect(
        TextScript.devanagari.recognitionScript,
        TextRecognitionScript.devanagiri,
      );
    });

    test('maps every script to a distinct recognizer', () {
      final mapped = TextScript.values.map((s) => s.recognitionScript).toSet();
      expect(mapped, hasLength(TextScript.values.length));
    });
  });
}
