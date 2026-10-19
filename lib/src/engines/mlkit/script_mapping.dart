import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show TextRecognitionScript;

import '../../models/text_script.dart';

/// Maps a [TextScript] to the ML Kit recognizer script that reads it.
///
/// Internal to the package: not exported from the entry library.
extension TextScriptMlKit on TextScript {
  /// The ML Kit script for this [TextScript].
  TextRecognitionScript get recognitionScript {
    if (this == TextScript.latin) return TextRecognitionScript.latin;
    // ML Kit's plugin spells this value "devanagiri".
    if (this == TextScript.devanagari) return TextRecognitionScript.devanagiri;
    throw StateError('No ML Kit recognizer for $this');
  }
}
