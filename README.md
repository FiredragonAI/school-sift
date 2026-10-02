# 学校通 · SchoolSift

把学校发来的一堆通知,变成**家庭日程、要签字的单子、要交的钱**;顺手记下孩子的**测验成绩**和**每天的学习**。
一份 Flutter 代码,出 Web(GitHub Pages)和 Android。

**网页版:** https://firedragonai.github.io/school-sift/
**Android:** 见 [Releases](https://github.com/FiredragonAI/school-sift/releases)(APK 直接安装)

## 为什么做这个

来自一次对全球 App 差评的挖掘([研究报告](https://claude.ai/artifact/TpPsZdS88vZk4enQDDcYe9)):「家校通知 → 家庭日程」在 126 条痛点里机会分排第一(7.50)。家长的原话:

- "3 天收到 7 位老师的 47 条通知,只有我一个人在管。"
- "25–50 封学校邮件里有一封把时间改成 10 点,夫妻俩都错过了。"
- ParentSquare / ClassDojo 这类学校指定的 App:**通知轰炸、搜不到、图片通知不可检索、多孩无法筛选、问卷弹窗、广告**。
- Ohai 之类的 AI 管家:每月 $15–40,而且没有日程总览。
- Cozi 之类的家庭日历:不会读通知,共享 ≠ 分担,不会催、不追踪是否完成。

学校通不替代学校的 App,它坐在所有通知之上,只做一件事:**读懂,然后分派下去,并追踪到做完。**

## 功能

| 页签 | 做什么 |
|---|---|
| **今日** | 今天 + 明天的日程、要家长办的事(逾期置顶)、待确认的通知、四个快捷入口 |
| **通知** | 粘贴老师发的文字或拍纸质通知 → 自动识别**日程 / 签字回执 / 缴费 / 带东西**,每条带把握度,家长核对后一键写入;**识别"改期"并更新同名旧日程**;原文永久保留、全文可搜 |
| **日程** | 月历 + 当日列表 + 接下来 30 天;按孩子着色;指派给爸爸/妈妈;导出 .ics、一键加到 Google 日历(不另造日历) |
| **待办** | 签字 / 缴费 / 带东西 / 其他;按逾期 · 今天 · 本周 · 之后分组;签字类有「待签 → 已签 → 已交回」三态 |
| **成长 · 成绩** | 按科目记测验成绩(可填满分、班均),科目卡片 + 趋势折线 + 班均虚线 |
| **成长 · 学习记录** | 每日作业完成 / 阅读分钟 / 专注度 / 一句话;连续打卡;近 14 天柱状 |
| **成长 · 签字袋** | 纸质回执拍照存档,追踪到交回 |
| **更多** | 多孩子(各自颜色)、家庭成员、中/英文、JSON 备份与恢复、演示数据 |

**隐私:** 本机优先。没有账号、没有服务器,数据只在你的设备上。[隐私政策](docs/privacy-policy.html)

## 通知识别是怎么做的

`app/lib/core/notice_parser.dart` 是一个纯规则、离线、确定性的解析器:

- 日期:`2026年10月8日` / `10月8日` / `10/8` / `Oct 8` / `8 Oct` / `明天` / `后天` / `下周三` / `next Monday`,无年份时取最近的将来
- 时间:`下午2:30` / `14:30` / `上午8点半` / `9:00 am to 2:00 pm` / `3pm`
- 动作词:签字/回执/permission slip,缴费/费用/fee,自备/携带/bring,截止/之前/by/due
- 改期词:改到/延期/取消/rescheduled/postponed → 确认时更新同孩子同标题的旧日程
- 地点:`地点:xxx` / `在xxx举行` / `at the Main Gym`;金额:`300元` / `$12`

每个结果都带置信度和来源句子,确认页上家长能一眼看出哪条需要改。测试见 `app/test/notice_parser_test.dart`。
以后接云端大模型时,只需要返回同样的 `Extraction` 结构。

## 开发

```bash
cd app
flutter pub get
flutter test          # 解析器 + 全流程冒烟
flutter run -d chrome
flutter build web --release
flutter build apk --release   # 需要 android/key.properties,否则回退 debug 签名
```

- 字体:Web 端没有系统字体,`assets/fonts/` 里是 Noto Sans SC 的子集(SIL OFL),由 `tools/fontsubset/subset.mjs` 生成。
- 图标:`GEN_ICON=1 flutter test test/tools/gen_icon_test.dart` 重新生成 Android / Web 全部尺寸。
- 部署:推 `main` 后 `.github/workflows/pages.yml` 自动跑 analyze + test + build 并发布到 GitHub Pages。

## 路线图

- [ ] 照片文字识别(端侧 ML Kit / 云端),拍完纸条直接出日程
- [ ] 本地推送提醒(截止前一天 / 当天早上)
- [ ] 家庭成员间同步(目前靠 JSON 备份手动传)
- [ ] 邮件转发地址 / Gmail 只读授权,自动收通知
- [ ] 每日早间简报

## 许可

代码 MIT;字体 Noto Sans SC 为 SIL Open Font License 1.1(见 `app/assets/fonts/LICENSE-OFL.txt`)。
