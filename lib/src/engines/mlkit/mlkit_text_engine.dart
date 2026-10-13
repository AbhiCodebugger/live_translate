import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../models/text_script.dart';
import '../text_engine.dart';
import 'script_mapping.dart';

/// The lowest recognition confidence at which a line is kept, where the
/// platform reports one.
const minLineConfidence = 0.5;

/// A [TextEngine] backed by ML Kit's on-device text recognizer for one
/// script.
///
/// The recognizer is created on the first [recognize] call, so an engine that
/// never sees a frame never loads a model.
final class MlKitTextEngine implements TextEngine {
  /// Creates an engine that reads [script].
  ///
  /// [createRecognizer] builds the underlying recognizer and exists so tests
  /// can substitute a fake.
  MlKitTextEngine({
    this.script = TextScript.latin,
    TextRecognizer Function(TextRecognitionScript script)? createRecognizer,
  }) : _createRecognizer =
           createRecognizer ?? ((script) => TextRecognizer(script: script));

  /// The script this engine reads.
  final TextScript script;

  final TextRecognizer Function(TextRecognitionScript script) _createRecognizer;
  TextRecognizer? _recognizer;
  bool _closed = false;

  @override
  Future<List<RecognizedLine>> recognize(InputImage image) async {
    if (_closed) throw StateError('MlKitTextEngine used after close.');
    final recognizer = _recognizer ??= _createRecognizer(
      script.recognitionScript,
    );
    final result = await recognizer.processImage(image);
    return [
      for (final (paragraph, block) in result.blocks.indexed)
        for (final line in block.lines)
          // Android reports how sure it is of each line; iOS reports
          // nothing, so iOS keeps every line.
          if ((line.confidence ?? 1) >= minLineConfidence)
            RecognizedLine(
              text: line.text,
              box: line.boundingBox,
              paragraph: paragraph,
            ),
    ];
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
