import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_translate/live_translate.dart';

/// Opens a sheet listing the frozen picture's paragraphs, each translation
/// over its original, with buttons to copy one or all of them.
///
/// The sheet follows [paragraphs]: it shows the new translation when the frozen
/// picture is read again, and closes when [paragraphs] becomes `null`.
Future<void> showTextSheet(
  BuildContext context,
  ValueListenable<List<TranslatedParagraph>?> paragraphs,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _TextSheet(paragraphs: paragraphs),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.paragraphs});

  final ValueListenable<List<TranslatedParagraph>?> paragraphs;

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
    widget.paragraphs.addListener(_onParagraphs);
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    widget.paragraphs.removeListener(_onParagraphs);
    super.dispose();
  }

  void _onParagraphs() {
    if (widget.paragraphs.value == null) {
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
    final paragraphs = widget.paragraphs.value ?? const <TranslatedParagraph>[];
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
                  onPressed: () => _copy(
                    paragraphs.map((p) => p.translatedText).join('\n\n'),
                  ),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: paragraphs.length,
              itemBuilder: (context, index) {
                final line = paragraphs[index];
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
