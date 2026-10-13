import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:live_translate/src/engines/mlkit/mlkit_model_store.dart';
import 'package:live_translate/src/errors.dart';

final class _FakeManager implements ModelManager {
  final calls = <String>[];
  bool downloadResult = true;
  Object? downloadError;

  @override
  String get method => 'fake';

  @override
  MethodChannel get channel => const MethodChannel('fake');

  @override
  Future<bool> isModelDownloaded(String model) async {
    calls.add('check $model');
    return model == 'hi';
  }

  @override
  Future<bool> downloadModel(String model, {bool isWifiRequired = true}) async {
    calls.add('download $model wifi=$isWifiRequired');
    if (downloadError case final error?) throw error;
    return downloadResult;
  }

  @override
  Future<bool> deleteModel(String model) async {
    calls.add('delete $model');
    return true;
  }
}

void main() {
  late _FakeManager manager;
  late MlKitModelStore store;

  setUp(() {
    manager = _FakeManager();
    store = MlKitModelStore(manager: manager);
  });

  test('checks a model by its BCP-47 code', () async {
    expect(await store.isDownloaded(TranslateLanguage.hindi), isTrue);
    expect(await store.isDownloaded(TranslateLanguage.marathi), isFalse);
    expect(manager.calls, ['check hi', 'check mr']);
  });

  test('passes the Wi-Fi requirement through', () async {
    await store.download(TranslateLanguage.hindi, wifiOnly: true);
    await store.download(TranslateLanguage.spanish, wifiOnly: false);
    expect(manager.calls, ['download hi wifi=true', 'download es wifi=false']);
  });

  test('a false result means the download failed', () async {
    manager.downloadResult = false;
    await expectLater(
      store.download(TranslateLanguage.hindi, wifiOnly: true),
      throwsA(
        isA<ModelNotDownloaded>().having(
          (e) => e.language,
          'language',
          TranslateLanguage.hindi,
        ),
      ),
    );
  });

  test('a platform error means the download failed', () async {
    manager.downloadError = PlatformException(code: 'download-failed');
    await expectLater(
      store.download(TranslateLanguage.hindi, wifiOnly: true),
      throwsA(isA<ModelNotDownloaded>()),
    );
  });

  test('deletes a model by its BCP-47 code', () async {
    await store.delete(TranslateLanguage.hindi);
    expect(manager.calls, ['delete hi']);
  });
}
