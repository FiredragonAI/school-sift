// 界面文案:每条同给 zh / en。加文案只改这里。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../store/app_state.dart';

class S {
  final String lang;
  const S(this.lang);
  static S of(BuildContext c) => S(c.watch<AppState>().language);
  static S read(BuildContext c) => S(c.read<AppState>().language);
  bool get zh => lang == 'zh';
  String t(String zhText, String enText) => zh ? zhText : enText;

  // 导航
  String get appName => t('学校通', 'SchoolSift');
  String get tabToday => t('今日', 'Today');
  String get tabInbox => t('通知', 'Notices');
  String get tabCalendar => t('日程', 'Calendar');
  String get tabGrowth => t('成长', 'Growth');
  String get tabMore => t('更多', 'More');

  // 通用
  String get allChildren => t('全部孩子', 'All kids');
  String get family => t('全家', 'Family');
  String get save => t('保存', 'Save');
  String get cancel => t('取消', 'Cancel');
  String get delete => t('删除', 'Delete');
  String get edit => t('编辑', 'Edit');
  String get done => t('完成', 'Done');
  String get confirm => t('确认', 'Confirm');
  String get add => t('添加', 'Add');
  String get none => t('暂无', 'None');
  String get unassigned => t('未指派', 'Unassigned');
  String get assignTo => t('谁去办', 'Assign to');
  String get child => t('孩子', 'Child');
  String get title => t('标题', 'Title');
  String get date => t('日期', 'Date');
  String get time => t('时间', 'Time');
  String get endTime => t('结束', 'End');
  String get location => t('地点', 'Location');
  String get note => t('备注', 'Note');
  String get amount => t('金额', 'Amount');
  String get dueDate => t('截止', 'Due');
  String get noDue => t('无截止', 'No due date');
  String get overdue => t('已逾期', 'Overdue');
  String get today => t('今天', 'Today');
  String get tomorrow => t('明天', 'Tomorrow');
  String get thisWeek => t('本周', 'This week');
  String get later => t('之后', 'Later');
  String get search => t('搜索通知原文…', 'Search notices…');
  String get required => t('必填', 'Required');

  // 今日
  String greeting(int hour) => zh
      ? (hour < 11 ? '早上好' : hour < 14 ? '中午好' : hour < 18 ? '下午好' : '晚上好')
      : (hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening');
  String get briefTitle => t('今天和明天', 'Today & tomorrow');
  String get nothingScheduled => t('没有安排,好好休息', 'Nothing scheduled');
  String get needsYou => t('要家长办的事', 'Needs a parent');
  String get allClear => t('都办完了 ✓', 'All clear ✓');
  String get unprocessed => t('待确认的通知', 'Notices to review');
  String get quickActions => t('快捷', 'Quick');
  String get qaPaste => t('粘贴通知', 'Paste notice');
  String get qaPhoto => t('拍纸质通知', 'Photo notice');
  String get qaGrade => t('记成绩', 'Add grade');
  String get qaLog => t('今日学习', 'Study log');
  String get rescheduledTag => t('已改期', 'Rescheduled');
  String get overdueCount => t('逾期', 'overdue');

  // 通知
  String get inboxEmpty => t('还没有通知。把学校发的文字粘贴进来,或拍一张纸质通知。', 'No notices yet. Paste a school message or snap a paper notice.');
  String get newNotice => t('新通知', 'New notice');
  String get noticeBody => t('通知原文', 'Notice text');
  String get noticeHint => t('把老师发的文字粘贴到这里…', 'Paste the message from the teacher here…');
  String get attachPhoto => t('附照片', 'Attach photo');
  String get takePhoto => t('拍照', 'Camera');
  String get pickPhoto => t('相册', 'Gallery');
  String get extract => t('识别日程与待办', 'Extract events & tasks');
  String get extractTitle => t('识别结果 · 请核对', 'Review extraction');
  String get extractEmpty => t('没识别到日期。可以手动加一条,或直接保存原文。', 'No dates found. Add one by hand or just save the text.');
  String get confidence => t('把握', 'confidence');
  String get rescheduleWarn => t('这条通知里有"改期/取消"字样,确认后会更新同名的旧日程。', 'This notice mentions a reschedule/cancellation; confirming will update the matching old event.');
  String get commit => t('写入日程与待办', 'Add to calendar & tasks');
  String get saveRaw => t('只存原文', 'Text only');
  String get processed => t('已处理', 'Processed');
  String get pending => t('待确认', 'To review');
  String get reExtract => t('重新识别', 'Extract again');
  String get original => t('原文', 'Original');
  String get addItem => t('手动加一条', 'Add item');
  String get source => t('来源', 'Source');
  String get sourcePaste => t('粘贴', 'Pasted');
  String get sourcePhoto => t('拍照', 'Photo');
  String get sourceDemo => t('演示', 'Demo');
  String get ocrNote => t('照片里的文字请先手动抄录(云端识别稍后上线)', 'Type the text from the photo for now (cloud OCR coming)');

  // 类型
  String kind(TaskKind k) {
    switch (k) {
      case TaskKind.sign:
        return t('签字', 'Sign');
      case TaskKind.pay:
        return t('缴费', 'Pay');
      case TaskKind.bring:
        return t('带东西', 'Bring');
      case TaskKind.other:
        return t('其他', 'Other');
    }
  }

  String status(TaskStatus s) {
    switch (s) {
      case TaskStatus.open:
        return t('待办', 'Open');
      case TaskStatus.done:
        return t('已完成', 'Done');
      case TaskStatus.submitted:
        return t('已交回', 'Returned');
    }
  }

  String get event => t('日程', 'Event');
  String get markDone => t('标记完成', 'Mark done');
  String get markSigned => t('已签字', 'Signed');
  String get markSubmitted => t('已交回学校', 'Returned to school');
  String get reopen => t('重新打开', 'Reopen');

  // 日程
  String get calendarEmpty => t('这天没有安排', 'Nothing on this day');
  String get upcoming => t('接下来', 'Upcoming');
  String get exportIcs => t('导出 .ics 到日历', 'Export .ics');
  String get addToGoogle => t('加到 Google 日历', 'Add to Google Calendar');
  String get viewCalendar => t('日历', 'Calendar');
  String get viewTasks => t('待办', 'Tasks');
  String get newEvent => t('新日程', 'New event');
  String get newTask => t('新待办', 'New task');
  String get fromNotice => t('来自通知', 'From notice');
  String get kindLabel => t('类型', 'Type');

  // 成长
  String get grades => t('成绩', 'Grades');
  String get studyLog => t('学习记录', 'Study log');
  String get papers => t('签字袋', 'Paper trail');
  String get subject => t('科目', 'Subject');
  String get testName => t('测验名称', 'Test');
  String get score => t('得分', 'Score');
  String get fullScore => t('满分', 'Full');
  String get classAvg => t('班均', 'Class avg');
  String get trend => t('趋势', 'Trend');
  String get noGrades => t('还没有成绩记录,点右下角添加。', 'No grades yet. Tap + to add.');
  String get recent => t('最近', 'Recent');
  String get avg => t('平均', 'Avg');
  String get best => t('最高', 'Best');
  String get homeworkDone => t('作业完成', 'Homework done');
  String get readingMin => t('阅读分钟', 'Reading min');
  String get focus => t('专注度', 'Focus');
  String get streak => t('连续记录', 'Streak');
  String get days => t('天', 'days');
  String get logNote => t('今天怎么样?一句话', 'How was today? One line');
  String get last14 => t('近 14 天', 'Last 14 days');
  String get papersEmpty => t('没有要签字的单子。拍一张纸质回执就能记下来。', 'No forms to sign. Snap a paper slip to track it.');
  String get pleaseAddChild => t('先添加一个孩子', 'Add a child first');
  String get selectChild => t('选择孩子', 'Select child');

  // 更多
  String get children => t('孩子管理', 'Children');
  String get members => t('家庭成员', 'Family members');
  String get language => t('语言', 'Language');
  String get backup => t('备份与恢复', 'Backup & restore');
  String get exportJson => t('导出 JSON 备份', 'Export JSON backup');
  String get importJson => t('粘贴 JSON 恢复', 'Restore from JSON');
  String get loadDemo => t('载入演示数据', 'Load demo data');
  String get clearAll => t('清空全部数据', 'Clear all data');
  String get clearConfirm => t('会删除本机全部数据,不可恢复。确定?', 'This deletes all local data. Continue?');
  String get about => t('关于', 'About');
  String get privacy => t('数据只存在你的设备里,不上传。', 'Data stays on your device. Nothing is uploaded.');
  String get name => t('姓名', 'Name');
  String get school => t('学校', 'School');
  String get gradeClass => t('年级/班级', 'Grade / class');
  String get color => t('颜色', 'Color');
  String get memberHint => t('例如:妈妈、爸爸、奶奶', 'e.g. Mom, Dad, Grandma');
  String get copied => t('已复制到剪贴板', 'Copied to clipboard');
  String get imported => t('已恢复', 'Restored');
  String get importFailed => t('JSON 格式不对', 'Invalid JSON');
  String get welcomeTitle => t('欢迎使用学校通', 'Welcome to SchoolSift');
  String get welcomeBody => t(
      '把学校通知变成家庭日程、待签字的单子、要交的钱;顺手记下测验成绩和每天的学习。\n\n先看演示数据,还是直接添加你的孩子?',
      'Turn school notices into family events, forms to sign and fees to pay; log test scores and daily study.\n\nStart with demo data, or add your child now?');
  String get startFresh => t('添加我的孩子', 'Add my child');

  // 日期格式
  String weekday(int wd) => zh ? '周${'一二三四五六日'[wd - 1]}' : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][wd - 1];
  String monthName(int m) => zh ? '$m月' : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  String md(Day d) => zh ? '${d.m}月${d.d}日' : '${monthName(d.m)} ${d.d}';
  String mdw(Day d) => '${md(d)} ${weekday(d.weekday)}';
  String ymd(Day d) => zh ? '${d.y}年${d.m}月${d.d}日' : '${monthName(d.m)} ${d.d}, ${d.y}';
  String relative(Day d) {
    final n = d.diff(Day.today());
    if (n == 0) return today;
    if (n == 1) return tomorrow;
    if (n == -1) return t('昨天', 'Yesterday');
    if (n > 1 && n < 7) return t('$n 天后', 'in $n days');
    if (n < -1 && n > -7) return t('${-n} 天前', '${-n} days ago');
    return md(d);
  }
  String tod(TimeOfDay? t) => t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String dueIn(Day d) {
    final n = d.diff(Day.today());
    if (n < 0) return t('逾期 ${-n} 天', '${-n}d overdue');
    if (n == 0) return t('今天截止', 'due today');
    if (n == 1) return t('明天截止', 'due tomorrow');
    return t('$n 天后截止', 'due in ${n}d');
  }
}
