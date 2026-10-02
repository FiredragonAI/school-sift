// 设置:AI key(只在本机)、OCR 语言、提醒。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/claude_extractor.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../platform/reminders.dart';
import '../store/app_state.dart';
import '../store/reminder_sync.dart';
import '../store/settings.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController key = TextEditingController(text: context.read<AppState>().settings.apiKey);
  bool showKey = false;
  bool testing = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    final set = st.settings;
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        SectionTitle(s.aiSection),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: key,
                obscureText: !showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: s.apiKey,
                  hintText: 'sk-ant-…',
                  suffixIcon: IconButton(icon: Icon(showKey ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => showKey = !showKey)),
                ),
                onChanged: (v) {
                  set.apiKey = v.trim();
                  st.saveSettings();
                },
              ),
              const SizedBox(height: 8),
              Text(s.apiKeyNote, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: Settings.models.any((m) => m.$1 == set.model) ? set.model : Settings.defaultModel,
                decoration: InputDecoration(labelText: s.model),
                items: [for (final m in Settings.models) DropdownMenuItem(value: m.$1, child: Text(m.$2, overflow: TextOverflow.ellipsis))],
                onChanged: (v) {
                  set.model = v ?? Settings.defaultModel;
                  st.saveSettings();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: set.aiEnabled && !testing ? _test : null,
                icon: testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_check),
                label: Text(s.testKey),
              ),
              const SizedBox(height: 4),
              Text(s.t('获取 key:console.anthropic.com → API Keys。每条通知约 \$0.01–0.03。', 'Get a key at console.anthropic.com → API Keys. About \$0.01–0.03 per notice.'), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        SectionTitle(s.ocrSection),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.ocrLang),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'auto', label: Text(s.ocrAuto)),
                  ButtonSegment(value: 'eng', label: Text(s.ocrEng)),
                  ButtonSegment(value: 'chi', label: Text(s.ocrChi)),
                ],
                selected: {set.ocrLang},
                onSelectionChanged: (v) {
                  set.ocrLang = v.first;
                  st.saveSettings();
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: 8),
              Text(kIsWeb ? s.ocrNoteWeb : s.ocrNoteAndroid, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        SectionTitle(s.remindersSection),
        Card(
          child: Column(children: [
            SwitchListTile(
              value: set.remindersEnabled,
              title: Text(s.remindersOn),
              subtitle: Text(s.remindersDesc),
              onChanged: (v) async {
                set.remindersEnabled = v;
                st.saveSettings();
                if (v) {
                  final ok = await ReminderSync.service.requestPermission();
                  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.permissionDenied)));
                }
                ReminderSync.now(st);
              },
            ),
            SwitchListTile(
              value: set.briefEnabled,
              title: Text(s.briefOn),
              onChanged: (v) {
                set.briefEnabled = v;
                st.saveSettings();
                ReminderSync.now(st);
              },
            ),
            ListTile(
              title: Text(s.briefTime),
              trailing: Text(s.tod(TimeOfDay(hour: set.briefHour, minute: set.briefMinute)), style: Theme.of(context).textTheme.titleMedium),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: set.briefHour, minute: set.briefMinute));
                if (t == null) return;
                set.briefHour = t.hour;
                set.briefMinute = t.minute;
                st.saveSettings();
                ReminderSync.now(st);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(s.testNotify),
              onTap: () async {
                final ok = await ReminderSync.service.requestPermission();
                if (!ok) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.permissionDenied)));
                  return;
                }
                await ReminderSync.service.showTest(s.appName, s.t('提醒正常工作 ✓', 'Reminders are working ✓'));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.testSent)));
              },
            ),
            if (!remindersInBackground)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(s.remindersWebNote, style: Theme.of(context).textTheme.bodySmall),
              ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _test() async {
    final s = S.read(context);
    final st = context.read<AppState>();
    setState(() => testing = true);
    try {
      final r = await ClaudeExtractor(apiKey: st.settings.apiKey, model: st.settings.model).extract(
        text: 'Reminder: picture day is tomorrow at 9:00 am. Wear your uniform.',
        today: Day.today(),
        uiLang: st.language,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.testOk} · ${r.items.length} items')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.aiFailed}: $e')));
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }
}
