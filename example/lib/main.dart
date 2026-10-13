import 'package:flutter/material.dart';

import 'camera_screen.dart';

void main() => runApp(const ExampleApp());

/// The example app: a full-screen camera translating into the device's
/// language, with Lens-style language and freeze controls.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'live_translate',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const CameraScreen(),
  );
}
