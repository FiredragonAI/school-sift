// 通知理解(规则版):从一段格式随意的学校通知(中文或英文)里抽出
//   - 日程候选:日期 + 时间 + 地点
//   - 待办候选:要签字回执、要交钱、要带东西,各带截止日期
//   - 是否是"改期"通知
// 纯规则、确定性、离线可跑;给出置信度让家长在确认页一眼看出哪条需要改。
// 有 Claude API key 时走 claude_extractor.dart,返回同样的 Extraction 结构。

import 'package:flutter/material.dart';

import '../models/models.dart';

enum ItemType { event, sign, pay, bring, deadline }

class ExtractedItem {
  ItemType type;
  String title;
  Day? day;
  TimeOfDay? start;
  TimeOfDay? end;
  String location;
  double? amount;
  double confidence; // 0..1
  String evidence; // 来源句子
  bool keep = true;
  ExtractedItem({
    required this.type,
    required this.title,
    this.day,
    this.start,
    this.end,
    this.location = '',
    this.amount,
    required this.confidence,
    required this.evidence,
  });
}

class Extraction {
  final String title;
  final List<ExtractedItem> items;
  final bool reschedule;
  final List<String> summary; // 三句以内要点
  const Extraction({
    required this.title,
    required this.items,
    required this.reschedule,
    required this.summary,
  });
}

class NoticeParser {
  final Day today;
  NoticeParser({Day? today}) : today = today ?? Day.today();

  static final _signRe = RegExp(
      r'签字|签名|签收|回执|家长签|确认单|同意书|知情书|sign(ed)? and return|signature|permission (slip|form)|consent form|waiver|return the (slip|form)|acknowledg',
      caseSensitive: false);
  static final _payRe = RegExp(
      r'缴费|交费|费用|收费|交钱|付款|转账|报名费|餐费|书本费|校服费|班费|\bpay(ment)?\b|\bfee\b|\bcost\b|donation|fundrais|order form|\$\s?\d|¥|￥|\d+(\.\d+)?\s*元',
      caseSensitive: false);
  static final _payStrongRe = RegExp(
      r'缴费|交费|交钱|付款|报名费|餐费|校服费|班费|\bpayment\b|\bfee\b|donation|\$\s?\d|¥|￥|\d+(\.\d+)?\s*元',
      caseSensitive: false);
  static final _bringRe = RegExp(
      r'请?(自备|携带|带好|带上|准备好|穿)|请.{0,6}带|需要带|记得带|\bbring\b|\bwear\b|\bpack\b|dress (in|up|as)|send (in|with)',
      caseSensitive: false);
  static final _deadlineRe = RegExp(
      r'截止|之前|以前|前(交|提交|上交|完成|回复|报名|缴)|最晚|务必于|不晚于|deadline|\bdue\b|\bby\s|no later than|\bbefore\b|rsvp|turn in|sign up|register',
      caseSensitive: false);
  static final _rescheduleRe = RegExp(
      r'改为|改到|改至|调整为|调整到|延期|推迟|提前到|提前至|顺延|时间变更|变更为|另行通知|取消|rescheduled|moved to|changed to|postponed|cancel+ed|new (date|time)|has been moved|date change|time change',
      caseSensitive: false);
  static final _eventWordRe = RegExp(
      r'家长会|运动会|开放日|春游|秋游|研学|参观|演出|汇演|比赛|考试|测验|测试|月考|期中|期末|放假|停课|调休|返校|开学|典礼|讲座|体检|筛查|检查|接种|疫苗|义卖|社团|课后|集合|出发'
      r'|field trip|parent.?teacher conferences?|conferences?|open house|back to school night|assembly|picture day|spirit day|pajama day|minimum day|early (release|dismissal)|no school|book fair|science fair|talent show|fall festival|spring festival|jog-a-thon|walk-a-thon|fun run|report cards?|awards?|graduation|promotion|orientation|exam|test|quiz|holiday|concert|recital|performance|rehearsal|game|practice|trip|fair|meeting|screening|vaccination|dress.?up day',
      caseSensitive: false);

  static const _cnNum = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
  static const _enMonths = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  static const _enWeek = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7};

  /// 中文字符占比很低就按英文处理(标题前缀、摘要用英文)
  static bool isEnglish(String t) {
    final cjk = RegExp(r'[一-龥]').allMatches(t).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    return letters > 0 && cjk < (letters + cjk) * 0.08;
  }

  Extraction parse(String text, {String? titleHint}) {
    final clean = text.replaceAll('\r', '').trim();
    final en = isEnglish(clean);
    final sentences = _split(clean, en);
    final items = <ExtractedItem>[];
    final reschedule = _rescheduleRe.hasMatch(clean);

    // 文档级信号:整段提到签字/缴费时,即使具体句子里没日期也要生成待办。
    bool docSign = false, docPay = false, docBring = false;

    for (final s in sentences) {
      final dates = _findDates(s);
      final times = _findTimes(s);
      final loc = _findLocation(s);
      final amount = _findAmount(s);
      final hasSign = _signRe.hasMatch(s);
      final hasPay = (_payRe.hasMatch(s) && amount != null) || _payStrongRe.hasMatch(s);
      final hasBring = _bringRe.hasMatch(s);
      final hasDeadline = _deadlineRe.hasMatch(s);
      docSign |= hasSign;
      docPay |= hasPay;
      docBring |= hasBring;

      if (dates.isEmpty) continue;
      // 一句里多个日期:通常是"X日至Y日"的范围,取第一个做事件、最后一个做截止;
      // 但"原定明天的秋游改到下周三"这种改期句,新日期在后面,取最后一个。
      final first = _rescheduleRe.hasMatch(s) ? dates.last : dates.first;
      final last = dates.last;
      final isAction = hasSign || hasPay || hasBring || hasDeadline;

      if (isAction) {
        final type = hasSign
            ? ItemType.sign
            : hasPay
                ? ItemType.pay
                : hasBring
                    ? ItemType.bring
                    : ItemType.deadline;
        items.add(ExtractedItem(
          type: type,
          title: _actionTitle(type, s, titleHint, en),
          day: last.day,
          amount: hasPay ? amount : null,
          confidence: _conf(last.confidence, s, action: true),
          evidence: s,
        ));
        // 既有截止又像活动(例如"请于 5 日前报名,活动 12 日举行")→ 也给事件
        if (dates.length >= 2 && _eventWordRe.hasMatch(s)) {
          items.add(ExtractedItem(
            type: ItemType.event,
            title: _eventTitle(s, titleHint, en),
            day: first.day,
            start: times.isNotEmpty ? times.first.$1 : null,
            end: times.isNotEmpty ? times.first.$2 : null,
            location: loc,
            confidence: _conf(first.confidence, s) * 0.85,
            evidence: s,
          ));
        }
      } else {
        items.add(ExtractedItem(
          type: ItemType.event,
          title: _eventTitle(s, titleHint, en),
          day: first.day,
          start: times.isNotEmpty ? times.first.$1 : null,
          end: times.isNotEmpty ? times.first.$2 : null,
          location: loc,
          confidence: _conf(first.confidence, s),
          evidence: s,
        ));
      }
    }

    // 无日期的文档级待办:兜底生成,置信度低,默认截止 = 最近的事件前一天
    final firstEvent = items.where((e) => e.type == ItemType.event).toList()..sort((a, b) => a.day!.compareTo(b.day!));
    final fallbackDue = firstEvent.isNotEmpty ? firstEvent.first.day!.add(-1) : null;
    if (docSign && items.every((e) => e.type != ItemType.sign)) {
      final ev = _sentenceWith(sentences, _signRe);
      items.add(ExtractedItem(type: ItemType.sign, title: _actionTitle(ItemType.sign, ev, titleHint, en), day: fallbackDue, confidence: 0.55, evidence: ev));
    }
    if (docPay && items.every((e) => e.type != ItemType.pay)) {
      final ev = _sentenceWith(sentences, _payRe);
      items.add(ExtractedItem(type: ItemType.pay, title: _actionTitle(ItemType.pay, ev, titleHint, en), day: fallbackDue, amount: _findAmount(clean), confidence: 0.55, evidence: ev));
    }
    if (docBring && items.every((e) => e.type != ItemType.bring)) {
      final ev = _sentenceWith(sentences, _bringRe);
      items.add(ExtractedItem(type: ItemType.bring, title: _actionTitle(ItemType.bring, ev, titleHint, en), day: firstEvent.isNotEmpty ? firstEvent.first.day : null, confidence: 0.5, evidence: ev));
    }

    // 同一天同类型同标题去重(保留置信度高的)
    final dedup = <String, ExtractedItem>{};
    for (final it in items) {
      final k = '${it.type.name}|${it.day?.key}|${it.title}';
      if (!dedup.containsKey(k) || dedup[k]!.confidence < it.confidence) dedup[k] = it;
    }
    final out = dedup.values.toList()..sort((a, b) => (a.day?.key ?? '9999').compareTo(b.day?.key ?? '9999'));

    return Extraction(
      title: titleHint?.trim().isNotEmpty == true ? titleHint!.trim() : _guessTitle(clean, en),
      items: out,
      reschedule: reschedule,
      summary: _summary(out, reschedule, en),
    );
  }

  // ---------- 句子切分 ----------
  List<String> _split(String t, bool en) {
    var text = t;
    if (en) {
      // 英文邮件一段话里好几句:句号/问号/叹号 + 空格 + 大写字母处切开("Mr. Smith"会误切,无妨)
      text = text.replaceAllMapped(RegExp(r'(?<=[.!?])\s+(?=[A-Z"“(])'), (_) => '\n');
      // 项目符号
      text = text.replaceAll(RegExp(r'\s+[•\-–*]\s+'), '\n');
    }
    final raw = text.split(RegExp(r'[\n。!！?？;；]+'));
    return raw.map((s) => s.trim()).where((s) => s.length >= 2).toList();
  }

  /// 含有匹配的那一整句(给确认页看依据用)
  String _sentenceWith(List<String> ss, RegExp re) => ss.firstWhere((s) => re.hasMatch(s), orElse: () => '');

  // ---------- 日期 ----------
  List<({Day day, double confidence})> _findDates(String s) {
    final res = <({Day day, double confidence})>[];
    final lower = s.toLowerCase();

    // 2026年10月8日 / 2026-10-08 / 2026/10/8
    for (final m in RegExp(r'(20\d{2})\s*[年\-/.]\s*(\d{1,2})\s*[月\-/.]\s*(\d{1,2})\s*[日号]?').allMatches(s)) {
      final d = _safe(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) res.add((day: d, confidence: 0.95));
    }
    // 10/24/2026 (美式 月/日/年)
    for (final m in RegExp(r'(?<!\d)(\d{1,2})/(\d{1,2})/(20\d{2})(?!\d)').allMatches(s)) {
      final d = _safe(int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!));
      if (d != null && !res.any((r) => r.day == d)) res.add((day: d, confidence: 0.95));
    }
    // 10月8日 / 10月8号 (无年份 → 最近的将来)
    for (final m in RegExp(r'(?<!\d)(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]').allMatches(s)) {
      final d = _nearest(int.parse(m[1]!), int.parse(m[2]!));
      if (d != null && !res.any((r) => r.day == d)) res.add((day: d, confidence: 0.85));
    }
    // Oct 8 / October 8th / Oct. 8, 2026 / October 24-25
    for (final m in RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(st|nd|rd|th)?(?:\s*[-–]\s*(\d{1,2})(?:st|nd|rd|th)?)?(,?\s*(20\d{2}))?(?!\d|:)')
        .allMatches(lower)) {
      final mo = _enMonths[m[1]!]!;
      final dd = int.parse(m[2]!);
      final year = m[6];
      final d = year != null ? _safe(int.parse(year), mo, dd) : _nearest(mo, dd);
      if (d != null && !res.any((r) => r.day == d)) res.add((day: d, confidence: year != null ? 0.95 : 0.85));
      if (m[4] != null) {
        final d2 = year != null ? _safe(int.parse(year), mo, int.parse(m[4]!)) : _nearest(mo, int.parse(m[4]!));
        if (d2 != null && !res.any((r) => r.day == d2)) res.add((day: d2, confidence: 0.8));
      }
    }
    // 8 Oct / 8th October
    for (final m in RegExp(r'\b(\d{1,2})(st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\b').allMatches(lower)) {
      final d = _nearest(_enMonths[m[3]!]!, int.parse(m[1]!));
      if (d != null && !res.any((r) => r.day == d)) res.add((day: d, confidence: 0.85));
    }
    // 10/8 或 10.8 (无年份;月在前)
    if (res.isEmpty) {
      for (final m in RegExp(r'(?<![\d:：/.])(\d{1,2})[/.](\d{1,2})(?![\d:：/.])').allMatches(s)) {
        final d = _nearest(int.parse(m[1]!), int.parse(m[2]!));
        if (d != null) res.add((day: d, confidence: 0.6));
      }
    }
    if (res.isNotEmpty) return res;

    // 相对日期
    if (s.contains('大后天')) {
      res.add((day: today.add(3), confidence: 0.8));
    } else if (s.contains('后天')) {
      res.add((day: today.add(2), confidence: 0.8));
    } else if (s.contains('明天') || s.contains('明日') || lower.contains('tomorrow')) {
      res.add((day: today.add(1), confidence: 0.8));
    } else if (s.contains('今天') || s.contains('今日') || RegExp(r'\btoday\b|\btonight\b').hasMatch(lower)) {
      res.add((day: today, confidence: 0.75));
    }
    // 相对日期之后继续找星期几:"原定明天…改到下周三"两个都要

    // 本周三 / 下周五 / 周四 / 星期二 / this Friday / next Monday
    final cn = RegExp(r'(本|这|下下|下)?(周|星期|礼拜)([一二三四五六日天])').firstMatch(s);
    if (cn != null) {
      final wd = _cnNum[cn[3]!]!;
      final prefix = cn[1] ?? '';
      res.add((day: _weekdayDay(wd, prefix), confidence: prefix.isEmpty ? 0.6 : 0.75));
      return res;
    }
    final enM = RegExp(r'\b(this|next)?\s*(mon|tue|wed|thu|fri|sat|sun)[a-z]*\b').firstMatch(lower);
    if (enM != null && enM[2] != null) {
      final wd = _enWeek[enM[2]!]!;
      final prefix = enM[1] == 'next' ? '下' : (enM[1] == 'this' ? '本' : '');
      final d = _weekdayDay(wd, prefix);
      if (!res.any((r) => r.day == d)) res.add((day: d, confidence: prefix.isEmpty ? 0.6 : 0.75));
    }
    return res;
  }

  Day _weekdayDay(int wd, String prefix) {
    final cur = today.weekday; // 1..7
    final thisWeek = today.add(wd - cur);
    switch (prefix) {
      case '本':
      case '这':
        return thisWeek;
      case '下':
        return thisWeek.add(7);
      case '下下':
        return thisWeek.add(14);
      default:
        // 无前缀:最近的将来那一天(今天算)
        return thisWeek.compareTo(today) < 0 ? thisWeek.add(7) : thisWeek;
    }
  }

  Day? _safe(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final t = DateTime(y, m, d);
    if (t.month != m) return null;
    return Day.of(t);
  }

  /// 无年份的月日:取 today 之前 45 天到之后 320 天这个窗口里的那一年
  Day? _nearest(int m, int d) {
    final a = _safe(today.y, m, d);
    if (a == null) return null;
    if (a.diff(today) < -45) return _safe(today.y + 1, m, d);
    return a;
  }

  // ---------- 时间 ----------
  List<(TimeOfDay, TimeOfDay?)> _findTimes(String s) {
    final out = <(TimeOfDay, TimeOfDay?)>[];
    final re = RegExp(
        r'(上午|早上|早晨|中午|下午|晚上|傍晚|am|pm)?\s*(\d{1,2})\s*[:：点时]\s*(\d{2})?\s*分?\s*(半)?\s*(am|pm|a\.m\.|p\.m\.)?'
        r'(?:\s*(?:[-~—–至到]|to)\s*(上午|下午|晚上)?\s*(\d{1,2})\s*[:：点时]?\s*(\d{2})?\s*分?\s*(半)?\s*(am|pm|a\.m\.|p\.m\.)?)?',
        caseSensitive: false);
    for (final m in re.allMatches(s)) {
      final h1 = int.parse(m[2]!);
      if (h1 > 24) continue;
      // "8时"要排除日期尾巴:前面是"月"的不算
      final before = m.start > 0 ? s[m.start - 1] : '';
      if (before == '月' && m[3] == null) continue;
      var ap = (m[1] ?? m[5] ?? '').toLowerCase();
      final ap2 = (m[6] ?? m[10] ?? '').toLowerCase();
      // "6:00-7:30 PM":开始没写上下午,跟结束的走;"9:00 to 1:30 PM" 开始在上午,不能跟
      if (ap.isEmpty && ap2.isNotEmpty) {
        final h2 = int.parse(m[7]!);
        ap = (ap2.startsWith('p') && h1 > h2 && h1 != 12) ? 'am' : ap2;
      }
      final start = _tod(h1, m[3], m[4] != null, ap);
      TimeOfDay? end;
      if (m[7] != null) {
        end = _tod(int.parse(m[7]!), m[8], m[9] != null, ap2.isEmpty ? ap : ap2);
      }
      out.add((start, end));
    }
    // 英文 3pm / 3 pm / 8am-2pm / noon
    if (out.isEmpty) {
      final m = RegExp(r'\b(\d{1,2})\s*(am|pm)(?:\s*(?:-|–|to)\s*(\d{1,2})\s*(am|pm))?\b', caseSensitive: false).firstMatch(s);
      if (m != null) {
        final st = _tod(int.parse(m[1]!), null, false, m[2]!.toLowerCase());
        final en = m[3] != null ? _tod(int.parse(m[3]!), null, false, m[4]!.toLowerCase()) : null;
        out.add((st, en));
      } else if (RegExp(r'\bnoon\b', caseSensitive: false).hasMatch(s)) {
        out.add((const TimeOfDay(hour: 12, minute: 0), null));
      }
    }
    return out;
  }

  TimeOfDay _tod(int h, String? mm, bool half, String ap) {
    var hour = h;
    final pm = ap.contains('下午') || ap.contains('晚') || ap.contains('傍') || ap.startsWith('p') || (ap.contains('中午') && h < 6);
    if (pm && hour < 12) hour += 12;
    if (ap.startsWith('a') && hour == 12) hour = 0;
    final minute = half ? 30 : (mm == null ? 0 : int.parse(mm));
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  // ---------- 地点 / 金额 ----------
  String _findLocation(String s) {
    final m1 = RegExp(r'(地点|集合地点|地址|位置|location|venue|where)\s*[:：]\s*([^,，。;；\n]{2,30})', caseSensitive: false).firstMatch(s);
    if (m1 != null) return m1[2]!.trim();
    final m2 = RegExp(r'在([^\s,，。;；]{2,15}?)(举行|举办|集合|进行|召开|开展|上课)').firstMatch(s);
    if (m2 != null) return m2[1]!;
    final m3 = RegExp(
            r'\b(?:at|in) (?:the )?([A-Z][\w&\x27-]*(?: [A-Z][\w&\x27-]*){0,4}(?: (?:gym|hall|room|library|cafeteria|auditorium|field|park|school|center|centre|mpr|playground|office|museum|zoo|theater|theatre))?)',
            caseSensitive: false)
        .firstMatch(s);
    if (m3 != null) {
      final cand = m3[1]!.trim();
      // 避免把 "at 9:00" / "in October" 之类当地点
      if (!RegExp(r'^\d|^(january|february|march|april|may|june|july|august|september|october|november|december|monday|tuesday|wednesday|thursday|friday|saturday|sunday)$', caseSensitive: false).hasMatch(cand) &&
          cand.length >= 3) {
        return cand;
      }
    }
    return '';
  }

  double? _findAmount(String s) {
    final m = RegExp(r'(?:[¥￥\$]\s*(\d+(?:\.\d{1,2})?))|(?:(\d+(?:\.\d{1,2})?)\s*(?:元|块|dollars?|rmb|usd))', caseSensitive: false).firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m[1] ?? m[2] ?? '');
  }

  // ---------- 标题 ----------
  String _guessTitle(String t, bool en) {
    final first = t.split('\n').map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    var s = first.replaceAll(RegExp(r'^(各位|亲爱的|尊敬的)?(家长|同学)们?[:：,，]?\s*(您好|你好|大家好)?[!！,，:：]?\s*'), '');
    s = s.replaceAll(RegExp(r'^(dear |hi |hello )?(parents?( and guardians| and families)?|families|families and caregivers|\w+ families)[,:!]?\s*', caseSensitive: false), '');
    if (en) {
      final ev = _eventPhraseEn(t);
      if (ev.isNotEmpty) return ev;
    }
    if (s.length > 28) {
      final ev = _eventWordRe.firstMatch(s);
      s = ev != null ? (en ? _cap(ev[0]!) : '${ev[0]}通知') : s.substring(0, 28);
    }
    return s.isEmpty ? (en ? 'School notice' : '学校通知') : s;
  }

  String _eventTitle(String s, String? hint, bool en) {
    if (en) {
      final p = _eventPhraseEn(s);
      if (p.isNotEmpty) return p;
      if (hint != null && hint.trim().isNotEmpty) return hint.trim();
      final c = s.replaceAll(RegExp(r'\b(on|at|from)\b.*$', caseSensitive: false), '').trim();
      return c.length > 40 ? '${c.substring(0, 40)}…' : (c.isEmpty ? 'School event' : c);
    }
    final ev = _eventWordRe.firstMatch(s);
    if (ev != null) {
      final w = ev[0]!;
      // 修饰词只往前取到动词/介词为止:"将于8日开展视力筛查" → "视力筛查"
      final m = RegExp('((?:(?!日|号|于|在|将|的|把|开展|举行|举办|召开|组织|进行|定于|安排|参加|观看)[\\u4e00-\\u9fa5]){0,6})${RegExp.escape(w)}').firstMatch(s);
      return (m?[0] ?? w).trim();
    }
    if (hint != null && hint.trim().isNotEmpty) return hint.trim();
    final c = s.replaceAll(RegExp(r'[\d]{1,4}\s*[年月日号:：点时分/.-]+\s*'), '').trim();
    return c.length > 20 ? c.substring(0, 20) : (c.isEmpty ? '学校活动' : c);
  }

  /// 英文:围绕活动关键词取一个短语,"4th grade field trip to the Exploratorium"。
  String _eventPhraseEn(String s) {
    final ev = _eventWordRe.firstMatch(s);
    if (ev == null) return '';
    final w = ev[0]!;
    // 大小写敏感:后缀只收专有名词("to the Exploratorium"),不然 "is on Friday" 也会被吞进来
    final re = RegExp(
        '((?:(?:\\d+(?:st|nd|rd|th)|[A-Za-z][\\w\'-]*)\\s){0,4})${RegExp.escape(w)}'
        '((?:\\s(?:to|at|of|for)\\s(?:the\\s)?[A-Z][\\w\'-]*(?:\\s[A-Z][\\w\'-]*){0,3})?)');
    final m = re.firstMatch(s);
    var phrase = (m?[0] ?? w).trim();
    phrase = phrase.replaceAll(RegExp(r'^(our|the|a|an)\s+', caseSensitive: false), '');
    return _cap(phrase);
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _actionTitle(ItemType t, String s, String? hint, bool en) {
    final h = (hint ?? '').trim();
    switch (t) {
      case ItemType.sign:
        if (en) {
          final m = RegExp(r'(permission (slip|form)|consent form|waiver|field trip form|emergency card|[\w-]+ form)', caseSensitive: false).firstMatch(s);
          return 'Sign: ${m != null ? m[0]!.toLowerCase() : (h.isNotEmpty ? h : 'form')}';
        }
        final m = RegExp(r'([一-龥]{2,10})(回执|确认单|同意书|知情书|签字)').firstMatch(s);
        return m != null ? '签字:${m[0]}' : (h.isNotEmpty ? '签字:$h' : '签字回执');
      case ItemType.pay:
        if (en) {
          final m = RegExp(r'((?:field trip|lunch|book|yearbook|uniform|registration|activity|lab|art|pe|club|materials?)\s+fee|donation|yearbook|lunch money|t-shirt|order)', caseSensitive: false).firstMatch(s);
          return 'Pay: ${m != null ? m[0]!.toLowerCase() : (h.isNotEmpty ? h : 'fee')}';
        }
        final m = RegExp(r'(报名费|餐费|书本费|校服费|班费|活动费|保险费|材料费|费用)').firstMatch(s);
        return m != null ? '缴费:${m[0]}' : (h.isNotEmpty ? '缴费:$h' : '缴费');
      case ItemType.bring:
        if (en) {
          final m = RegExp(r'(?:bring|wear|pack|send in|dress (?:in|up as|as))\s+(?:a |an |the |their |your )?([^,.;\n]{2,40})', caseSensitive: false).firstMatch(s);
          return 'Bring: ${m != null ? m[1]!.trim() : 'items'}';
        }
        final m = RegExp(r'(?:自备|携带|带好|带上|准备好|带|穿)\s*[:：]?\s*([^,，。;；\n]{1,20})').firstMatch(s);
        return m != null ? '带:${m[1]!.trim()}' : '要带的东西';
      case ItemType.deadline:
        if (en) {
          final m = RegExp(r'(rsvp|register|sign up|order|submit|return|reply|volunteer)', caseSensitive: false).firstMatch(s);
          return 'Due: ${m != null ? _cap(m[0]!.toLowerCase()) : (h.isNotEmpty ? h : 'deadline')}';
        }
        final m = RegExp(r'(报名|提交|上交|回复|填写|登记|注册|预约)').firstMatch(s);
        return m != null ? '截止:${m[0]}' : (h.isNotEmpty ? '截止:$h' : '截止事项');
      case ItemType.event:
        return _eventTitle(s, hint, en);
    }
  }

  double _conf(double dateConf, String s, {bool action = false}) {
    var c = dateConf;
    if (_eventWordRe.hasMatch(s)) c += 0.05;
    if (action && _deadlineRe.hasMatch(s)) c += 0.05;
    return c.clamp(0.0, 0.98);
  }

  List<String> _summary(List<ExtractedItem> items, bool reschedule, bool en) {
    final out = <String>[];
    if (reschedule) out.add(en ? '⚠ Mentions a reschedule/cancellation — check the old event' : '⚠ 这条通知含有改期/取消字样,请核对旧日程');
    final ev = items.where((e) => e.type == ItemType.event).length;
    final act = items.length - ev;
    if (ev > 0) out.add(en ? '$ev event${ev > 1 ? 's' : ''} found' : '识别到 $ev 个日程');
    if (act > 0) out.add(en ? '$act parent to-do${act > 1 ? 's' : ''} found' : '识别到 $act 项要家长办的事');
    if (items.isEmpty) out.add(en ? 'No dates found — add items by hand' : '没有识别到日期,可手动添加');
    return out;
  }
}
