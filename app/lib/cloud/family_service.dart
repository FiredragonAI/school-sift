// 家庭与邀请(Firestore)。
//
//   families/{fid}            memberUids: [uid…]、memberEmails: {uid: email}、inviteEmails: [email…](都是小写)
//   families/{fid}/items/…    家庭的全部记录,见 family_sync.dart
//   families/{fid}/images/…   照片(压缩后的 base64)
//   users/{uid}               familyId:这个账号在哪个家庭
//
// 规则(firebase/firestore.rules):家庭成员权限完全相同——谁都能看、改、删全部记录,谁都能邀请或撤回邀请;
// 只能把自己移出家庭,不能踢别人。被邀请的人要用被邀请的邮箱登录并验证过,才能看到邀请、把自己加进去。

import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyInfo {
  final String id;
  final List<String> memberUids;
  final Map<String, String> memberEmails;
  final List<String> inviteEmails;
  const FamilyInfo({required this.id, required this.memberUids, required this.memberEmails, required this.inviteEmails});

  factory FamilyInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? const {};
    return FamilyInfo(
      id: d.id,
      memberUids: ((j['memberUids'] as List?) ?? const []).cast<String>(),
      memberEmails: Map<String, String>.from((j['memberEmails'] as Map?) ?? const {}),
      inviteEmails: ((j['inviteEmails'] as List?) ?? const []).cast<String>(),
    );
  }

  /// 邀请里显示「谁的家庭」:第一个成员的邮箱
  String get ownerLabel => memberUids.isEmpty ? '' : (memberEmails[memberUids.first] ?? '');
}

String normEmail(String e) => e.trim().toLowerCase();

bool looksLikeEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

class FamilyService {
  final FirebaseFirestore db;
  FamilyService(this.db);

  DocumentReference<Map<String, dynamic>> _family(String fid) => db.collection('families').doc(fid);
  DocumentReference<Map<String, dynamic>> _user(String uid) => db.collection('users').doc(uid);

  /// 这个账号现在所在的家庭(不在或已被移出返回 null)
  Future<String?> familyOf(String uid) async {
    final u = await _user(uid).get();
    final fid = u.data()?['familyId'] as String?;
    if (fid == null || fid.isEmpty) return null;
    try {
      final f = await _family(fid).get();
      if (!f.exists) return null;
      return FamilyInfo.fromDoc(f).memberUids.contains(uid) ? fid : null;
    } on FirebaseException {
      return null; // 被移出后读不了家庭文档
    }
  }

  /// 发给这个邮箱、还没接受的邀请
  Future<List<FamilyInfo>> invitesFor(String email) async {
    final q = await db.collection('families').where('inviteEmails', arrayContains: normEmail(email)).get();
    return q.docs.map(FamilyInfo.fromDoc).toList();
  }

  Future<String> create({required String uid, required String email}) async {
    final ref = db.collection('families').doc();
    await ref.set({
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'memberUids': [uid],
      'memberEmails': {uid: normEmail(email)},
      'inviteEmails': <String>[],
    });
    await _user(uid).set({'familyId': ref.id, 'email': normEmail(email)});
    return ref.id;
  }

  Future<void> join(String fid, {required String uid, required String email}) async {
    await _family(fid).update({
      'memberUids': FieldValue.arrayUnion([uid]),
      'inviteEmails': FieldValue.arrayRemove([normEmail(email)]),
      'memberEmails.$uid': normEmail(email),
    });
    await _user(uid).set({'familyId': fid, 'email': normEmail(email)});
  }

  Future<void> invite(String fid, String email) =>
      _family(fid).update({'inviteEmails': FieldValue.arrayUnion([normEmail(email)])});

  Future<void> cancelInvite(String fid, String email) =>
      _family(fid).update({'inviteEmails': FieldValue.arrayRemove([normEmail(email)])});

  Future<void> leave(String fid, {required String uid}) async {
    await _family(fid).update({
      'memberUids': FieldValue.arrayRemove([uid]),
      'memberEmails.$uid': FieldValue.delete(),
    });
    await _user(uid).set({'familyId': null}, SetOptions(merge: true));
  }

  /// 删除账号时调用:自己是家庭里最后一个人,就把家庭的全部记录、照片和邀请都删掉,再把自己移出;
  /// 还有别人,只把自己移出(数据留给家人)。最后删 users/{uid}。
  Future<void> removeAccountData(String? fid, {required String uid}) async {
    if (fid != null) {
      final f = await _family(fid).get();
      final info = f.exists ? FamilyInfo.fromDoc(f) : null;
      if (info != null && info.memberUids.length == 1 && info.memberUids.first == uid) {
        for (final sub in ['items', 'images']) {
          final docs = (await _family(fid).collection(sub).get()).docs;
          for (var i = 0; i < docs.length; i += 400) {
            final batch = db.batch();
            for (final d in docs.skip(i).take(400)) {
              batch.delete(d.reference);
            }
            await batch.commit();
          }
        }
        await _family(fid).update({'inviteEmails': <String>[]});
      }
      if (info != null && info.memberUids.contains(uid)) await leave(fid, uid: uid);
    }
    await _user(uid).delete();
  }

  Stream<FamilyInfo?> watch(String fid) => _family(fid).snapshots().map((d) => d.exists ? FamilyInfo.fromDoc(d) : null);
}
