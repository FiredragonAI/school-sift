// 提醒的平台实现:
//   Android → flutter_local_notifications 本地定时通知(App 关着也响)
//   Web     → 只能在页面打开时用浏览器 Notification;关了页就没有(PWA 推送需要服务器,本机优先不做)
export 'reminders_native.dart' if (dart.library.js_interop) 'reminders_web.dart';
