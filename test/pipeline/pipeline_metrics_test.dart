import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/pipeline/pipeline_metrics.dart';

PipelineMetrics _metrics({
  int recognition = 120,
  int paragraphs = 1,
  bool frozen = false,
}) => PipelineMetrics(
  recognition: Duration(milliseconds: recognition),
  translation: const Duration(milliseconds: 80),
  sampling: const Duration(milliseconds: 10),
  total: const Duration(milliseconds: 214),
  paragraphs: paragraphs,
  frozen: frozen,
);

void main() {
  test('equal fields make equal values', () {
    expect(_metrics(), _metrics());
    expect(_metrics().hashCode, _metrics().hashCode);
  });

  test('any differing field breaks equality', () {
    expect(_metrics(), isNot(_metrics(recognition: 121)));
    expect(_metrics(), isNot(_metrics(paragraphs: 2)));
    expect(_metrics(), isNot(_metrics(frozen: true)));
  });

  test('prints durations in whole milliseconds', () {
    final text = '${_metrics()}';
    expect(text, contains('recognition: 120 ms'));
    expect(text, contains('total: 214 ms'));
    expect(text, contains('frozen: false'));
  });
}
