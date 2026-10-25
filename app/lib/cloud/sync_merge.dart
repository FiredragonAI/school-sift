// 家庭同步的合并规则(纯函数,和 Firebase 无关,单测覆盖)。
//
// 每条记录(一个孩子、一条通知、一个日程……)在云端是一份文档,内容是它的 JSON 字符串。
// 三方合并:本机现在的样子(local)、上次同步时双方一致的样子(base)、云端现在的样子(remote)。
//   本机没改过(local == base)       → 用云端的(包括云端删掉了)
//   本机删了(local 没有、base 有)    → 云端也没改过就删云端;云端改过就留云端的(别人的修改不被误删)
//   本机新增或改过(local != base)    → 用本机的,和云端不同就推上去
// 两个人同时改同一条:后推上去的为准(整条覆盖)。爸爸妈妈权限相同,没有谁说了算。

/// 一条记录。[t] 只用来排序(孩子、家庭成员按加入先后显示),不参与比较。
class SyncRecord {
  final String kind; // child / member / notice / event / task / grade / log / reply
  final String id;
  final String json;
  final int t;
  const SyncRecord({required this.kind, required this.id, required this.json, this.t = 0});

  String get docId => docIdFor(kind, id);
  static String docIdFor(String kind, String id) => '${kind}_$id';

  Map<String, dynamic> toJson() => {'kind': kind, 'id': id, 'json': json, 't': t};
  factory SyncRecord.fromJson(Map<String, dynamic> j) =>
      SyncRecord(kind: j['kind'] as String, id: j['id'] as String, json: j['json'] as String, t: (j['t'] as num?)?.toInt() ?? 0);

  SyncRecord withT(int t) => SyncRecord(kind: kind, id: id, json: json, t: t);
}

class MergeResult {
  /// 合并后本机应该是的样子
  final Map<String, SyncRecord> result;
  /// 要推到云端的(新增或修改)
  final Map<String, SyncRecord> push;
  /// 要从云端删掉的文档 id
  final Set<String> delete;
  const MergeResult(this.result, this.push, this.delete);

  bool get hasRemoteWrites => push.isNotEmpty || delete.isNotEmpty;
}

bool _same(SyncRecord? a, SyncRecord? b) => a?.json == b?.json; // 两个都没有也算相同

MergeResult mergeRecords({
  required Map<String, SyncRecord> local,
  required Map<String, SyncRecord> base,
  required Map<String, SyncRecord> remote,
}) {
  final result = <String, SyncRecord>{};
  final push = <String, SyncRecord>{};
  final delete = <String>{};
  for (final k in {...local.keys, ...base.keys, ...remote.keys}) {
    final l = local[k], b = base[k], r = remote[k];
    if (_same(l, b)) {
      if (r != null) result[k] = r;
    } else if (l == null) {
      if (_same(r, b)) {
        if (r != null) delete.add(k);
      } else if (r != null) {
        result[k] = r;
      }
    } else {
      // 本机新增或改过;排序键沿用云端已有的,新记录用本机给的
      final keep = r != null ? l.withT(r.t) : l;
      result[k] = keep;
      if (!_same(l, r)) push[k] = keep;
    }
  }
  return MergeResult(result, push, delete);
}

/// 本机保存后的增量:和 base 比,哪些要推、哪些要删。
MergeResult localDiff({required Map<String, SyncRecord> local, required Map<String, SyncRecord> base}) {
  final push = <String, SyncRecord>{};
  final delete = <String>{};
  for (final e in local.entries) {
    final b = base[e.key];
    if (!_same(e.value, b)) push[e.key] = b != null ? e.value.withT(b.t) : e.value;
  }
  for (final k in base.keys) {
    if (!local.containsKey(k)) delete.add(k);
  }
  // 没变的沿用 base(带着云端的排序键),变了的用推上去的
  final result = {for (final k in local.keys) k: push[k] ?? base[k]!};
  return MergeResult(result, push, delete);
}
