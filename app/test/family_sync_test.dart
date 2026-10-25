// 家庭同步的集成测试:两台「手机」(两个 AppState)共用一个假的 Firestore,验证邀请、加入、
// 双向同步、删除、照片、离线后重新接上不会把别人删掉的东西又传回去。
// 真实 Firestore 的权限规则另在 firebase/ 下用模拟器测。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_sift/cloud/account.dart';
import 'package:school_sift/cloud/cloud_session.dart';
import 'package:school_sift/cloud/family_service.dart';
import 'package:school_sift/cloud/family_sync.dart';
import 'package:school_sift/models/models.dart';
import 'package:school_sift/store/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假的登录服务:注册即登录,verify() 模拟点了验证邮件里的链接
class FakeAccounts {
  final users = <String, ({String uid, String password, bool verified})>{};
  int _n = 0;
}

class FakeAccount implements AccountBackend {
  FakeAccount(this.all);
  final FakeAccounts all;
  CloudUser? _cur;

  void verify() {
    final u = all.users[_cur!.email]!;
    all.users[_cur!.email] = (uid: u.uid, password: u.password, verified: true);
  }

  @override
  CloudUser? get current => _cur;
  @override
  Stream<CloudUser?> changes() => const Stream.empty();
  @override
  Future<CloudUser> signUp(String email, String password) async {
    final e = normEmail(email);
    if (all.users.containsKey(e)) throw const AccountException(AccountError.emailInUse);
    all.users[e] = (uid: 'uid${++all._n}', password: password, verified: false);
    return _cur = CloudUser(uid: all.users[e]!.uid, email: e, emailVerified: false);
  }

  @override
  Future<CloudUser> signIn(String email, String password) async {
    final u = all.users[normEmail(email)];
    if (u == null || u.password != password) throw const AccountException(AccountError.wrongCredentials);
    return _cur = CloudUser(uid: u.uid, email: normEmail(email), emailVerified: u.verified);
  }

  @override
  Future<CloudUser?> reload() async {
    if (_cur == null) return null;
    final u = all.users[_cur!.email]!;
    return _cur = CloudUser(uid: u.uid, email: _cur!.email, emailVerified: u.verified);
  }

  @override
  Future<void> sendVerification() async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async => _cur = null;
  @override
  Future<void> deleteAccount(String password) async {
    final u = all.users[_cur!.email]!;
    if (u.password != password) throw const AccountException(AccountError.wrongCredentials);
    all.users.remove(_cur!.email);
    _cur = null;
  }
  @override
  void setLanguage(String lang) {}
}

Future<void> settle(List<CloudSession> ss) async {
  for (var i = 0; i < 6; i++) {
    await pumpEventQueue();
    for (final s in ss) {
      await s.sync?.flush();
    }
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeFirebaseFirestore db;
  late FakeAccounts accounts;

  Future<(CloudSession, AppState, FakeAccount)> phone({bool demo = false}) async {
    final st = AppState();
    await st.load(inMemory: true);
    if (demo) st.loadDemo();
    final acc = FakeAccount(accounts);
    final s = CloudSession(st, account: () => acc, db: () => db, init: () async {}, configured: true);
    await s.start();
    return (s, st, acc);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    accounts = FakeAccounts();
  });

  test('没开通正式项目时只显示「还没开通」,不初始化', () async {
    final st = AppState();
    await st.load(inMemory: true);
    final s = CloudSession(st, configured: false);
    await s.start();
    expect(s.phase, CloudPhase.notConfigured);
    expect(s.started, isFalse);
  });

  test('妈妈建家庭、邀请爸爸;爸爸验证邮箱后加入,看到同一份数据;双向修改、删除都同步', () async {
    final (mom, momSt, momAcc) = await phone(demo: true);
    final (dad, dadSt, dadAcc) = await phone();

    // 妈妈注册 → 未验证 → 验证 → 没家庭 → 建家庭(本机演示数据全部上传)
    expect(mom.phase, CloudPhase.signedOut);
    expect(await mom.signUp('Mom@Example.com', 'pw123456'), isTrue);
    expect(mom.phase, CloudPhase.unverified);
    momAcc.verify();
    expect(await mom.refreshVerification(), isTrue);
    expect(mom.phase, CloudPhase.noFamily);
    expect(await mom.createFamily(), isTrue);
    await settle([mom]);
    expect(mom.phase, CloudPhase.inFamily);
    final items = await db.collection('families').doc(mom.familyId).collection('items').get();
    expect(items.docs.length, momSt.syncRecords().length);
    expect(momSt.settings.cloudFamilyId, mom.familyId);

    // 邀请(大小写不敏感)
    expect(await mom.invite('DAD@example.com'), isTrue);
    await settle([mom]);
    expect(mom.family!.inviteEmails, ['dad@example.com']);

    // 爸爸:未验证时看不到邀请;验证后看到并加入(本机没有数据 → 直接用家庭的)
    await dad.signUp('dad@example.com', 'pw654321');
    expect(dad.phase, CloudPhase.unverified);
    dadAcc.verify();
    await dad.refreshVerification();
    expect(dad.phase, CloudPhase.noFamily);
    expect(dad.invites.single.id, mom.familyId);
    expect(dad.invites.single.ownerLabel, 'mom@example.com');
    expect(await dad.joinFamily(mom.familyId!, keepLocal: false), isTrue);
    await settle([mom, dad]);
    expect(dad.phase, CloudPhase.inFamily);
    expect(dadSt.children.map((c) => c.name), momSt.children.map((c) => c.name));
    expect(dadSt.notices.length, momSt.notices.length);
    expect(dadSt.tasks.length, momSt.tasks.length);
    expect(mom.family!.memberUids.length, 2);
    expect(mom.family!.inviteEmails, isEmpty);

    // 爸爸加一条待办 → 妈妈看到
    dadSt.upsertTask(Task(id: 'from_dad', childId: dadSt.children.first.id, kind: TaskKind.sign, title: '签字:爸爸加的', createdAt: DateTime.now()));
    await settle([mom, dad]);
    expect(momSt.tasks.any((t) => t.id == 'from_dad'), isTrue);

    // 妈妈改爸爸加的那条(权限相同)→ 爸爸看到
    final t = momSt.tasks.firstWhere((t) => t.id == 'from_dad');
    momSt.upsertTask(t.copyWith(status: TaskStatus.submitted));
    await settle([mom, dad]);
    expect(dadSt.tasks.firstWhere((t) => t.id == 'from_dad').status, TaskStatus.submitted);

    // 爸爸删一个孩子(连带他的通知、待办)→ 妈妈那边也没了
    final removed = dadSt.children.last.id;
    dadSt.removeChild(removed);
    await settle([mom, dad]);
    expect(momSt.children.any((c) => c.id == removed), isFalse);
    expect(momSt.tasks.any((t) => t.childId == removed), isFalse);
    expect(momSt.syncRecords().keys.toSet(), dadSt.syncRecords().keys.toSet());

    // 家庭成员(谁去办)也同步
    dadSt.upsertMember(const Member(id: 'm_grandma', name: '奶奶'));
    await settle([mom, dad]);
    expect(momSt.members.map((m) => m.name), contains('奶奶'));
  });

  test('照片:一方拍的另一方也有;删除也同步', () async {
    final (mom, momSt, momAcc) = await phone();
    final (dad, dadSt, dadAcc) = await phone();
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await mom.invite('d@x.com');
    await dad.signUp('d@x.com', 'pw123456');
    dadAcc.verify();
    await dad.refreshVerification();
    await dad.joinFamily(mom.familyId!, keepLocal: false);
    await settle([mom, dad]);

    momSt.upsertChild(const Child(id: 'c1', name: '小雨'));
    final img = momSt.putImage('aGVsbG8=');
    momSt.addNotice(Notice(id: 'n1', childId: 'c1', title: '回执', body: '请签字', source: 'photo', receivedAt: DateTime.now(), imageIds: [img]));
    await settle([mom, dad]);
    expect(dadSt.notices.single.imageIds, [img]);
    expect(dadSt.image(img), 'aGVsbG8=');

    dadSt.removeNotice('n1');
    await settle([mom, dad]);
    expect(momSt.notices, isEmpty);
    expect(momSt.image(img), isNull);
  });

  test('加入时保留本机数据:两边的都并到一起', () async {
    final (mom, momSt, momAcc) = await phone();
    final (dad, dadSt, dadAcc) = await phone();
    momSt.upsertChild(const Child(id: 'c_mom', name: '妈妈加的孩子'));
    dadSt.upsertChild(const Child(id: 'c_dad', name: '爸爸加的孩子'));
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await mom.invite('d@x.com');
    await dad.signUp('d@x.com', 'pw123456');
    dadAcc.verify();
    await dad.refreshVerification();
    await dad.joinFamily(mom.familyId!, keepLocal: true);
    await settle([mom, dad]);
    expect(momSt.children.map((c) => c.id), ['c_mom', 'c_dad']);
    expect(dadSt.children.map((c) => c.id), ['c_mom', 'c_dad'], reason: '先进家庭的排前面');
  });

  test('离线期间:别人删掉的不会被传回去,自己的修改能补传', () async {
    final (mom, momSt, momAcc) = await phone();
    final (dad, dadSt, dadAcc) = await phone();
    momSt.upsertChild(const Child(id: 'c1', name: '小雨'));
    momSt.upsertTask(Task(id: 'old', childId: 'c1', kind: TaskKind.sign, title: '旧的', createdAt: DateTime.now()));
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await mom.invite('d@x.com');
    await dad.signUp('d@x.com', 'pw123456');
    dadAcc.verify();
    await dad.refreshVerification();
    await dad.joinFamily(mom.familyId!, keepLocal: false);
    await settle([mom, dad]);

    // 妈妈「断网」:停掉同步(base 留在本机),期间本机改了东西
    final fid = mom.familyId!;
    await mom.sync!.stop();
    mom.sync = null;
    momSt.sync = null;
    momSt.upsertTask(Task(id: 'offline_new', childId: 'c1', kind: TaskKind.pay, title: '离线时加的', createdAt: DateTime.now()));
    // 这期间爸爸把旧待办删了
    dadSt.removeTask('old');
    await settle([dad]);

    // 妈妈重新接上(和重启 App 一样走 resume)
    final s = FamilySync(db: db, st: momSt, familyId: fid, uid: momAcc.current!.uid);
    await s.start(SyncStartMode.resume);
    await settle([dad]);
    await s.flush();
    await settle([dad]);
    expect(momSt.tasks.any((t) => t.id == 'old'), isFalse, reason: '爸爸删掉的不复活');
    expect(dadSt.tasks.any((t) => t.id == 'offline_new'), isTrue, reason: '妈妈离线加的补传');
    await s.stop();
  });

  test('退出家庭:本机留一份,不再同步;另一方不受影响', () async {
    final (mom, momSt, momAcc) = await phone(demo: true);
    final (dad, dadSt, dadAcc) = await phone();
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await mom.invite('d@x.com');
    await dad.signUp('d@x.com', 'pw123456');
    dadAcc.verify();
    await dad.refreshVerification();
    await dad.joinFamily(mom.familyId!, keepLocal: false);
    await settle([mom, dad]);

    expect(await dad.leaveFamily(), isTrue);
    await settle([mom, dad]);
    expect(dad.phase, CloudPhase.noFamily);
    expect(dadSt.settings.cloudFamilyId, isEmpty);
    expect(dadSt.children, isNotEmpty, reason: '本机留一份');
    dadSt.upsertChild(const Child(id: 'after_leave', name: '退出后加的'));
    await settle([mom, dad]);
    expect(momSt.children.any((c) => c.id == 'after_leave'), isFalse);
    expect(mom.family!.memberUids.length, 1);
  });

  test('换台设备登录、本机已有数据:先让家长选,不自动覆盖', () async {
    final (mom, momSt, momAcc) = await phone(demo: true);
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await settle([mom]);

    // 妈妈的第二台设备:本机有自己加的数据(不是演示数据)
    final st2 = AppState();
    await st2.load(inMemory: true);
    st2.upsertChild(const Child(id: 'tablet', name: '平板上加的'));
    final acc2 = FakeAccount(accounts);
    final s2 = CloudSession(st2, account: () => acc2, db: () => db, init: () async {}, configured: true);
    await s2.start();
    await s2.signIn('m@x.com', 'pw123456');
    expect(s2.phase, CloudPhase.needsChoice);
    await s2.attachThisDevice(keepLocal: true);
    await settle([mom, s2]);
    expect(momSt.children.any((c) => c.id == 'tablet'), isTrue);
    expect(st2.children.length, momSt.children.length);
  });
  test('删除账号:还有家人时只把自己移出、数据留下;最后一个人删除时家庭数据一起删', () async {
    final (mom, momSt, momAcc) = await phone(demo: true);
    final (dad, dadSt, dadAcc) = await phone();
    await mom.signUp('m@x.com', 'pw123456');
    momAcc.verify();
    await mom.refreshVerification();
    await mom.createFamily();
    await mom.invite('d@x.com');
    await dad.signUp('d@x.com', 'pw123456');
    dadAcc.verify();
    await dad.refreshVerification();
    await dad.joinFamily(mom.familyId!, keepLocal: false);
    await settle([mom, dad]);
    final fid = mom.familyId!;
    final items = db.collection('families').doc(fid).collection('items');
    final n = (await items.get()).docs.length;

    expect(await dad.deleteAccount('wrong'), isFalse, reason: '密码不对不删');
    expect(await dad.deleteAccount('pw123456'), isTrue);
    await settle([mom, dad]);
    expect(dad.phase, CloudPhase.signedOut);
    expect(accounts.users.containsKey('d@x.com'), isFalse);
    expect((await items.get()).docs.length, n, reason: '妈妈还在,数据留着');
    expect(mom.family!.memberUids.length, 1);
    expect(dadSt.children, isNotEmpty, reason: '爸爸本机数据不受影响');

    expect(await mom.deleteAccount('pw123456'), isTrue);
    await settle([mom]);
    expect((await items.get()).docs, isEmpty, reason: '最后一个人删账号,家庭数据一起删');
    expect((await db.collection('users').get()).docs, isEmpty);
  });
}
