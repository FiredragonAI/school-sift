// 登录:邮箱 + 密码(Firebase Authentication)。抽成接口,测试里换成假的。
//
// 为什么不用「邮箱链接免密登录」:Android 上要靠 Dynamic Links(2025 年已停服)或额外配置 App Links,
// 邮箱 + 密码在网页和 Android 上都一样简单,验证邮件和重设密码邮件由 Firebase 免费代发。
// 被邀请的人必须验证过邮箱才能加入家庭(否则谁都能拿别人的邮箱注册、截走邀请)。

import 'package:firebase_auth/firebase_auth.dart';

class CloudUser {
  final String uid;
  final String email;
  final bool emailVerified;
  const CloudUser({required this.uid, required this.email, required this.emailVerified});
}

/// 登录失败的原因,界面按它显示中英文提示
enum AccountError { emailInUse, invalidEmail, weakPassword, wrongCredentials, tooManyRequests, network, unknown }

class AccountException implements Exception {
  final AccountError code;
  final String? detail;
  const AccountException(this.code, [this.detail]);
  @override
  String toString() => 'AccountException($code${detail == null ? '' : ': $detail'})';
}

abstract class AccountBackend {
  CloudUser? get current;
  Stream<CloudUser?> changes();
  Future<CloudUser> signUp(String email, String password);
  Future<CloudUser> signIn(String email, String password);
  Future<void> sendVerification();
  /// 重新取用户状态;验证过邮箱后还要刷新登录凭证,规则里才看得到 email_verified
  Future<CloudUser?> reload();
  Future<void> resetPassword(String email);
  Future<void> signOut();
  /// 删除账号(Google Play 要求可在应用内删除)。Firebase 要求最近登录过,所以带密码先重新验证一次
  Future<void> deleteAccount(String password);
  void setLanguage(String lang);
}

class FirebaseAccountBackend implements AccountBackend {
  FirebaseAccountBackend([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  static CloudUser? _wrap(User? u) =>
      u == null ? null : CloudUser(uid: u.uid, email: u.email ?? '', emailVerified: u.emailVerified);

  @override
  CloudUser? get current => _wrap(_auth.currentUser);

  @override
  Stream<CloudUser?> changes() => _auth.userChanges().map(_wrap);

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseAuthException catch (e) {
      throw AccountException(switch (e.code) {
        'email-already-in-use' => AccountError.emailInUse,
        'invalid-email' => AccountError.invalidEmail,
        'weak-password' => AccountError.weakPassword,
        'user-not-found' || 'wrong-password' || 'invalid-credential' || 'invalid-login-credentials' => AccountError.wrongCredentials,
        'too-many-requests' => AccountError.tooManyRequests,
        'network-request-failed' => AccountError.network,
        _ => AccountError.unknown,
      }, e.code);
    }
  }

  @override
  Future<CloudUser> signUp(String email, String password) => _guard(() async {
        final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await c.user!.sendEmailVerification();
        return _wrap(c.user)!;
      });

  @override
  Future<CloudUser> signIn(String email, String password) => _guard(() async {
        final c = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return _wrap(c.user)!;
      });

  @override
  Future<void> sendVerification() => _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<CloudUser?> reload() => _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return null;
        await u.reload();
        final fresh = _auth.currentUser;
        if (fresh != null && fresh.emailVerified) await fresh.getIdToken(true);
        return _wrap(fresh);
      });

  @override
  Future<void> resetPassword(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount(String password) => _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return;
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email ?? '', password: password));
        await u.delete();
      });

  @override
  void setLanguage(String lang) => _auth.setLanguageCode(lang == 'zh' ? 'zh-CN' : 'en');
}
