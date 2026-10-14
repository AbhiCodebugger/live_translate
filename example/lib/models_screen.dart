import 'package:flutter/material.dart';
import 'package:live_translate/live_translate.dart';

import 'languages.dart';

/// "Languages on this phone": the translation models on the device, with
/// buttons to delete them, and every other language, with buttons to
/// download it.
class ModelsScreen extends StatefulWidget {
  /// Creates the page, managing models through [models].
  const ModelsScreen({super.key, required this.models});

  /// Where models are checked, downloaded and deleted.
  final TranslationModels models;

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  Set<TranslateLanguage> _downloaded = const {};
  final _busy = <TranslateLanguage>{};
  bool _wifiOnly = false;

  @override
  void initState() {
    super.initState();
    widget.models.downloaded().then((downloaded) {
      if (mounted) setState(() => _downloaded = downloaded);
    }, onError: (Object _) {});
  }

  Future<void> _download(TranslateLanguage language) async {
    setState(() => _busy.add(language));
    try {
      await widget.models.download(language, wifiOnly: _wifiOnly);
      if (mounted) setState(() => _downloaded = {..._downloaded, language});
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text("Couldn't download ${displayName(language)}"),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(language));
    }
  }

  Future<void> _delete(TranslateLanguage language) async {
    await widget.models.delete(language);
    if (mounted) {
      setState(() => _downloaded = {..._downloaded}..remove(language));
    }
  }

  static List<TranslateLanguage> _sorted(Iterable<TranslateLanguage> all) =>
      all.toList()..sort((a, b) => displayName(a).compareTo(displayName(b)));

  @override
  Widget build(BuildContext context) {
    final onPhone = _sorted(_downloaded);
    final available = _sorted(
      TranslateLanguage.values.where((l) => !_downloaded.contains(l)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Languages on this phone')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Wi-Fi only'),
            subtitle: const Text('Downloads wait for Wi-Fi'),
            value: _wifiOnly,
            onChanged: (on) => setState(() => _wifiOnly = on),
          ),
          const _Header('On this phone'),
          for (final language in onPhone)
            ListTile(
              key: ValueKey(('on-phone', language)),
              title: Text(displayName(language)),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(language),
              ),
            ),
          const _Header('Available'),
          for (final language in available)
            ListTile(
              key: ValueKey(('available', language)),
              title: Text(displayName(language)),
              trailing: _busy.contains(language)
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Download',
                      icon: const Icon(Icons.download),
                      onPressed: () => _download(language),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
