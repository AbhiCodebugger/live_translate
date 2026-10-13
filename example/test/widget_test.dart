import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate_example/main.dart';

void main() {
  testWidgets('builds the camera screen without a camera', (tester) async {
    // The view checks the target model at start; report every model present,
    // as ML Kit's plugin isn't available in tests.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_on_device_translator'),
      (call) async => true,
    );
    await tester.pumpWidget(const ExampleApp());

    // Tests have no camera plugin, so the view reports the camera missing.
    // The plugin's failure arrives on a real async boundary, outside the
    // test's fake time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.textContaining('CameraUnavailable'), findsOneWidget);
    expect(find.text('No camera available.'), findsOneWidget);

    expect(find.text('Live Translate'), findsOneWidget);
    expect(find.text('Detect language'), findsOneWidget);
    expect(find.byTooltip('Freeze'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
