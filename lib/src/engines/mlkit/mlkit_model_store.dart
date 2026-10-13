import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../errors.dart';
import '../model_store.dart';

/// A [ModelStore] backed by ML Kit's translation model manager.
final class MlKitModelStore implements ModelStore {
  /// Creates a store.
  ///
  /// [manager] exists so tests can substitute a fake.
  MlKitModelStore({ModelManager? manager})
    : _manager = manager ?? OnDeviceTranslatorModelManager();

  final ModelManager _manager;

  @override
  Future<bool> isDownloaded(TranslateLanguage language) =>
      _manager.isModelDownloaded(language.bcpCode);

  @override
  Future<void> download(
    TranslateLanguage language, {
    required bool wifiOnly,
  }) async {
    final bool succeeded;
    try {
      succeeded = await _manager.downloadModel(
        language.bcpCode,
        isWifiRequired: wifiOnly,
      );
    } on PlatformException {
      throw ModelNotDownloaded(language);
    }
    if (!succeeded) throw ModelNotDownloaded(language);
  }

  @override
  Future<void> delete(TranslateLanguage language) =>
      _manager.deleteModel(language.bcpCode);
}
