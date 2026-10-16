import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/models/source_status.dart';

void main() {
  const spanish = TranslateLanguage.spanish;

  String stage(SourceStatus status) => switch (status) {
    SourceSearching() => 'searching',
    SourceGuessed() => 'guessed',
    SourceDownloading() => 'downloading',
    SourceReady() => 'ready',
    SourceUnsupported() => 'unsupported',
    SourceNotFound() => 'not found',
    SourceDownloadFailed() => 'download failed',
  };

  group('SourceStatus', () {
    test('stages carry their language', () {
      const status = SourceDownloading(spanish);
      expect(stage(status), 'downloading');
      expect(status.language, spanish);
      expect(const SourceUnsupported('la').tag, 'la');
    });

    test('is equal when stage and language are equal', () {
      expect(const SourceReady(spanish), const SourceReady(spanish));
      expect(
        const SourceReady(spanish).hashCode,
        const SourceReady(spanish).hashCode,
      );
      expect(const SourceSearching(), const SourceSearching());
      expect(const SourceNotFound(), const SourceNotFound());
      expect(const SourceUnsupported('la'), const SourceUnsupported('la'));
    });

    test('differs by stage or language', () {
      expect(const SourceReady(spanish), isNot(const SourceGuessed(spanish)));
      expect(
        const SourceDownloading(spanish),
        isNot(const SourceDownloadFailed(spanish)),
      );
      expect(
        const SourceReady(spanish),
        isNot(const SourceReady(TranslateLanguage.french)),
      );
      expect(const SourceSearching(), isNot(const SourceNotFound()));
    });

    test('describes itself', () {
      expect(const SourceGuessed(spanish).toString(), 'SourceGuessed(es)');
      expect(const SourceUnsupported('la').toString(), 'SourceUnsupported(la)');
    });
  });
}
