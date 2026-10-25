// 界面文案:每条同给 zh / en。加文案只改这里。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cloud/account.dart';
import '../core/money.dart';
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
  String get currencySwitch => t('切换货币', 'Switch currency');
  String currencyName(String? c) => switch (c ?? defaultCurrency) {
        'USD' => t('美元', 'US dollars'),
        'CNY' => t('人民币', 'Chinese yuan'),
        final code => code,
      };
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
  String get privacy => t('默认数据只存在你的设备里,不上传;开启「家庭同步」后存到 Google Firebase,只有你的家人能看到。', 'By default your data stays on this device and nothing is uploaded; with Family sync on, it is stored in Google Firebase and only your family can see it.');
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
  String get welcomeJoin => t('我有家人的邀请', 'I was invited by family');

  // 家庭同步(Firebase):爸爸妈妈用各自的账号看到、修改同一份数据,权限相同
  String get famTitle => t('家庭同步', 'Family sync');
  String get famCardSub => t('爸爸妈妈各用自己的账号,看到、修改同一份数据', 'Each parent signs in and sees and edits the same data');
  String get famCardSubOn => t('已开启 · 和家人实时同步', 'On · syncing with your family');
  String get famNotConfigured => t('家庭同步还没开通(开发者还没接上云端服务)。现在的数据只存在这台设备上。', 'Family sync isn’t switched on yet (the cloud service hasn’t been connected). Your data stays on this device.');
  String get famIntro => t(
      '开启后,孩子、通知、日程、待办、成绩、学习记录和照片会存到 Google Firebase,只有你邀请进家庭的人能看到;家庭成员权限完全相同,谁邀请谁都一样。不开启就和现在一样,数据只在这台设备上。Claude API key、提醒设置、界面语言每台设备各自保留,不同步。',
      'When on, children, notices, events, to-dos, grades, study logs and photos are stored in Google Firebase and only people you invite into your family can see them. Every family member has the same rights, no matter who invited whom. When off, everything stays on this device as before. Your Claude API key, reminder settings and language stay per device.');
  String get famEmail => t('邮箱', 'Email');
  String get famPassword => t('密码(至少 6 位)', 'Password (6+ characters)');
  String get famSignIn => t('登录', 'Sign in');
  String get famSignUp => t('注册', 'Create account');
  String get famForgot => t('忘记密码', 'Forgot password');
  String get famResetSent => t('重设密码的邮件已发出,去邮箱看看', 'Password reset email sent — check your inbox');
  String get famVerifyTitle => t('验证你的邮箱', 'Verify your email');
  String famVerifyBody(String e) => t('验证邮件已发到 $e。点邮件里的链接,再回来点「我已验证」。没收到的话看看垃圾邮件。', 'We sent a verification email to $e. Tap the link in it, then come back and tap “I’ve verified”. Check spam if you don’t see it.');
  String get famIVerified => t('我已验证', 'I’ve verified');
  String get famResend => t('重发验证邮件', 'Resend email');
  String get famVerifySent => t('已重发', 'Sent again');
  String get famNotVerifiedYet => t('还没验证成功,点邮件里的链接后再试', 'Not verified yet — tap the link in the email, then try again');
  String famSignedInAs(String e) => t('已登录:$e', 'Signed in as $e');
  String get famNoFamily => t('还没有加入家庭', 'Not in a family yet');
  String get famCreate => t('创建我的家庭', 'Create my family');
  String get famCreateDesc => t('这台设备上现有的数据会成为家庭的第一份数据,然后你可以用邮箱邀请家人。', 'The data on this device becomes your family’s data. Then invite family members by email.');
  String get famInvites => t('收到的邀请', 'Invitations');
  String famInviteFrom(String who) => t('$who 邀请你加入家庭', '$who invited you to their family');
  String get famJoin => t('加入', 'Join');
  String get famRefresh => t('刷新', 'Refresh');
  String get famNoInvites => t('还没收到邀请。让家人在他的学校通里用你这个邮箱邀请你,然后点刷新。', 'No invitations yet. Ask your family member to invite this email from their SchoolSift, then tap Refresh.');
  String get famLocalTitle => t('这台设备上已经有数据', 'This device already has data');
  String get famLocalBody => t('合并:这台设备上的孩子、通知、待办等也并进家庭,两边都保留。\n只用家庭的:这台设备上的数据换成家庭的(这台设备原来的会被替换)。', 'Merge: children, notices, to-dos on this device are added to the family; both are kept.\nUse family data: this device switches to the family’s data (what’s here now is replaced).');
  String get famMerge => t('合并进家庭', 'Merge');
  String get famUseFamily => t('只用家庭的', 'Use family data');
  String get famMembers => t('家庭成员(权限相同)', 'Family members (equal rights)');
  String get famMe => t('我', 'me');
  String get famPending => t('等待接受的邀请', 'Pending invitations');
  String get famInviteHint => t('家人的邮箱', 'Family member’s email');
  String get famInviteBtn => t('邀请', 'Invite');
  String get famBadEmail => t('邮箱格式不对', 'That email doesn’t look right');
  String get famAlreadyIn => t('这个邮箱已经在家庭里或已邀请过', 'That email is already in the family or invited');
  String famInvitedTitle(String e) => t('已邀请 $e', 'Invited $e');
  String get famInvitedBody => t('对方用这个邮箱注册并验证后,在「更多 → 家庭同步」里就能看到邀请。现在把邀请发给他:', 'Once they sign up with this email and verify it, they’ll see the invitation under More → Family sync. Send them the invitation now:');
  String get famSendEmail => t('用邮件发送', 'Send by email');
  String get famShareInvite => t('分享 / 复制', 'Share / copy');
  String get famInviteSubject => t('邀请你一起用「学校通」管理孩子的学校事务', 'Join our family on SchoolSift');
  String famInviteMessage(String e) => t(
      '我在用「学校通」管理孩子的学校通知、日程和待办,邀请你加入我们家的共享账号,我们俩看到、修改的是同一份数据:\n1. 打开 https://firedragonai.github.io/school-sift/ (Android 版:https://github.com/FiredragonAI/school-sift/releases)\n2. 更多 → 家庭同步,用 $e 注册并验证邮箱\n3. 点「加入」',
      'I’m using SchoolSift to keep track of the kids’ school notices, events and to-dos. Join our family so we both see and edit the same data:\n1. Open https://firedragonai.github.io/school-sift/ (Android: https://github.com/FiredragonAI/school-sift/releases)\n2. More → Family sync, sign up with $e and verify the email\n3. Tap “Join”');
  String get famCancelInvite => t('撤回邀请', 'Cancel invitation');
  String get famLeave => t('退出家庭', 'Leave family');
  String get famLeaveConfirm => t('退出后这台设备留一份现在的数据,之后不再同步;家庭里的其他人不受影响。确定?', 'This device keeps a copy of the current data but stops syncing; others in the family are not affected. Leave?');
  String get famSignOut => t('退出登录', 'Sign out');
  String get famSignOutConfirm => t('退出登录后这台设备留一份现在的数据,之后不再同步。再登录就能接着同步。确定?', 'This device keeps a copy of the current data but stops syncing until you sign in again. Sign out?');
  String get famDelete => t('删除账号', 'Delete account');
  String get famDeleteBody => t(
      '会永久删除你的登录账号。你是家庭里唯一的成员时,云端的家庭数据(孩子、通知、日程、照片……)会一起删除;还有其他成员时,数据留给他们,只把你移出。这台设备上的数据不受影响。\n\n输入密码确认:',
      'This permanently deletes your account. If you are the only member of your family, the family’s cloud data (children, notices, events, photos…) is deleted too; if others remain, the data stays with them and only you are removed. Data on this device is not affected.\n\nEnter your password to confirm:');
  String get famDeleteBtn => t('永久删除', 'Delete permanently');
  String get famDeleted => t('账号已删除', 'Account deleted');
  String get famSynced => t('已同步', 'Synced');
  String get famPendingWrites => t('正在上传…', 'Uploading…');
  String get famOffline => t('离线 · 恢复网络后自动同步', 'Offline · will sync when you’re back online');
  String get famConnecting => t('正在连接…', 'Connecting…');
  String get famError => t('同步出错', 'Sync error');
  String get famSyncedLocked => t('已开启家庭同步:要载入演示数据或清空数据,请先在「家庭同步」里退出家庭(否则会改到全家的数据)。', 'Family sync is on: to load demo data or clear everything, leave the family first (otherwise it changes everyone’s data).');
  String get famRestoreWarn => t('已开启家庭同步:恢复备份会覆盖全家共享的数据。确定?', 'Family sync is on: restoring a backup overwrites your whole family’s data. Continue?');
  String famAccountError(AccountError e) => switch (e) {
        AccountError.emailInUse => t('这个邮箱已经注册过,直接登录', 'This email already has an account — sign in instead'),
        AccountError.invalidEmail => t('邮箱格式不对', 'That email doesn’t look right'),
        AccountError.weakPassword => t('密码太简单,至少 6 位', 'Password too weak — use 6+ characters'),
        AccountError.wrongCredentials => t('邮箱或密码不对', 'Wrong email or password'),
        AccountError.tooManyRequests => t('尝试次数太多,过一会儿再试', 'Too many attempts — try again later'),
        AccountError.network => t('网络连不上', 'Can’t reach the network'),
        AccountError.unknown => t('出错了,请再试一次', 'Something went wrong — please try again'),
      };

  // 通知录入:附件 / OCR / AI
  String get attachments => t('附件', 'Attachments');
  String get pickFile => t('选文件(截图/PDF)', 'File (screenshot / PDF)');
  String get ocrRun => t('识别图片文字(本机)', 'Read text from images (on device)');
  String get ocrRunning => t('正在识别文字…', 'Reading text…');
  String get ocrDone => t('识别出的文字已填入,请核对后再识别日程', 'Text filled in — check it, then extract');
  String get ocrFailed => t('文字识别失败', 'Text recognition failed');
  String get ocrEmpty => t('没识别出文字,可以手动输入或用 AI', 'No text found — type it or use AI');
  String get aiExtract => t('用 AI 识别日程与待办', 'Extract with AI');
  String get rulesExtract => t('离线识别日程与待办', 'Extract offline');
  String get useRulesInstead => t('改用离线规则', 'Use offline rules instead');
  String get useAiInstead => t('改用 AI 识别', 'Use AI instead');
  String get aiRunning => t('正在请求 Claude…', 'Asking Claude…');
  String get aiFailed => t('AI 识别失败', 'AI extraction failed');
  String get aiNoKey => t('还没设置 Claude API key。去「更多 → 设置」填一个,或先用离线识别。', 'No Claude API key yet. Add one under More → Settings, or extract offline.');
  String get aiConsentTitle => t('把这条通知发给 Claude?', 'Send this notice to Claude?');
  String get aiConsentBody => t(
      '只会发送这一条通知的文字和附图,用你自己的 API key 直接发给 Anthropic(api.anthropic.com),不经过任何其他服务器。孩子姓名、其他通知、成绩等都不会发送。\n\n不想上传时随时可以用离线识别。',
      'Only this notice’s text and attached images are sent, directly to Anthropic (api.anthropic.com) with your own API key — no other server in between. Children’s names, other notices and grades are never sent.\n\nYou can always use offline extraction instead.');
  String get aiConsentOk => t('发送并识别', 'Send & extract');
  String get aiConsentRemember => t('以后不再提示', 'Don’t ask again');
  String get extractorAi => t('AI 识别', 'AI');
  String get extractorRules => t('离线规则', 'Offline rules');
  String get page => t('页', 'p.');
  String get noContent => t('先粘贴文字或添加附件', 'Paste text or add an attachment first');
  String get sourceFile => t('文件', 'File');

  // 设置
  String get settings => t('设置', 'Settings');
  String get aiSection => t('AI 识别(可选)', 'AI extraction (optional)');
  String get apiKey => t('Claude API key', 'Claude API key');
  String get apiKeyNote => t('只保存在这台设备上,不会随备份导出。有 key 时拍照/PDF/文字都由 Claude 理解;没有就用本机 OCR + 规则。', 'Stored only on this device, never included in backups. With a key, photos/PDFs/text are understood by Claude; without one, on-device OCR + rules.');
  String get model => t('模型', 'Model');
  String get testKey => t('测试连接', 'Test connection');
  String get testOk => t('连接成功', 'Connected');
  String get ocrSection => t('图片文字识别(本机)', 'On-device text recognition');
  String get ocrLang => t('OCR 语言', 'OCR language');
  String get ocrAuto => t('跟随界面语言', 'Follow app language');
  String get ocrEng => t('英文', 'English');
  String get ocrChi => t('中文 + 英文', 'Chinese + English');
  String get ocrNoteWeb => t('网页版用 Tesseract.js 在浏览器里识别,首次使用会下载语言包(英文约 4 MB,中文约 20 MB),图片不上传。', 'The web version runs Tesseract.js in your browser; the first run downloads a language pack (English ≈4 MB, Chinese ≈20 MB). Images never leave the device.');
  String get ocrNoteAndroid => t('Android 版用 Google ML Kit 端侧模型,离线可用。', 'Android uses Google ML Kit on-device models; works offline.');
  String get remindersSection => t('提醒', 'Reminders');
  String get remindersOn => t('截止与日程提醒', 'Deadline & event reminders');
  String get remindersDesc => t('截止前一天 19:00、当天 8:00;逾期每天再催;日程前一天与前 1 小时', 'Day before at 19:00, due day at 8:00, daily while overdue; events the day before and 1 h ahead');
  String get briefOn => t('每日简报', 'Daily brief');
  String get briefTime => t('简报时间', 'Brief time');
  String get testNotify => t('发一条测试通知', 'Send a test notification');
  String get remindersWebNote => t('网页版只能在页面开着时提醒;要后台提醒请装 Android 版。', 'The web version can only remind you while the page is open; install the Android app for background reminders.');
  String get permissionDenied => t('通知权限没开,系统设置里打开后才会响', 'Notification permission is off — enable it in system settings');
  String get testSent => t('已发送', 'Sent');

  // 协作(F05:对方不用装 App)
  String get shareFamily => t('发给家人', 'Send to family');
  String get shareBrief => t('分享简报', 'Share brief');
  String get copiedShare => t('已复制,粘贴到微信 / 短信发出去', 'Copied — paste into WhatsApp / SMS');
  String get briefEmpty => t('今明两天没有安排', 'Nothing today or tomorrow');

  // 用英文回复(ai-keyboard-research 报告 4.3:中文意思 → 得体英文 + 中文回译)
  String get replyInEnglish => t('用英文回复', 'Reply in English');
  String get replyWrite => t('用英文写信', 'Write in English');
  String get replyWriteDesc => t('中文写要点,生成得体的英文邮件或短信,附中文回译', 'Jot your points in Chinese; get a polished English email or text, with a Chinese back-translation');
  String get replyContext => t('回复', 'Replying to');
  String get replyContextNote => t('通知原文会一起发给 AI 做参考', 'The notice text is sent along as context');
  String get replyContextNoText => t('这条通知只有图片,AI 看不到原文,要点里写清楚就好。', 'This notice has images only, so the AI won’t see it — make your points self-contained.');
  String get replyTo => t('写给谁', 'To');
  String get replyToneLabel => t('语气', 'Tone');
  String get replyFormatLabel => t('形式', 'Format');
  String recipientName(ReplyRecipient r) => switch (r) {
        ReplyRecipient.teacher => t('老师', 'Teacher'),
        ReplyRecipient.office => t('学校办公室', 'School office'),
        ReplyRecipient.nurse => t('校医', 'School nurse'),
        ReplyRecipient.coach => t('教练', 'Coach'),
        ReplyRecipient.parent => t('其他家长', 'Another parent'),
      };
  String toneName(ReplyTone x) => switch (x) {
        ReplyTone.polite => t('礼貌', 'Polite'),
        ReplyTone.firm => t('坚定', 'Firm'),
        ReplyTone.apology => t('道歉', 'Apologetic'),
        ReplyTone.followUp => t('催办', 'Follow-up'),
        ReplyTone.thanks => t('感谢', 'Thank-you'),
      };
  String formatName(ReplyFormat f) => f == ReplyFormat.email ? t('邮件', 'Email') : t('短信', 'Text message');
  String get replyRestrained => t('克制模式', 'Light-touch mode');
  String get replyRestrainedDesc => t('我自己写英文,只纠错,不重写', 'I write the English myself — fix mistakes only, no rewriting');
  String get replyPoints => t('用中文写要点', 'Your points (Chinese is fine)');
  String get replyPointsHint => t('例如:小雨下周三上午要看牙医,10 点接走,11 点半送回学校。问一下要不要先去办公室签字。', 'e.g. Mia has a dentist appointment next Wednesday; I’ll pick her up at 10 and bring her back by 11:30. Do I need to sign her out at the office?');
  String get replyDraft => t('你写的英文', 'Your English draft');
  String get replyDraftHint => t('例如:Hi Ms. Garcia, Mia will absent tomorrow because she have a fever.', 'e.g. Hi Ms. Garcia, Mia will absent tomorrow because she have a fever.');
  String get replySignature => t('署名(可选)', 'Sign-off name (optional)');
  String get replySignatureHint => t('例如 Lin Wang (Mia’s mom)', 'e.g. Lin Wang (Mia’s mom)');
  String get replySignatureNote => t('只在本机填进 [Your name],不发给 AI', 'Filled into [Your name] on this device — never sent to the AI');
  String get replyGenerate => t('生成英文', 'Write it in English');
  String get replyFix => t('只纠错', 'Fix mistakes only');
  String get replyRunning => t('正在请 Claude 写…', 'Asking Claude…');
  String get replyFailed => t('生成失败', 'Couldn’t write it');
  String get replyEmpty => t('先写几句要点', 'Write a few points first');
  String get replySubject => t('主题', 'Subject');
  String get replyBack => t('中文回译 · 核对意思有没有被改', 'Chinese back-translation · check nothing changed');
  String get replyChanges => t('改了哪些地方', 'What was corrected');
  String get replyNoChanges => t('没发现要改的地方', 'No mistakes found');
  String get replyNotes => t('发送前留意', 'Before you send');
  String replyFillIn(String list) => t('发送前把方括号换成真实信息:$list', 'Replace the bracketed parts before sending: $list');
  String get copy => t('复制', 'Copy');
  String get copySubject => t('复制主题', 'Copy subject');
  String get share => t('分享', 'Share');
  String get replyHistory => t('回信记录', 'Reply history');
  String get replyHistoryEmpty => t('还没有写过英文回信', 'No replies yet');

  // 回信反馈卡(第 3 封后出现一次;不点发送就什么都不发)
  String get fbTitle => t('「用英文回复」对你有用吗?', 'Is “Reply in English” useful to you?');
  String get fbBody => t('你已经写了 3 封以上。花 10 秒告诉我们感受,帮我们决定下一步做什么。', 'You’ve written 3+ replies. Ten seconds of feedback helps us decide what to build next.');
  String get fbUseful => t('有用', 'Useful');
  String get fbOkay => t('一般', 'It’s OK');
  String get fbNotUseful => t('没用', 'Not useful');
  String get fbKeyboard => t('想要能在任何 App(微信、邮件、WhatsApp)里直接用的中英键盘', 'I’d like a Chinese→English keyboard that works in any app (email, WhatsApp…)');
  String get fbComment => t('想说的话(可选)', 'Anything else? (optional)');
  String get fbSendForm => t('打开反馈表单', 'Open feedback form');
  String get fbCopy => t('复制反馈', 'Copy feedback');
  String get fbDismiss => t('不了,谢谢', 'No thanks');
  String get fbPrivacy => t('不点按钮就什么都不会发送。表单里只预填你上面选的三项和回信条数;留言和联系方式由你在表单里自己填。', 'Nothing is sent unless you tap. The form is pre-filled only with your choices above and your reply count; any comment or contact you add yourself in the form.');
  String get fbPrivacyCopy => t('不点按钮就什么都不会发送。「复制反馈」只是把上面的内容放进剪贴板,由你自己决定贴到哪里。', 'Nothing is sent unless you tap. “Copy feedback” only puts the text on your clipboard — you decide where to paste it.');
  String get fbCopied => t('已复制,贴到家长群或发给推荐你用学校通的人就好', 'Copied — paste it into your parents’ group or send it to whoever told you about SchoolSift');
  String get fbCommentCopied => t('你的留言已复制,可以在表单里粘贴', 'Your comment is copied — paste it into the form');
  String get fbThanks => t('谢谢你的反馈!', 'Thanks for the feedback!');
  String get fbPickRating => t('先选一下有用 / 一般 / 没用', 'Pick Useful / OK / Not useful first');
  String get fbHeader => t('学校通「用英文回复」反馈', 'SchoolSift “Reply in English” feedback');
  String get fbCountLabel => t('已写回信', 'Replies written');
  String get fbWantsKeyboard => t('想要中英键盘:是', 'Wants keyboard: yes');
  String get fbNoKeyboard => t('想要中英键盘:否', 'Wants keyboard: no');
  String get fbMenu => t('反馈', 'Feedback');
  String fbRatingLine(String r) => t('评价:$r', 'Rating: $r');
  String get replyNoKeyTitle => t('需要 Claude API key', 'Needs a Claude API key');
  String get replyNoKeyBody => t('这个功能用你自己的 key 调 Claude(每封约 \$0.01–0.03)。在设置里填一个就能用。', 'This uses Claude with your own key (about \$0.01–0.03 per message). Add one in Settings.');
  String get goSettings => t('去设置', 'Settings');
  String get replyConsentTitle => t('把要点发给 Claude?', 'Send your points to Claude?');
  String get replyConsentBody => t(
      '会发送你写的要点(克制模式下是你写的英文)和选的对象、语气;从通知进入时,还会带上这条通知的文字。用你自己的 API key 直接发给 Anthropic(api.anthropic.com),不经过任何其他服务器。\n\n署名只在本机填入,不会发送;孩子资料、成绩、其他通知也不会发送。要点里写了谁的名字,这个名字会被发送。',
      'What you wrote (your English draft in light-touch mode) and the recipient and tone you picked are sent — plus the notice’s text when you reply to one — directly to Anthropic (api.anthropic.com) with your own API key, with no other server in between.\n\nYour sign-off name is filled in on this device and never sent, nor are children’s profiles, grades or other notices. Any name you type into your points is sent.');
  String get replyConsentOk => t('发送并生成', 'Send & write');

  // 学习 / 导出
  String get teacherNote => t('老师反馈', 'Teacher feedback');
  String get teacherNoteHint => t('联系册、App 或口头反馈,抄一句', 'From the planner, app or in person');
  String get csvExport => t('导出 CSV(Excel 可开)', 'Export CSV');
  String get csvGrades => t('成绩', 'Grades');
  String get csvLogs => t('学习记录', 'Study logs');
  String get csvEvents => t('日程', 'Events');
  String get csvTasks => t('待办', 'Tasks');

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
