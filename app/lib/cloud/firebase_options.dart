// Firebase 项目配置。Web 端的这些值是公开的(打开网页就能看到),不是密钥;
// 访问控制靠 firestore.rules 和登录。
//
// 还没建正式项目时用 demo-schoolsift:Firebase 本机模拟器认 demo- 开头的项目,不需要真实账号。
// 建好正式项目后,把下面的值换成 `firebase apps:sdkconfig` 给出的(或用 flutterfire configure 重新生成)。

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class CloudOptions {
  /// 构建时 --dart-define=FIREBASE_EMULATOR=true:连本机模拟器(开发 / 端到端测试用)
  static const useEmulator = bool.fromEnvironment('FIREBASE_EMULATOR');
  static const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

  static const _demoProject = 'demo-schoolsift';

  static const web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: _demoProject,
    authDomain: '$_demoProject.firebaseapp.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: _demoProject,
  );

  static FirebaseOptions get current => kIsWeb ? web : android;

  /// 有正式项目,或者在连模拟器:家庭同步才可用;否则界面上说明「还没开通」
  static bool get configured => useEmulator || current.projectId != _demoProject;
}
