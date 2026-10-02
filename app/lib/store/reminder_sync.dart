// 把 AppState 的每次变动(防抖后)同步成系统提醒。平台差异在 platform/reminders.dart。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/reminder_plan.dart';
import '../platform/reminders.dart';
import 'app_state.dart';

class ReminderSync {
  static final service = ReminderService();
  static Timer? _debounce;
  static bool _attached = false;

  static void attach(AppState st) {
    if (_attached) return;
    _attached = true;
    st.addListener(() => _schedule(st));
    // Android:首次启动就申请通知权限(系统只会问一次);网页版等用户在设置里打开再问,免得一进来就弹框
    if (!kIsWeb && st.settings.remindersEnabled) {
      service.requestPermission().then((_) => now(st));
    } else {
      now(st);
    }
  }

  static void _schedule(AppState st) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => now(st));
  }

  static Future<void> now(AppState st) async {
    try {
      await service.reschedule(ReminderPlanner(st).plan());
    } catch (e) {
      debugPrint('reminder reschedule failed: $e');
    }
  }
}
