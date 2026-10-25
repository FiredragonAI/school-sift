// 家庭同步的总控:登录状态、所在家庭、邀请、同步开关。界面只跟它打交道。
//
// Firebase 是懒加载的:没开家庭同步的人,网页版启动时不会去 Google 拉 Firebase 的 JS(firebase_core_web
// 只在 initializeApp 时注入脚本),和以前一样零外部请求。打开「家庭同步」页或本机之前开过同步时才初始化。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../store/app_state.dart';
import 'account.dart';
import 'family_service.dart';
import 'family_sync.dart';
import 'firebase_options.dart';

enum CloudPhase {
  /// 还没有正式的 Firebase 项目
  notConfigured,
  /// 还没初始化(没打开过家庭同步)
  idle,
  signedOut,
  /// 注册了但还没点验证邮件里的链接
  unverified,
  /// 登录了,不在任何家庭(可能有邀请)
  noFamily,
  /// 在家庭里,但这台设备还没决定本机已有的数据怎么办
  needsChoice,
  inFamily,
}

class CloudSession extends ChangeNotifier {
  CloudSession(this.st, {AccountBackend Function()? account, FirebaseFirestore Function()? db, Future<void> Function()? init, bool? configured})
      : _accountFactory = account,
        _dbFactory = db,
        _init = init,
        _configured = configured;

  final AppState st;
  final AccountBackend Function()? _accountFactory;
  final FirebaseFirestore Function()? _dbFactory;
  final Future<void> Function()? _init;
  final bool? _configured;

  AccountBackend? _account;
  FirebaseFirestore? _db;
  FamilyService? _families;

  bool started = false;
  bool busy = false;
  CloudUser? user;
  String? familyId;
  FamilyInfo? family;
  List<FamilyInfo> invites = [];
  FamilySync? sync;
  StreamSubscription? _userSub, _familySub;
  Object? lastError;

  bool get configured => _configured ?? CloudOptions.configured;
  FamilyService get families => _families!;

  CloudPhase get phase {
    if (!configured) return CloudPhase.notConfigured;
    if (!started) return CloudPhase.idle;
    final u = user;
    if (u == null) return CloudPhase.signedOut;
    if (!u.emailVerified) return CloudPhase.unverified;
    if (familyId == null) return CloudPhase.noFamily;
    if (sync == null) return CloudPhase.needsChoice;
    return CloudPhase.inFamily;
  }

  static Future<void> _defaultInit() async {
    await Firebase.initializeApp(options: CloudOptions.current);
    final fs = FirebaseFirestore.instance;
    // 离线写入排队、重启后还在(Android 默认就开,网页要手动开);同一浏览器开了两个页签时可能开不了,不影响使用
    try {
      fs.settings = const Settings(persistenceEnabled: true);
    } catch (e) {
      debugPrint('firestore persistence: $e');
    }
    if (CloudOptions.useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(CloudOptions.emulatorHost, 9099);
      fs.useFirestoreEmulator(CloudOptions.emulatorHost, 8080);
    }
  }

  /// 初始化 Firebase、恢复登录;本机之前在某个家庭里同步过就接着同步。
  Future<void> start() async {
    if (started || !configured) return;
    await _run(() async {
      await (_init ?? _defaultInit)();
      _account = (_accountFactory ?? FirebaseAccountBackend.new)();
      _db = (_dbFactory ?? () => FirebaseFirestore.instance)();
      _families = FamilyService(_db!);
      _account!.setLanguage(st.language);
      user = _account!.current;
      started = true;
      _userSub = _account!.changes().listen(_onUser);
      if (user?.emailVerified == true) await _loadFamily();
    });
  }

  void _onUser(CloudUser? u) {
    if (u?.uid != user?.uid) {
      // 换了账号或被登出:停掉同步,本机数据留着
      unawaited(_detach());
      familyId = null;
      family = null;
      invites = [];
    }
    user = u;
    notifyListeners();
  }

  Future<T?> _run<T>(Future<T> Function() f) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      return await f();
    } catch (e) {
      lastError = e;
      debugPrint('cloud: $e');
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool get _hasLocalData => st.syncRecords().isNotEmpty;

  /// 刚验证完邮箱时,Firestore 要过一会儿才换上新的登录凭证(带 email_verified),这段时间查邀请会被规则拒绝。
  /// 只对 permission-denied 重试几次;别的错误照常抛出。
  Future<T> _retryUntilTokenFresh<T>(Future<T> Function() f) async {
    for (var i = 0;; i++) {
      try {
        return await f();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || i >= 5) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  /// 看这个账号在不在家庭里;在的话决定这台设备怎么接上
  Future<void> _loadFamily() async {
    final u = user!;
    final fid = await families.familyOf(u.uid);
    if (fid == null) {
      familyId = null;
      if (st.settings.cloudFamilyId.isNotEmpty) {
        st.settings.cloudFamilyId = '';
        st.saveSettings();
      }
      invites = await _retryUntilTokenFresh(() => families.invitesFor(u.email));
      return;
    }
    familyId = fid;
    _watchFamily(fid);
    if (st.settings.cloudFamilyId == fid || st.loadSyncBase(fid).isNotEmpty) {
      await _attach(SyncStartMode.resume);
    } else if (!_hasLocalData || st.demoLoaded) {
      await _attach(SyncStartMode.replace);
    }
    // 否则停在 needsChoice,等家长选「合并本机数据」还是「用家庭的」
  }

  void _watchFamily(String fid) {
    _familySub?.cancel();
    _familySub = families.watch(fid).listen((f) {
      family = f;
      if (f != null && user != null && !f.memberUids.contains(user!.uid)) {
        // 在别的设备上退出了家庭
        unawaited(_detach(clearDevice: true));
        familyId = null;
      }
      notifyListeners();
    }, onError: (Object e) => debugPrint('family watch: $e'));
  }

  Future<void> _attach(SyncStartMode mode) async {
    await _detach();
    final s = FamilySync(db: _db!, st: st, familyId: familyId!, uid: user!.uid);
    sync = s;
    s.status.addListener(notifyListeners);
    await s.start(mode);
    st.settings.cloudFamilyId = familyId!;
    st.saveSettings();
  }

  Future<void> _detach({bool clearDevice = false}) async {
    final s = sync;
    sync = null;
    if (s != null) {
      s.status.removeListener(notifyListeners);
      await s.stop();
      if (clearDevice) st.clearSyncBase(s.familyId);
    }
    if (clearDevice && st.settings.cloudFamilyId.isNotEmpty) {
      st.settings.cloudFamilyId = '';
      st.saveSettings();
    }
  }

  // ---------- 界面调用 ----------

  Future<bool> signUp(String email, String password) async =>
      await _run(() async {
        user = await _account!.signUp(email, password);
        return true;
      }) ??
      false;

  Future<bool> signIn(String email, String password) async =>
      await _run(() async {
        user = await _account!.signIn(email, password);
        if (user!.emailVerified) await _loadFamily();
        return true;
      }) ??
      false;

  /// 「我已验证」:重新取状态,验证过就去看有没有家庭 / 邀请
  Future<bool> refreshVerification() async =>
      await _run(() async {
        user = await _account!.reload();
        if (user?.emailVerified == true) await _loadFamily();
        return user?.emailVerified == true;
      }) ??
      false;

  Future<bool> resendVerification() async => await _run(() async {
        await _account!.sendVerification();
        return true;
      }) ??
      false;

  Future<bool> resetPassword(String email) async => await _run(() async {
        await _account!.resetPassword(email);
        return true;
      }) ??
      false;

  Future<void> refreshInvites() => _run(() async {
        if (user != null) invites = await _retryUntilTokenFresh(() => families.invitesFor(user!.email));
      });

  /// 创建家庭:本机现有数据全部上传,成为家庭的第一份数据
  Future<bool> createFamily() async =>
      await _run(() async {
        familyId = await _retryUntilTokenFresh(() => families.create(uid: user!.uid, email: user!.email));
        _watchFamily(familyId!);
        await _attach(SyncStartMode.merge);
        return true;
      }) ??
      false;

  /// 接受邀请。[keepLocal]:本机已有的数据并进家庭;否则丢弃本机的、用家庭的
  Future<bool> joinFamily(String fid, {required bool keepLocal}) async =>
      await _run(() async {
        await _retryUntilTokenFresh(() => families.join(fid, uid: user!.uid, email: user!.email));
        familyId = fid;
        invites = invites.where((i) => i.id != fid).toList();
        _watchFamily(fid);
        await _attach(keepLocal && _hasLocalData ? SyncStartMode.merge : SyncStartMode.replace);
        return true;
      }) ??
      false;

  /// 已在家庭里、换了台设备登录:本机已有数据怎么办
  Future<bool> attachThisDevice({required bool keepLocal}) async =>
      await _run(() async {
        await _attach(keepLocal ? SyncStartMode.merge : SyncStartMode.replace);
        return true;
      }) ??
      false;

  Future<bool> invite(String email) async => await _run(() async {
        await families.invite(familyId!, email);
        return true;
      }) ??
      false;

  Future<bool> cancelInvite(String email) async => await _run(() async {
        await families.cancelInvite(familyId!, email);
        return true;
      }) ??
      false;

  /// 退出家庭:本机留一份当时的数据,之后不再同步;家庭里其他人不受影响
  Future<bool> leaveFamily() async =>
      await _run(() async {
        final fid = familyId!;
        await sync?.flush();
        await _detach(clearDevice: true);
        await families.leave(fid, uid: user!.uid);
        await _familySub?.cancel();
        familyId = null;
        family = null;
        invites = await families.invitesFor(user!.email);
        return true;
      }) ??
      false;

  /// 删除账号:先删云端数据(最后一个成员才删家庭数据,否则只退出),再删登录账号。本机数据留着。
  Future<bool> deleteAccount(String password) async =>
      await _run(() async {
        final u = user!;
        // 先验证密码,免得删了云端数据却删不掉账号
        await _account!.signIn(u.email, password);
        await sync?.flush();
        final fid = familyId;
        await _detach(clearDevice: true);
        await _familySub?.cancel();
        await families.removeAccountData(fid, uid: u.uid);
        await _account!.deleteAccount(password);
        familyId = null;
        family = null;
        invites = [];
        user = null;
        return true;
      }) ??
      false;

  Future<void> signOut() => _run(() async {
        await sync?.flush();
        await _detach(clearDevice: true);
        await _familySub?.cancel();
        familyId = null;
        family = null;
        invites = [];
        await _account!.signOut();
        user = null;
      });

  @override
  void dispose() {
    _userSub?.cancel();
    _familySub?.cancel();
    sync?.stop();
    super.dispose();
  }
}
