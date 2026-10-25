import 'package:flutter_test/flutter_test.dart';
import 'package:school_sift/cloud/sync_merge.dart';

SyncRecord r(String id, String json, {int t = 0}) => SyncRecord(kind: 'task', id: id, json: json, t: t);
Map<String, SyncRecord> m(List<SyncRecord> rs) => {for (final x in rs) x.docId: x};

void main() {
  test('本机没改:用云端的(包括云端新增、修改、删除)', () {
    final base = m([r('a', 'A'), r('b', 'B')]);
    final local = m([r('a', 'A'), r('b', 'B')]);
    final remote = m([r('a', 'A2'), r('c', 'C')]); // a 被改、b 被删、c 新增
    final res = mergeRecords(local: local, base: base, remote: remote);
    expect(res.result.keys, unorderedEquals(['task_a', 'task_c']));
    expect(res.result['task_a']!.json, 'A2');
    expect(res.hasRemoteWrites, isFalse);
  });

  test('本机改了 / 新增:用本机的并推上去;云端已有的排序键沿用', () {
    final base = m([r('a', 'A', t: 5)]);
    final local = m([r('a', 'A-local', t: 0), r('n', 'N', t: 1)]);
    final remote = m([r('a', 'A', t: 5)]);
    final res = mergeRecords(local: local, base: base, remote: remote);
    expect(res.result['task_a']!.json, 'A-local');
    expect(res.result['task_a']!.t, 5);
    expect(res.push.keys, unorderedEquals(['task_a', 'task_n']));
    expect(res.delete, isEmpty);
  });

  test('本机删了:云端没改就删云端;云端改过就留云端的', () {
    final base = m([r('a', 'A'), r('b', 'B')]);
    final local = m(<SyncRecord>[]);
    final remote = m([r('a', 'A'), r('b', 'B-edited-by-dad')]);
    final res = mergeRecords(local: local, base: base, remote: remote);
    expect(res.delete, {'task_a'});
    expect(res.result.keys, ['task_b']);
    expect(res.result['task_b']!.json, 'B-edited-by-dad');
  });

  test('第一次合并(base 为空):两边都留,同一条以本机为准', () {
    final local = m([r('x', 'X-local'), r('mine', 'M')]);
    final remote = m([r('x', 'X-remote'), r('theirs', 'T')]);
    final res = mergeRecords(local: local, base: const {}, remote: remote);
    expect(res.result.keys, unorderedEquals(['task_x', 'task_mine', 'task_theirs']));
    expect(res.result['task_x']!.json, 'X-local');
    expect(res.push.keys, unorderedEquals(['task_x', 'task_mine']));
  });

  test('本机增量:改了推、删了删、没变的保留 base 的排序键', () {
    final base = m([r('a', 'A', t: 100), r('b', 'B', t: 200)]);
    final local = m([r('a', 'A', t: 0), r('c', 'C', t: 1)]);
    final d = localDiff(local: local, base: base);
    expect(d.push.keys, ['task_c']);
    expect(d.delete, {'task_b'});
    expect(d.result['task_a']!.t, 100);
  });
}
