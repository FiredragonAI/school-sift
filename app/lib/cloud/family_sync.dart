// 家庭同步:把 AppState 的记录和照片与 Firestore 的 families/{fid}/items、images 保持一致。
//
//   本机保存  → 和 base(上次一致的样子)比,改了的推上去、删了的删掉(合并到下一个事件循环再推)
//   云端变化  → 三方合并(sync_merge.dart),结果写回本机;本机有、云端没有的照片补传
//   离线      → Firestore 自己排队写入;base 存在本机,重启后照样能分清是谁改的
// 本机的 Hive 仍是显示用的副本,所以没网、刚打开时界面马上有数据。

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../store/app_state.dart';
import 'sync_merge.dart';

enum SyncStartMode {
  /// 重启后接着同步:用本机存着的 base
  resume,
  /// 创建家庭 / 加入时保留本机数据:本机有、云端没有的都并进去
  merge,
  /// 加入时丢弃本机数据:直接用家庭的
  replace,
}

enum SyncStatus { connecting, synced, pending, offline, error }

class FamilySync implements StateSync {
  FamilySync({required this.db, required this.st, required this.familyId, required this.uid});

  final FirebaseFirestore db;
  final AppState st;
  final String familyId;
  final String uid;

  final status = ValueNotifier<SyncStatus>(SyncStatus.connecting);
  String? lastError;

  Map<String, SyncRecord> _base = {};
  bool _ready = false;
  bool _discardLocalOnce = false;
  bool _imagesReady = false;
  final Set<String> _remoteImageIds = {};
  StreamSubscription? _itemsSub, _imagesSub;
  Timer? _pushTimer;
  final List<Future<void>> _pending = [];

  CollectionReference<Map<String, dynamic>> get _items => db.collection('families').doc(familyId).collection('items');
  CollectionReference<Map<String, dynamic>> get _images => db.collection('families').doc(familyId).collection('images');

  bool get ready => _ready;

  Future<void> start(SyncStartMode mode) async {
    _base = mode == SyncStartMode.resume ? st.loadSyncBase(familyId) : {};
    _discardLocalOnce = mode == SyncStartMode.replace;
    st.sync = this;
    _itemsSub = _items.snapshots(includeMetadataChanges: true).listen(_onItems, onError: _onError);
    _imagesSub = _images.snapshots().listen(_onImages, onError: _onError);
  }

  Future<void> stop() async {
    _pushTimer?.cancel();
    await _itemsSub?.cancel();
    await _imagesSub?.cancel();
    if (identical(st.sync, this)) st.sync = null;
  }

  /// 等所有已发出的写入结束(测试和「退出前」用)
  Future<void> flush() async {
    _pushTimer?.cancel();
    _pushLocal();
    while (_pending.isNotEmpty) {
      await Future.wait(List.of(_pending));
    }
  }

  void _onError(Object e) {
    lastError = '$e';
    status.value = SyncStatus.error;
    debugPrint('sync error: $e');
  }

  // ---------- 云端 → 本机 ----------

  void _onItems(QuerySnapshot<Map<String, dynamic>> snap) {
    final meta = snap.metadata;
    status.value = meta.hasPendingWrites
        ? SyncStatus.pending
        : meta.isFromCache
            ? SyncStatus.offline
            : SyncStatus.synced;
    // 只是元数据变化(比如写入被服务器确认)时内容没变,不用重算
    if (_ready && snap.docChanges.isEmpty) return;

    final remote = <String, SyncRecord>{};
    for (final d in snap.docs) {
      final j = d.data();
      final json = j['json'];
      if (json is! String) continue;
      remote[d.id] = SyncRecord(kind: '${j['kind']}', id: '${j['id']}', json: json, t: (j['t'] as num?)?.toInt() ?? 0);
    }
    final local = _discardLocalOnce ? <String, SyncRecord>{} : st.syncRecords();
    _discardLocalOnce = false;
    final m = mergeRecords(local: local, base: _base, remote: remote);
    final push = _stampNew(m.push, remote);
    final result = {...m.result, ...push};
    _base = Map.of(result);
    if (!_sameRecords(st.syncRecords(), result)) st.applySyncRecords(result.values);
    _write(push, m.delete);
    st.saveSyncBase(familyId, _base);
    _ready = true;
    _uploadMissingImages();
  }

  void _onImages(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final c in snap.docChanges) {
      final id = c.doc.id;
      if (c.type == DocumentChangeType.removed) {
        _remoteImageIds.remove(id);
        st.dropImage(id);
      } else {
        _remoteImageIds.add(id);
        final b64 = c.doc.data()?['b64'];
        if (b64 is String) st.cacheImage(id, b64);
      }
    }
    _imagesReady = true;
    _uploadMissingImages();
  }

  /// 记录里引用了、本机有、云端没有的照片补传(创建家庭、合并本机数据、离线时拍的照片)
  void _uploadMissingImages() {
    if (!_ready || !_imagesReady) return;
    for (final id in st.referencedImageIds()) {
      if (_remoteImageIds.contains(id)) continue;
      final b64 = st.image(id);
      if (b64 != null) onImagePut(id, b64);
    }
  }

  // ---------- 本机 → 云端 ----------

  @override
  void onLocalSave() {
    _pushTimer?.cancel();
    _pushTimer = Timer(Duration.zero, _pushLocal);
  }

  void _pushLocal() {
    if (!_ready) return; // 第一次快照到了会一起合并
    final d = localDiff(local: st.syncRecords(), base: _base);
    if (!d.hasRemoteWrites) return;
    final push = _stampNew(d.push, _base);
    _base = {...d.result, ...push};
    _write(push, d.delete);
    st.saveSyncBase(familyId, _base);
  }

  @override
  void onImagePut(String id, String b64) {
    _remoteImageIds.add(id);
    final data = shrinkForCloud(b64);
    _track(_images.doc(id).set({'b64': data, 'by': uid, 'at': FieldValue.serverTimestamp()}));
  }

  @override
  void onImageRemoved(String id) {
    _remoteImageIds.remove(id);
    _track(_images.doc(id).delete());
  }

  /// 新记录(云端还没有的)给一个排序键:现在的时间,同一批按原来的先后
  Map<String, SyncRecord> _stampNew(Map<String, SyncRecord> push, Map<String, SyncRecord> known) {
    final now = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    final sorted = push.values.toList()..sort((a, b) => a.t.compareTo(b.t));
    return {for (final r in sorted) r.docId: known.containsKey(r.docId) ? r : r.withT(now + n++)};
  }

  void _write(Map<String, SyncRecord> push, Set<String> delete) {
    final ops = <void Function(WriteBatch)>[
      for (final r in push.values)
        (b) => b.set(_items.doc(r.docId), {
              'kind': r.kind,
              'id': r.id,
              'json': r.json,
              't': r.t,
              'by': uid,
              'at': FieldValue.serverTimestamp(),
            }),
      for (final k in delete) (b) => b.delete(_items.doc(k)),
    ];
    // 一个批次最多 500 次写入
    for (var i = 0; i < ops.length; i += 400) {
      final batch = db.batch();
      for (final op in ops.skip(i).take(400)) {
        op(batch);
      }
      _track(batch.commit());
    }
  }

  void _track(Future<void> f) {
    late final Future<void> wrapped;
    wrapped = f.catchError(_onError).whenComplete(() => _pending.remove(wrapped));
    _pending.add(wrapped);
  }

  /// [local] 来自 st.syncRecords()(t 是列表位置),[result] 是合并结果(t 是排序键)。
  /// 内容相同、孩子和家庭成员的先后也相同,才不用重写本机。
  static bool _sameRecords(Map<String, SyncRecord> local, Map<String, SyncRecord> result) {
    if (local.length != result.length) return false;
    for (final e in local.entries) {
      if (result[e.key]?.json != e.value.json) return false;
    }
    String order(Map<String, SyncRecord> m, String kind) {
      final rs = m.values.where((r) => r.kind == kind).toList()..sort((a, b) => a.t != b.t ? a.t.compareTo(b.t) : a.id.compareTo(b.id));
      return rs.map((r) => r.id).join(',');
    }

    for (final kind in const ['child', 'member']) {
      if (order(local, kind) != order(result, kind)) return false;
    }
    return true;
  }
}

/// Firestore 单个文档上限 1 MiB。拍照存进来的已缩到 1280 px / 质量 72,一般 150–400 KB;
/// 万一超过 900 KB(base64 字符数)就再缩一次,保证写得进去。
String shrinkForCloud(String b64) {
  if (b64.length <= 900000) return b64;
  try {
    final decoded = img.decodeImage(base64Decode(b64));
    if (decoded == null) return b64;
    var q = 60;
    var w = decoded.width > decoded.height ? 1000 : null;
    var h = decoded.height >= decoded.width ? 1000 : null;
    var out = base64Encode(img.encodeJpg(img.copyResize(decoded, width: w, height: h), quality: q));
    while (out.length > 900000 && q > 30) {
      q -= 10;
      w = w == null ? null : (w * 0.8).round();
      h = h == null ? null : (h * 0.8).round();
      out = base64Encode(img.encodeJpg(img.copyResize(decoded, width: w, height: h), quality: q));
    }
    return out;
  } catch (_) {
    return b64;
  }
}
