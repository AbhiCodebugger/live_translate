/// Live, offline camera translation for Flutter.
///
/// Text in the camera view is recognised, translated on-device and painted
/// over the original, in place.
library;

export 'package:camera/camera.dart' show ResolutionPreset;
export 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

export 'src/controller/live_translate_controller.dart'
    show LiveTranslateController;
export 'src/controller/live_translate_state.dart' show LiveTranslateState;
export 'src/errors.dart';
export 'src/models/overlay_style.dart';
export 'src/models/text_script.dart';
export 'src/models/translated_line.dart';
export 'src/translation_models.dart';
export 'src/view/live_translate_view.dart'
    show LiveTranslateView, OverlayBuilder;
