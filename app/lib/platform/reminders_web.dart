import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../core/reminder_plan.dart';

const bool remindersInBackground = false;

/// 网页版:页面开着的时候每分钟看一眼计划,到点就弹浏览器通知。
class ReminderService {
  List<PlannedReminder> _plan = const [];
  final Set<String> _fired = {};
  Timer? _timer;

  Future<void> init() async {
    _timer ??= Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  Future<bool> requestPermission() async {
    if (!web.window.has('Notification')) return false;
    if (web.Notification.permission == 'granted') return true;
    final r = await web.Notification.requestPermission().toDart;
    return r.toDart == 'granted';
  }

  Future<void> reschedule(List<PlannedReminder> plan) async {
    await init();
    _plan = plan;
  }

  void _tick() {
    if (!web.window.has('Notification') || web.Notification.permission != 'granted') return;
    final now = DateTime.now();
    for (final r in _plan) {
      if (_fired.contains(r.key)) continue;
      final diff = now.difference(r.at);
      if (diff.inSeconds >= 0 && diff.inMinutes < 2) {
        _fired.add(r.key);
        web.Notification(r.title, web.NotificationOptions(body: r.body, tag: r.key));
      }
    }
  }

  Future<void> showTest(String title, String body) async {
    if (await requestPermission()) {
      web.Notification(title, web.NotificationOptions(body: body));
    }
  }
}
