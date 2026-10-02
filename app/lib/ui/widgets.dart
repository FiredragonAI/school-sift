// 复用的小部件:Logo、孩子筛选条、孩子头像点、空状态、图片工具、通用编辑对话框。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../platform/export.dart';
import '../store/app_state.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E6BE6), Color(0xFF5BB0FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}

/// 顶部孩子筛选:全部 / 每个孩子一个彩色 chip。
class ChildFilterBar extends StatelessWidget {
  const ChildFilterBar({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = S.of(context);
    if (st.children.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        ChoiceChip(
          label: Text(s.allChildren),
          selected: st.filterChildId.isEmpty,
          onSelected: (_) => st.setFilter(''),
        ),
        for (final c in st.children) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: c.c, radius: 6),
            label: Text(c.name),
            selected: st.filterChildId == c.id,
            selectedColor: c.c.withValues(alpha: 0.2),
            onSelected: (_) => st.setFilter(c.id),
          ),
        ],
      ]),
    );
  }
}

class ChildDot extends StatelessWidget {
  final String childId;
  final double size;
  const ChildDot(this.childId, {super.key, this.size = 10});
  @override
  Widget build(BuildContext context) {
    final c = context.read<AppState>().child(childId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c?.c ?? Colors.grey, shape: BoxShape.circle),
    );
  }
}

class ChildTag extends StatelessWidget {
  final String childId;
  const ChildTag(this.childId, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final c = st.child(childId);
    final name = c?.name ?? S.read(context).family;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (c?.c ?? Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(name, style: TextStyle(fontSize: 12, color: c?.c ?? Colors.grey.shade700, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

IconData kindIcon(TaskKind k) {
  switch (k) {
    case TaskKind.sign:
      return Icons.draw_outlined;
    case TaskKind.pay:
      return Icons.payments_outlined;
    case TaskKind.bring:
      return Icons.backpack_outlined;
    case TaskKind.other:
      return Icons.check_circle_outline;
  }
}

Color kindColor(TaskKind k) {
  switch (k) {
    case TaskKind.sign:
      return const Color(0xFFE6563F);
    case TaskKind.pay:
      return const Color(0xFF2DA36A);
    case TaskKind.bring:
      return const Color(0xFFE09A1B);
    case TaskKind.other:
      return const Color(0xFF6B7A99);
  }
}

// ---------- 图片 ----------

/// 选图并缩到最长边 1280、JPEG 质量 72,返回 base64。手机拍的 4000px 原图会有 3–5 MB,
/// 缩完一般 150–300 KB,存进 JSON 没压力。
Future<String?> pickImageB64(BuildContext context, {bool camera = false}) async {
  final picker = ImagePicker();
  final x = await picker.pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return compressToB64(bytes);
}

String compressToB64(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return base64Encode(bytes);
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest > 1280 ? img.copyResize(decoded, width: decoded.width > decoded.height ? 1280 : null, height: decoded.height >= decoded.width ? 1280 : null) : decoded;
  return base64Encode(img.encodeJpg(resized, quality: 72));
}

/// 选图,返回压缩后的 JPEG 字节(给 OCR / AI 用)。
Future<Uint8List?> pickImageBytes(BuildContext context, {bool camera = false}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (x == null) return null;
  return compressBytes(await x.readAsBytes());
}

Uint8List compressBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest > 1280 ? img.copyResize(decoded, width: decoded.width > decoded.height ? 1280 : null, height: decoded.height >= decoded.width ? 1280 : null) : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 72));
}

/// 图片库里的图(按 id)。找不到时给个占位,别崩。
Widget storedImage(BuildContext context, String id, {double? height, BoxFit fit = BoxFit.cover}) {
  final b64 = context.read<AppState>().image(id);
  if (b64 == null) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.broken_image_outlined),
    );
  }
  return b64Image(b64, height: height, fit: fit);
}

void showStoredImage(BuildContext context, String id) {
  final b64 = context.read<AppState>().image(id);
  if (b64 != null) showFullImage(context, b64);
}

/// 发给家人:原生走分享面板;网页不支持 Web Share 时复制到剪贴板。
Future<void> shareOrCopy(BuildContext context, String text, {String? subject}) async {
  final s = S.read(context);
  final ok = await shareText(text, subject: subject);
  if (!ok) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copiedShare)));
  }
}

Widget b64Image(String b64, {double? height, BoxFit fit = BoxFit.cover}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(base64Decode(b64), height: height, fit: fit, gaplessPlayback: true),
  );
}

void showFullImage(BuildContext context, String b64) {
  showDialog(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(child: Image.memory(base64Decode(b64))),
    ),
  );
}

// ---------- 通用选择 ----------

class ChildPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowFamily;
  const ChildPicker({super.key, required this.value, required this.onChanged, this.allowFamily = true});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = S.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: s.child),
      items: [
        if (allowFamily) DropdownMenuItem(value: '', child: Text(s.family)),
        for (final c in st.children)
          DropdownMenuItem(
            value: c.id,
            child: Row(mainAxisSize: MainAxisSize.min, children: [ChildDot(c.id), const SizedBox(width: 8), Text(c.name)]),
          ),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

class MemberPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const MemberPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = S.of(context);
    return DropdownButtonFormField<String>(
      initialValue: st.member(value) == null ? '' : value,
      decoration: InputDecoration(labelText: s.assignTo),
      items: [
        DropdownMenuItem(value: '', child: Text(s.unassigned)),
        for (final m in st.members) DropdownMenuItem(value: m.id, child: Text(m.name)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

/// 日期按钮:显示 + 点开选择器。
class DayField extends StatelessWidget {
  final String label;
  final Day? value;
  final ValueChanged<Day?> onChanged;
  final bool clearable;
  const DayField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: clearable && value != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(null)) : null),
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value?.date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );
          if (d != null) onChanged(Day.of(d));
        },
        child: Text(value == null ? s.noDue : s.ymd(value!)),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  const TimeField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: value != null ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(null)) : null),
      child: InkWell(
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 8, minute: 0));
          if (t != null) onChanged(t);
        },
        child: Text(value == null ? '—' : s.tod(value)),
      ),
    );
  }
}

/// 底部弹出的编辑面板,内容可滚动,键盘弹起不遮挡。
Future<T?> showEditorSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (c2, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(title, style: Theme.of(c2).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            builder(c2),
          ],
        ),
      ),
    ),
  );
}

// ---------- 孩子 / 成员编辑 ----------

const childColors = [0xFF3F8CFF, 0xFFFF8A3D, 0xFF2DA36A, 0xFFB45CFF, 0xFFE6563F, 0xFF12A5B8, 0xFFE0A91B];

Future<void> showChildEditor(BuildContext context, {Child? child}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  final name = TextEditingController(text: child?.name ?? '');
  final school = TextEditingController(text: child?.school ?? '');
  final grade = TextEditingController(text: child?.grade ?? '');
  var color = child?.color ?? childColors[st.children.length % childColors.length];
  await showEditorSheet(
    context,
    title: child == null ? '${s.add} ${s.child}' : '${s.edit} ${s.child}',
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: name, decoration: InputDecoration(labelText: '${s.name} (${s.required})'), autofocus: child == null),
        const SizedBox(height: 12),
        TextField(controller: school, decoration: InputDecoration(labelText: s.school)),
        const SizedBox(height: 12),
        TextField(controller: grade, decoration: InputDecoration(labelText: s.gradeClass)),
        const SizedBox(height: 16),
        Text(s.color),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          for (final col in childColors)
            GestureDetector(
              onTap: () => setS(() => color = col),
              child: CircleAvatar(
                backgroundColor: Color(col),
                radius: 16,
                child: color == col ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            ),
        ]),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            st.upsertChild(Child(
              id: child?.id ?? newId(),
              name: name.text.trim(),
              school: school.text.trim(),
              grade: grade.text.trim(),
              color: color,
            ));
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
      ]),
    ),
  );
}

Future<void> showMemberEditor(BuildContext context, {Member? member}) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  final name = TextEditingController(text: member?.name ?? '');
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(member == null ? '${s.add} ${s.members}' : s.edit),
      content: TextField(controller: name, decoration: InputDecoration(labelText: s.name, hintText: s.memberHint), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            st.upsertMember(Member(id: member?.id ?? newId(), name: name.text.trim()));
            Navigator.pop(c);
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String text) async {
  final s = S.read(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.confirm)),
      ],
    ),
  );
  return r == true;
}
