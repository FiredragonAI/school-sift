// 不打真网络:验证请求体形状(结构化输出、附件块、浏览器直连头)和返回 JSON → Extraction 的映射。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_sift/core/claude_extractor.dart';
import 'package:school_sift/core/notice_parser.dart';
import 'package:school_sift/models/models.dart';

void main() {
  test('请求体与返回映射', () async {
    Map<String, dynamic>? sent;
    Map<String, String>? headers;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      headers = req.headers;
      final out = {
        'title': 'Field trip',
        'reschedule': false,
        'summary': ['Trip on Oct 24', 'Slip due Oct 17'],
        'items': [
          {'type': 'event', 'title': 'Field trip to the Exploratorium', 'date': '2026-10-24', 'start': '09:00', 'end': '13:30', 'location': 'Exploratorium', 'amount': null, 'confidence': 0.95, 'evidence': 'our field trip ...'},
          {'type': 'sign', 'title': 'Sign: permission slip', 'date': '2026-10-17', 'start': null, 'end': null, 'location': '', 'amount': null, 'confidence': 0.9, 'evidence': 'Please sign ...'},
          {'type': 'pay', 'title': 'Pay: field trip fee', 'date': '2026-10-17', 'start': null, 'end': null, 'location': '', 'amount': 12, 'confidence': 0.9, 'evidence': 'The cost is \$12'},
        ],
      };
      return http.Response(
        jsonEncode({
          'id': 'msg_1',
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': jsonEncode(out)},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final ex = await ClaudeExtractor(apiKey: 'sk-test', model: 'claude-opus-5-5', client: client).extract(
      text: 'hello',
      attachments: const [ClaudeAttachment('image/jpeg', 'AAAA'), ClaudeAttachment('application/pdf', 'BBBB')],
      today: const Day(2026, 10, 1),
      uiLang: 'en',
    );
    // 头
    expect(headers!['x-api-key'], 'sk-test');
    expect(headers!['anthropic-dangerous-direct-browser-access'], 'true');
    expect(headers!['anthropic-version'], '2023-06-01');
    // 体
    expect(sent!['model'], 'claude-opus-5-5');
    expect(sent!['output_config']['format']['type'], 'json_schema');
    expect(sent!['output_config']['effort'], 'low');
    expect(sent!['fallbacks'], 'default');
    final content = (sent!['messages'][0]['content'] as List);
    expect(content.where((b) => b['type'] == 'image').length, 1);
    expect(content.where((b) => b['type'] == 'document').length, 1);
    expect(content.last['type'], 'text');
    expect(sent!['system'], contains('2026-10-01'));
    // 映射
    expect(ex.title, 'Field trip');
    expect(ex.items.length, 3);
    final ev = ex.items.firstWhere((i) => i.type == ItemType.event);
    expect(ev.day, const Day(2026, 10, 24));
    expect(ev.start, const TimeOfDay(hour: 9, minute: 0));
    expect(ev.end, const TimeOfDay(hour: 13, minute: 30));
    expect(ex.items.firstWhere((i) => i.type == ItemType.pay).amount, 12);
    expect(ex.summary.length, 2);
  });

  test('Haiku 不带 effort / fallbacks;401 映射成可读错误', () async {
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}}), 401);
    });
    try {
      await ClaudeExtractor(apiKey: 'bad', model: 'claude-haiku-4-5', client: client).extract(text: 'x', today: const Day(2026, 10, 1), uiLang: 'zh');
      fail('should throw');
    } on ClaudeError catch (e) {
      expect(e.status, 401);
      expect(e.message, contains('API key'));
    }
    expect((sent!['output_config'] as Map).containsKey('effort'), isFalse);
    expect(sent!.containsKey('fallbacks'), isFalse);
  });

  test('坏日期/坏时间不崩', () {
    final ex = ClaudeExtractor.parseResult({
      'title': 't',
      'reschedule': true,
      'summary': [],
      'items': [
        {'type': 'bring', 'title': 'Bring: lunch', 'date': '2026-02-30', 'start': '25:00', 'end': null, 'location': '', 'amount': null, 'confidence': 2, 'evidence': ''},
      ],
    });
    expect(ex.reschedule, isTrue);
    expect(ex.items.single.day, isNull);
    expect(ex.items.single.start, isNull);
    expect(ex.items.single.confidence, 1.0);
  });
}
