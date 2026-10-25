// Firebase 项目配置。Web 端的这些值是公开的(打开网页就能看到),不是密钥;
// 访问控制靠 firestore.rules 和登录。
//
// 正式项目 schoolsift-family(2026-10-25 建,Firestore 在 us-west2),值来自 `firebase apps:sdkconfig`。
// 连本机模拟器(--dart-define=FIREBASE_EMULATOR=true)时改用 demo-schoolsift:模拟器认 demo- 开头的项目,
// 不会碰到正式数据。

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class CloudOptions {
  /// 构建时 --dart-define=FIREBASE_EMULATOR=true:连本机模拟器(开发 / 端到端测试用)
  static const useEmulator = bool.fromEnvironment('FIREBASE_EMULATOR');
  static const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

  static const _demoProject = 'demo-schoolsift';

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyAMQQA-FHKy7Z23-twftogE7evRaeTvWYc',
    appId: '1:738217985306:web:59f4503043b14301c558a3',
    messagingSenderId: '738217985306',
    projectId: 'schoolsift-family',
    authDomain: 'schoolsift-family.firebaseapp.com',
    storageBucket: 'schoolsift-family.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyA7kNC96CN_AWgPmG6gT2EWLNM0634YS24',
    appId: '1:738217985306:android:fdb705109e3cbab7c558a3',
    messagingSenderId: '738217985306',
    projectId: 'schoolsift-family',
    storageBucket: 'schoolsift-family.firebasestorage.app',
  );

  /// 模拟器用:demo- 项目,假 key
  static const emulator = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: _demoProject,
    authDomain: '$_demoProject.firebaseapp.com',
  );

  static FirebaseOptions get current => useEmulator ? emulator : (kIsWeb ? web : android);

  /// 有正式项目,或者在连模拟器:家庭同步才可用;否则界面上说明「还没开通」
  static bool get configured => useEmulator || current.projectId != _demoProject;
}
