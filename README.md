# 学校通 · SchoolSift

把学校发来的一堆通知,变成**家庭日程、要签字的单子、要交的钱**;顺手记下孩子的**测验成绩**和**每天的学习**。
一份 Flutter 代码,出 Web(GitHub Pages)和 Android。本机优先:没有账号、没有服务器。

**网页版:** https://firedragonai.github.io/school-sift/
**Android:** 见 [Releases](https://github.com/FiredragonAI/school-sift/releases)(APK 直接安装)

## 为什么做这个

来自一次对全球 App 差评的挖掘([研究报告](https://claude.ai/artifact/TpPsZdS88vZk4enQDDcYe9)):「家校通知 → 家庭日程」在 126 条痛点里机会分排第一(7.50)。每个功能对应的痛点编号见 [docs/DESIGN.md](docs/DESIGN.md)。

- **F01** "3 天收到 7 位老师的 47 条通知,只有我一个人在管。"
- **F02** ParentSquare / ClassDojo 这类学校指定的 App:通知轰炸、搜不到、图片通知不可检索、多孩无法筛选。
- **F03** 共享日历 ≠ 分担:工具不会主动催,也不追踪是否完成。
- **F04** Cozi 用了 7 年突然要收费、只能看 30 天——数据必须归用户、随时能导出。
- **F05** "另一半就是不装 App"——协作必须免安装。
- **I07** 截图 / 短信 / 邮件里的活动要手动重打进日历。

学校通不替代学校的 App,它坐在所有通知之上,只做一件事:**读懂,然后分派下去,并追踪到做完。**

## 功能

| 页签 | 做什么 | 痛点 |
|---|---|---|
| **今日** | 今天 + 明天的日程、要家长办的事(逾期置顶)、待确认的通知、四个快捷入口;右上角一键**分享今日简报**给家人 | F01 F03 F05 |
| **通知** | **粘贴文字 / 拍照 / 相册 / 截图 / PDF** → 本机 OCR(Web: Tesseract.js,Android: ML Kit)或 **用你自己的 Claude API key 让 AI 读**(文字 + 图片 + PDF)→ 自动识别**日程 / 签字回执 / 缴费 / 带东西 / 截止**,每条带把握度和来源句 → 家长核对、改、指派后一键写入;**识别"改期"并更新同名旧日程**;原文永久保留、全文可搜、按孩子筛选 | F01 F02 I07 |
| **日程** | 月历 + 当日列表 + 接下来 30 天;按孩子着色;指派给爸爸/妈妈;导出 .ics、一键加到 Google 日历(不另造日历);**发给家人** | F03 F04 F05 |
| **待办** | 签字 / 缴费 / 带东西 / 其他;按逾期 · 今天 · 本周 · 之后分组;签字类有「待签 → 已签 → 已交回」三态 | F03 |
| **提醒** | 截止前一天 19:00、当天 8:00、**逾期后每天再催**(7 天);日程前一天 + 前 1 小时;每日早间简报。Android 后台本地通知;网页版在页面打开时提醒 | F03 |
| **成长 · 成绩** | 按孩子 / 科目 / 日期记测验成绩(可填满分、班均),科目卡片 + 趋势折线 + 班均虚线 | — |
| **成长 · 学习记录** | 每日作业完成 / 阅读分钟 / 专注度 / 一句话 / **老师反馈**;连续打卡;近 14 天柱状 | — |
| **成长 · 签字袋** | 纸质回执拍照存档,追踪到交回 | F03 |
| **用英文回复** | 通知详情「用英文回复」(带上通知原文)或 更多「用英文写信」:中文写要点 → 选写给谁和语气 → 得体的英文邮件/短信 + **中文回译**;克制模式只纠错不重写;复制、分享、本机历史。写到第 3 封后出现一次可选的反馈卡 | K4.3 |
| **家庭同步**(可选) | 更多 → 家庭同步:邮箱 + 密码登录,建家庭后用邮箱邀请家人;对方注册并验证邮箱后加入。之后爸爸妈妈各用自己的账号看到、修改同一份数据(孩子、通知、日程、待办、成绩、学习记录、照片),实时同步、离线可用;**权限完全相同,谁邀请谁都一样**。可退出家庭、可在应用内删除账号 | F03 F05 |
| **更多** | 多孩子(各自颜色)、家庭成员、中 / 英文、**设置**(AI key、OCR 语言、提醒)、JSON 备份(含图片)与恢复、**四张 CSV 导出** | F04 |

## 隐私

- 所有数据只在你的设备上:Android 是应用私有目录,网页版是浏览器的 IndexedDB。没有账号、没有我们的服务器、没有统计 SDK。
- 本机 OCR 的图片不离开设备。
- **家庭同步是可选的**:不开就和以前一样纯本机;开了以后数据存进 Google Firebase,只有家庭成员能读(规则见 `firebase/firestore.rules`,有 15 个模拟器测试)。API key、提醒设置、界面语言不同步。
- 网页版启动不连任何外部域名(字体、CanvasKit 引擎都从本站加载);只有用到 OCR 时才从 jsdelivr 加载 Tesseract.js。
- 「用英文回复」的反馈卡:不点按钮什么都不发;点了才打开反馈表单(只预填评分、回信条数、要不要键盘)或复制成文字。
- **只有你主动点「用 AI 识别」时**,这一条通知的文字和附图才会用你自己的 API key 直接发给 Anthropic(api.anthropic.com),不经过任何中间服务器;第一次会弹窗说明发什么、不发什么(孩子姓名、成绩、其他通知都不发)。API key 只存在本机,不随备份导出。
- [隐私政策](docs/privacy-policy.html)

## 通知识别是怎么做的

两条路,返回同一个 `Extraction` 结构,确认页不区分来源:

1. **离线规则** `app/lib/core/notice_parser.dart` —— 纯规则、确定性、可测试
   - 日期:`2026年10月8日` / `10月8日` / `10/24/2026` / `Oct. 24` / `October 24-25` / `8 Oct` / `明天` / `下周三` / `next Monday`,无年份取最近的将来
   - 时间:`下午2:30` / `上午8点半` / `9:00 to 1:30 PM` / `6:00-7:30 PM` / `8am-2pm` / `noon`
   - 动作词(中英):签字/回执/permission slip、缴费/fee/$12/donation、自备/bring/wear、截止/by/due/RSVP
   - 改期词:改到/延期/取消/moved to/postponed/rescheduled → 写入时更新旧日程
   - 英文通知自动切句、取活动短语("4th grade field trip to the Exploratorium")、标题用英文前缀(Sign: / Pay: / Bring: / Due:)
2. **Claude**(可选)`app/lib/core/claude_extractor.dart` —— 用结构化输出(`output_config.format` = JSON Schema)直接拿到同样的结构;图片走 image block,PDF 走 document block;默认 `claude-opus-5-5`,可选 Sonnet 5.5 / Haiku 4.5;每条通知约 $0.01–0.03

测试:`app/test/notice_parser_test.dart`(中文)、`notice_parser_en_test.dart`(美国小学英文通知)、`claude_extractor_test.dart`(请求体与映射,不打网络)、`reminder_plan_test.dart`、`app_smoke_test.dart`(全流程)、`font_coverage_test.dart`(打包字体覆盖界面用到的字符)。

## 开发

```bash
cd app
flutter pub get
flutter analyze && flutter test
flutter run -d chrome
flutter build web --release
flutter build apk --release --split-per-abi   # 需要 android/key.properties,否则回退 debug 签名
```

- 存储:Hive CE(`store/app_state.dart`),图片单独一个 box;0.1 版 localStorage 数据首次启动自动迁移。
- 字体:Web 端没有系统字体,`assets/fonts/` 里是 Noto Sans SC 的子集(SIL OFL),由 `tools/fontsubset/subset.mjs` 生成(subset-font 必须锁 2.7.0),字符集 = lib/ 用到的字 + GB2312 + CJK 标点/全角 + Latin-1(José、Peña 这类人名),只留简体用到的字形和横排默认版式,每个字重约 1.8 MB;App 要用别的 OpenType feature(FontFeature)得加进脚本里的 `FEATURES` 重裁。界面文案新用了符号或生僻字要重新裁剪,`test/font_coverage_test.dart` 会拦住漏掉的字符(harfbuzz 版:`node tools/fontsubset/check.mjs`)。
- 图标:`GEN_ICON=1 flutter test test/tools/gen_icon_test.dart` 重新生成 Android / Web 全部尺寸。
- OCR:Web 端按需从 jsdelivr 加载 Tesseract.js(首次下载语言包);Android 端 ML Kit 拉丁 + 中文模型打进 APK。
- 提醒:Android 用 `flutter_local_notifications` 不精确闹钟(不需要 SCHEDULE_EXACT_ALARM);每次数据变动 3 秒后整体重排。
- 家庭同步:代码在 `app/lib/cloud/`(`cloud_session.dart` 总控、`family_sync.dart` 同步、`sync_merge.dart` 三方合并、`family_service.dart` 家庭与邀请)。正式 Firebase 项目是 `schoolsift-family`(Firestore 在 us-west2,邮箱/密码登录,授权域名含 firedragonai.github.io),配置在 `lib/cloud/firebase_options.dart`;改了规则后 `cd firebase && npx.cmd firebase deploy --only firestore:rules`(PowerShell 里用 npx.cmd)。本机联调:`firebase emulators:start --only auth,firestore --project demo-schoolsift`(要 JDK 21),Flutter 构建加 `--dart-define=FIREBASE_EMULATOR=true`。规则测试:`cd firebase && npm test`。
- 部署:推 `main` 后 `.github/workflows/pages.yml` 自动跑 analyze + test + build 并发布到 GitHub Pages。构建带 `--no-web-resources-cdn`(CanvasKit 与 Roboto 自托管,启动不连 gstatic)。
- 反馈表单:在仓库 Settings → Secrets and variables → Actions → **Variables** 里加 `FEEDBACK_FORM_URL`(如 Tally / Google 表单地址),可用占位符 `{rating}` `{count}` `{keyboard}` `{lang}` 预填;本地构建用 `--dart-define=FEEDBACK_FORM_URL=...`。不设就只有「复制反馈」。改了变量要重跑一次 Pages 工作流才生效。Windows 上 `flutter` 是 .bat,地址里的 `&` 会被 cmd 截断,本地打包要绕过 .bat 直接调 `flutter_tools.snapshot`(Git Bash 里加 `MSYS_NO_PATHCONV=1`)。

## 路线图

- [x] 拍照 / 截图 / PDF 直接识别(本机 OCR + 可选 Claude)
- [x] 本地推送提醒(Android),逾期持续催
- [x] 发给家人(免安装协作)
- [x] 家庭同步:邮箱邀请家人,权限相同,实时同步(可选,默认仍纯本机)
- [ ] 邮件转发地址 / Gmail 只读授权,自动收通知(需要 Google 安全审计,等真实用户验证后再做)
- [ ] iOS 版(同一代码,需要 Mac 或云构建)

## 许可

代码 MIT;字体 Noto Sans SC 为 SIL Open Font License 1.1(见 `app/assets/fonts/LICENSE-OFL.txt`)。
