import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_translate/live_translate.dart';

/// Opens a sheet listing the frozen picture's paragraphs, each translation
/// over its original, with buttons to copy one or all of them.
///
/// The sheet follows [lines]: it shows the new translation when the frozen
/// picture is read again, and closes when [lines] becomes `null`.
Future<void> showTextSheet(
  BuildContext context,
  ValueListenable<List<TranslatedLine>?> lines,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _TextSheet(lines: lines),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.lines});

  final ValueListenable<List<TranslatedLine>?> lines;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  // Whether the "Copied" confirmation shows, and when it goes away.
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    widget.lines.addListener(_onLines);
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    widget.lines.removeListener(_onLines);
    super.dispose();
  }

  void _onLines() {
    if (widget.lines.value == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines.value ?? const <TranslatedLine>[];
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
            child: Row(
              children: [
                Text('Text', style: theme.textTheme.titleLarge),
                const SizedBox(width: 12),
                if (_copied)
                  Text(
                    'Copied',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _copy(lines.map((l) => l.translatedText).join('\n\n')),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return ListTile(
                  title: Text(line.translatedText),
                  subtitle: Text(line.sourceText),
                  trailing: IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copy(line.translatedText),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
