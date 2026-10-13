import 'package:flutter/material.dart';
import 'package:live_translate/live_translate.dart';

import 'languages.dart';

/// What the picker returns when the user chooses: [choice] is `null` for
/// "Detect language". Going back returns `null` instead of a choice.
typedef LanguageChoice = ({TranslateLanguage? choice});

/// Opens a [LanguagePicker] and returns the user's choice, or `null` if they
/// went back without choosing.
Future<LanguageChoice?> pickLanguage(
  BuildContext context, {
  required String title,
  required List<TranslateLanguage?> options,
  required TranslateLanguage? selected,
  required TranslationModels models,
}) => Navigator.of(context).push(
  MaterialPageRoute<LanguageChoice>(
    builder: (_) => LanguagePicker(
      title: title,
      options: options,
      selected: selected,
      models: models,
    ),
  ),
);

/// A full-screen, searchable list of languages, marking the ones whose
/// model is on the device.
class LanguagePicker extends StatefulWidget {
  /// Creates a picker over [options], where `null` is "Detect language".
  const LanguagePicker({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.models,
  });

  /// The page title, such as "Translate to".
  final String title;

  /// The choices; `null` stands for "Detect language" and is listed first.
  final List<TranslateLanguage?> options;

  /// The current choice, listed first among the languages and marked.
  final TranslateLanguage? selected;

  /// Where to look up which models are on the device.
  final TranslationModels models;

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  Set<TranslateLanguage> _downloaded = const {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.models.downloaded().then((downloaded) {
      if (mounted) setState(() => _downloaded = downloaded);
    }, onError: (Object _) {});
  }

  /// "Detect language" first, then the current choice, then the rest by
  /// name, keeping only those matching the search.
  List<TranslateLanguage?> get _rows {
    final languages = widget.options.whereType<TranslateLanguage>().toList()
      ..sort((a, b) {
        if (a == widget.selected) return -1;
        if (b == widget.selected) return 1;
        return displayName(a).compareTo(displayName(b));
      });
    final query = _query.trim().toLowerCase();
    return [if (widget.options.contains(null)) null, ...languages]
        .where((option) => sourceName(option).toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              autofocus: false,
              onChanged: (query) => setState(() => _query = query),
              decoration: const InputDecoration(
                hintText: 'Search languages',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final option = rows[index];
          final selected = option == widget.selected;
          return ListTile(
            leading: option == null
                ? const Icon(Icons.auto_awesome)
                : const SizedBox(width: 24),
            title: Text(sourceName(option)),
            selected: selected,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option != null && _downloaded.contains(option))
                  const Icon(Icons.download_done, semanticLabel: 'Downloaded'),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, semanticLabel: 'Selected'),
                ],
              ],
            ),
            onTap: () => Navigator.of(context).pop((choice: option)),
          );
        },
      ),
    );
  }
}
