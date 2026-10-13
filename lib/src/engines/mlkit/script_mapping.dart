import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show TextRecognitionScript;

import '../../models/text_script.dart';

/// Maps a [TextScript] to the ML Kit recognizer script that reads it.
///
/// Internal to the package: not exported from the entry library.
extension TextScriptMlKit on TextScript {
  /// The ML Kit script for this [TextScript].
  TextRecognitionScript get recognitionScript => switch (this) {
    TextScript.latin => TextRecognitionScript.latin,
    // ML Kit's plugin spells this value "devanagiri".
    TextScript.devanagari => TextRecognitionScript.devanagiri,
  };
}
