import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_plan.dart';

const bool remindersInBackground = true;

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'schoolsift_reminders',
      '学校通提醒',
      channelDescription: '截止日期、日程与每日简报',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  /// 全部取消再按计划重排。用不精确闹钟,不需要 SCHEDULE_EXACT_ALARM 权限,误差几分钟可接受。
  Future<void> reschedule(List<PlannedReminder> plan) async {
    await init();
    await _plugin.cancelAll();
    var id = 1;
    for (final r in plan) {
      // 用 UTC 瞬间排,省掉查设备时区名:zonedSchedule 只关心绝对时刻
      final when = tz.TZDateTime.from(r.at.toUtc(), tz.UTC);
      try {
        await _plugin.zonedSchedule(
          id++,
          r.title,
          r.body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.key,
        );
      } catch (_) {
        // 个别排程失败(比如系统限制数量)不影响其余
      }
    }
  }

  Future<void> showTest(String title, String body) async {
    await init();
    await _plugin.show(0, title, body, _details);
  }
}
