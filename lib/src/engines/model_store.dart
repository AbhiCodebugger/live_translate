import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

/// The translation models on the device.
abstract interface class ModelStore {
  /// Whether [language]'s model is on the device.
  Future<bool> isDownloaded(TranslateLanguage language);

  /// Downloads [language]'s model, waiting for Wi-Fi when [wifiOnly] is
  /// true. Completes once the model is on the device.
  ///
  /// Throws `ModelNotDownloaded` if the download fails.
  Future<void> download(TranslateLanguage language, {required bool wifiOnly});

  /// Removes [language]'s model from the device.
  Future<void> delete(TranslateLanguage language);
}
