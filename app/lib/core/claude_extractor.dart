// 用家长自己的 Claude API key 做通知理解(可选;没 key 时走 notice_parser 的规则)。
//
// 直接从客户端调 Anthropic Messages API(Dart 没有官方 SDK,走 HTTP):
//   - 密钥只在本机设置里,随请求发给 api.anthropic.com,不经过我们的任何服务器
//   - 请求里带的是这一条通知的文字 / 照片 / PDF,别的数据不发
//   - 用结构化输出(output_config.format = json_schema)保证返回能直接解析成 Extraction
// 浏览器里直连需要 anthropic-dangerous-direct-browser-access 头,否则被 CORS 拦。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'notice_parser.dart';

class ClaudeAttachment {
  final String mediaType; // image/jpeg | image/png | application/pdf
  final String base64Data;
  const ClaudeAttachment(this.mediaType, this.base64Data);
}

class ClaudeError implements Exception {
  final String message;
  final int? status;
  const ClaudeError(this.message, {this.status});
  @override
  String toString() => message;
}

class ClaudeExtractor {
  final String apiKey;
  final String model;
  final http.Client _client;
  ClaudeExtractor({required this.apiKey, required this.model, http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// 返回结构的 JSON Schema。日期 YYYY-MM-DD、时间 HH:MM,拿不准就 null。
  static final Map<String, dynamic> schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['title', 'reschedule', 'summary', 'items'],
    'properties': {
      'title': {'type': 'string'},
      'reschedule': {'type': 'boolean'},
      'summary': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['type', 'title', 'date', 'start', 'end', 'location', 'amount', 'confidence', 'evidence'],
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['event', 'sign', 'pay', 'bring', 'deadline'],
            },
            'title': {'type': 'string'},
            'date': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
            },
            'start': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
            },
            'end': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
            },
            'location': {'type': 'string'},
            'amount': {
              'anyOf': [
                {'type': 'number'},
                {'type': 'null'},
              ],
            },
            'confidence': {'type': 'number'},
            'evidence': {'type': 'string'},
          },
        },
      },
    },
  };

  static String systemPrompt({required Day today, required String uiLang}) {
    final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][today.weekday - 1];
    final lang = uiLang == 'zh' ? 'Simplified Chinese' : 'English';
    return '''
You read school notices for a busy parent and turn them into concrete calendar items and parent to-dos.
Today is ${today.key} ($wd). Resolve every relative or partial date ("next Friday", "Oct 24", "明天") to an absolute YYYY-MM-DD; a month-day without a year is the nearest upcoming occurrence. Times are 24h HH:MM.

Produce:
- title: a short name for the notice (<= 30 chars).
- reschedule: true if the notice changes, moves, or cancels something previously announced.
- summary: at most 3 short bullet strings a parent needs to know.
- items: one entry per actionable thing.
  - type "event": something that happens on a date (field trip, conference, picture day, test, no-school day, early dismissal, performance...). Include start/end if stated, location if stated.
  - type "sign": a form/permission slip/consent the parent must sign and return; date = the return deadline.
  - type "pay": money to pay; amount = number without currency; date = deadline.
  - type "bring": something the child must bring or wear; date = the day it is needed.
  - type "deadline": any other deadline (RSVP, register, submit, order).
  Do not duplicate the same obligation under two types. Skip generic pleasantries. If a sentence contains both an event and a deadline, emit both.
- confidence: 0..1, how sure you are the date/time/type are right.
- evidence: the exact sentence (or image region text) the item came from, in the original language.
Write item titles and summary in $lang; keep proper nouns (school, teacher, place names) as written. Titles: for sign/pay/bring/deadline start with what to do, e.g. "签字:春游同意书" / "Sign: field trip permission slip".
If an image is a photo of a paper notice, read it carefully including handwriting and tables.
''';
  }

  Future<Extraction> extract({
    required String text,
    List<ClaudeAttachment> attachments = const [],
    required Day today,
    required String uiLang,
  }) async {
    final content = <Map<String, dynamic>>[
      for (final a in attachments)
        if (a.mediaType == 'application/pdf')
          {
            'type': 'document',
            'source': {'type': 'base64', 'media_type': a.mediaType, 'data': a.base64Data},
          }
        else
          {
            'type': 'image',
            'source': {'type': 'base64', 'media_type': a.mediaType, 'data': a.base64Data},
          },
      {
        'type': 'text',
        'text': text.trim().isEmpty ? 'Extract everything from the attached notice.' : 'Notice text:\n\n${text.trim()}',
      },
    ];
    final isHaiku = model.contains('haiku');
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 8000,
      'system': systemPrompt(today: today, uiLang: uiLang),
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'output_config': {
        if (!isHaiku) 'effort': 'low', // 抽取不需要深思;Haiku 不认 effort
        'format': {'type': 'json_schema', 'schema': schema},
      },
      if (!isHaiku) 'fallbacks': 'default', // 安全分类器误判时服务端自动换模型重试
    };
    final headers = {
      'content-type': 'application/json',
      'x-api-key': apiKey.trim(),
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
      if (!isHaiku) 'anthropic-beta': 'server-side-fallback-2026-07-01',
    };

    http.Response res;
    try {
      res = await _client
          .post(Uri.parse(_endpoint), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw ClaudeError('网络错误:$e');
    }
    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        final j = jsonDecode(utf8.decode(res.bodyBytes));
        msg = j['error']?['message']?.toString() ?? msg;
      } catch (_) {}
      if (res.statusCode == 401) msg = 'API key 无效($msg)';
      if (res.statusCode == 429) msg = '请求太频繁或额度不足($msg)';
      throw ClaudeError(msg, status: res.statusCode);
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final stop = j['stop_reason'];
    if (stop == 'refusal') {
      throw const ClaudeError('模型拒绝处理这条内容(安全策略)');
    }
    if (stop == 'max_tokens') {
      throw const ClaudeError('输出被截断,请把通知拆短一点再试');
    }
    final textBlock = (j['content'] as List).cast<Map<String, dynamic>>().firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => throw const ClaudeError('返回里没有文本'),
        );
    return parseResult(jsonDecode(textBlock['text'] as String) as Map<String, dynamic>);
  }

  /// 把模型返回的 JSON 映射成和规则解析器相同的 Extraction(确认页不用区分来源)。
  static Extraction parseResult(Map<String, dynamic> j) {
    final items = <ExtractedItem>[];
    for (final raw in (j['items'] as List? ?? [])) {
      final it = Map<String, dynamic>.from(raw as Map);
      final type = ItemType.values.where((t) => t.name == it['type']).firstOrNull ?? ItemType.event;
      items.add(ExtractedItem(
        type: type,
        title: (it['title'] ?? '').toString(),
        day: _day(it['date']),
        start: _tod(it['start']),
        end: _tod(it['end']),
        location: (it['location'] ?? '').toString(),
        amount: (it['amount'] as num?)?.toDouble(),
        confidence: ((it['confidence'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
        evidence: (it['evidence'] ?? '').toString(),
      ));
    }
    items.sort((a, b) => (a.day?.key ?? '9999').compareTo(b.day?.key ?? '9999'));
    return Extraction(
      title: (j['title'] ?? '').toString(),
      items: items,
      reschedule: j['reschedule'] == true,
      summary: ((j['summary'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }

  static Day? _day(dynamic v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(v);
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final t = DateTime(y, mo, d);
    if (t.month != mo) return null;
    return Day.of(t);
  }

  static TimeOfDay? _tod(dynamic v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v);
    if (m == null) return null;
    final h = int.parse(m[1]!), mi = int.parse(m[2]!);
    if (h > 23 || mi > 59) return null;
    return TimeOfDay(hour: h, minute: mi);
  }
}
