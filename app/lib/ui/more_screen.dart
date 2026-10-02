// 更多:孩子、家庭成员、语言、备份、演示数据、关于。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../platform/export.dart';
import '../store/app_state.dart';
import '../store/settings.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(s.tabMore)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(s.settings),
            subtitle: Text('${s.aiSection} · ${s.ocrSection} · ${s.remindersSection}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ),
        SectionTitle(s.children, trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => showChildEditor(context))),
        Card(
          child: Column(children: [
            if (st.children.isEmpty) ListTile(title: Text(s.none)),
            for (final c in st.children)
              ListTile(
                leading: CircleAvatar(backgroundColor: c.c, child: Text(c.name.characters.first, style: const TextStyle(color: Colors.white))),
                title: Text(c.name),
                subtitle: Text([c.school, c.grade].where((e) => e.isNotEmpty).join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, '${s.delete} ${c.name}?')) st.removeChild(c.id);
                  },
                ),
                onTap: () => showChildEditor(context, child: c),
              ),
          ]),
        ),
        SectionTitle(s.members, trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => showMemberEditor(context))),
        Card(
          child: Column(children: [
            if (st.members.isEmpty) ListTile(title: Text(s.none), subtitle: Text(s.memberHint)),
            for (final m in st.members)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(m.name),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => st.removeMember(m.id)),
                onTap: () => showMemberEditor(context, member: m),
              ),
          ]),
        ),
        SectionTitle(s.language),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'zh', label: Text('中文')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {st.language},
              onSelectionChanged: (v) => st.setLanguage(v.first),
            ),
          ),
        ),
        SectionTitle(s.backup),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(s.exportJson),
              onTap: () => exportText('schoolsift-backup.json', 'application/json', st.exportJson()),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(s.t('复制 JSON 到剪贴板', 'Copy JSON to clipboard')),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: st.exportJson()));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: Text(s.importJson),
              onTap: () => _importDialog(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(s.csvExport),
              subtitle: Wrap(spacing: 6, children: [
                for (final k in [('grades', s.csvGrades), ('logs', s.csvLogs), ('events', s.csvEvents), ('tasks', s.csvTasks)])
                  ActionChip(
                    label: Text(k.$2),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => exportText('schoolsift-${k.$1}.csv', 'text/csv', st.exportCsv(k.$1)),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.science_outlined), title: Text(s.loadDemo), onTap: () => st.loadDemo()),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(s.clearAll, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                if (await confirmDialog(context, s.clearConfirm)) st.clearAll();
              },
            ),
          ]),
        ),
        SectionTitle(s.about),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const AppLogo(size: 36), const SizedBox(width: 10), Text('${s.appName} · SchoolSift ${Settings.appVersion}', style: Theme.of(context).textTheme.titleMedium)]),
              const SizedBox(height: 8),
              Text(s.privacy),
              const SizedBox(height: 4),
              Text(s.t('开源项目:github.com/FiredragonAI/school-sift', 'Open source: github.com/FiredragonAI/school-sift'), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _importDialog(BuildContext context) async {
    final s = S.read(context);
    final st = context.read<AppState>();
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.importJson),
        content: TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(hintText: '{ "version": 1, ... }')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              try {
                st.importJson(ctrl.text);
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.imported)));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.importFailed)));
              }
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }
}
