import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reading_preferences.dart';
import '../services/comic_library_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ReadingPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await ReadingPreferences.load();
    setState(() => _prefs = prefs);
  }

  Future<void> _save() async {
    if (_prefs != null) await _prefs!.save();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Use System Theme'),
            subtitle: const Text('Follow device dark/light mode'),
            value: prefs.useSystemTheme,
            onChanged: (value) {
              setState(() => prefs.useSystemTheme = value);
              _save();
            },
          ),
          if (!prefs.useSystemTheme)
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: prefs.darkMode,
              onChanged: (value) {
                setState(() => prefs.darkMode = value);
                _save();
              },
            ),
          const Divider(),
          _SectionHeader(title: 'Reading Defaults'),
          ListTile(
            title: const Text('Reading Direction'),
            subtitle: Text(prefs.direction == ReadingDirection.leftToRight ? 'Left to Right' : 'Right to Left'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDirectionPicker(context, prefs),
          ),
          ListTile(
            title: const Text('Page Fit'),
            subtitle: Text(prefs.fitMode == PageFitMode.fitWidth ? 'Fit Width' : 'Fit Page'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFitModePicker(context, prefs),
          ),
          const Divider(),
          _SectionHeader(title: 'Library'),
          ListTile(
            title: const Text('Clear All Data'),
            subtitle: const Text('Delete all imported comics and progress'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _confirmClearData(context),
          ),
        ],
      ),
    );
  }

  void _showDirectionPicker(BuildContext context, ReadingPreferences prefs) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ReadingDirection.values.map((dir) {
            return RadioListTile<ReadingDirection>(
              title: Text(dir == ReadingDirection.leftToRight ? 'Left to Right' : 'Right to Left'),
              value: dir,
              groupValue: prefs.direction,
              onChanged: (value) {
                if (value != null) {
                  setState(() => prefs.direction = value);
                  _save();
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFitModePicker(BuildContext context, ReadingPreferences prefs) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PageFitMode.values.map((mode) {
            return RadioListTile<PageFitMode>(
              title: Text(mode == PageFitMode.fitWidth ? 'Fit Width' : 'Fit Page'),
              value: mode,
              groupValue: prefs.fitMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() => prefs.fitMode = value);
                  _save();
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will permanently delete all imported comics and reading progress.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final service = context.read<ComicLibraryService>();
              for (final chapter in List<dynamic>.from(service.chapters)) {
                service.deleteChapter(chapter);
              }
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

