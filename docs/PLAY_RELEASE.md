# Google Play 自动发布

学校通的 Android 版通过 **fastlane**(Google Play Developer API + 服务账号)从本机构建、校验并上传到 Google Play。

| 命令(在仓库根目录) | 做什么 | 会改 Play 上的东西吗 |
|---|---|---|
| `play-release.cmd check` | 检查工具、签名密钥、服务账号、Play 连接、商店文字长度 | 不会 |
| `play-release.cmd internal` | 测试 → 自动定 versionCode → 构建 AAB → 校验签名 / 版本 / targetSdk / 16 KB → 上传**内部测试** | 只动 internal 轨道 |
| `play-release.cmd production` | 把内部测试里**已有**的某个版本提升到正式版,只建**草稿**;要回答 y 并输入 `PRODUCTION-<versionCode>` | 正式版轨道多一个草稿,不发布、不送审 |
| `play-release.cmd metadata` | 上传商店标题、简介、图标、置顶大图、截图(要确认) | 改商店资料 |

可选参数:`play-release.cmd internal version_code:12`、`version_name:0.5.0`;`play-release.cmd production version_code:12`。
在 Git Bash 里一样用 `./play-release.cmd internal`。

## 设计上的安全约束

- `internal` 的轨道写死为 internal;`production` 只做「提升 + 草稿」,不上传新包,非交互终端直接拒绝,两次确认。
- 不删除、不停用任何已有发布:提升时 `deactivate_on_promote: false`,内部测试保持原样。
  (注意:往 internal 传新版本时,内部测试人员会自动收到新版本——这是内部测试轨道本身的行为。)
- 不自动公开发布、不替你送审:正式版草稿要你本人在 Play Console 检查后点「发布 / 送审」。
- 签名不是上传密钥(SHA-1 `04:98:37:69:…:BE:57`)就拒绝上传,防止 key.properties 丢失后回退成 debug 签名。
- 密钥不进 git:`app/android/key.properties`、`*.jks`、服务账号 JSON 都在 `.gitignore` 里,`check` 每次都会验证。

## 文件

```
play-release.cmd                         一条命令入口(找 Ruby → bundle exec fastlane android <lane>)
app/android/Gemfile, Gemfile.lock         fastlane 版本锁定
app/android/fastlane/Appfile              包名 + 服务账号 JSON 路径(默认 ~/.secrets/school-sift/play-service-account.json,可用 SUPPLY_JSON_KEY 覆盖)
app/android/fastlane/Fastfile             四个 lane 的全部逻辑
app/android/fastlane/.env.default         公开配置:FEEDBACK_FORM_URL、关闭 fastlane 统计
app/android/fastlane/metadata/android/    商店资料:zh-CN、en-US 的标题/简介/更新说明/图标/大图/截图
docs/PLAY_LISTING.md                      Data safety、内容分级、目标受众等问卷的草稿与待确认问题
docs/delete-account.html                  账号删除说明页(Play 要求的「删除账号网址」)
```

每次运行的日志:`app/build/release-logs/<时间>/`——每一步一个 `NN-步骤.log`,结果 `summary.json`,出错时 `error.txt`(异常、可能原因、调用栈)。

## 密钥放哪里

| 密钥 | 位置 | 说明 |
|---|---|---|
| 上传密钥 | `~/schoolsift-upload-firedragonai.jks` | **务必另外备份**(密码管理器 / 加密盘)。开启 Play App Signing 后丢了可以向 Google 申请重置上传密钥,但很麻烦 |
| 上传密钥密码 | `app/android/key.properties`(git 忽略) | storePassword / keyPassword / keyAlias / storeFile |
| Play 服务账号 | `~/.secrets/school-sift/play-service-account.json` | 已限制为只有当前 Windows 用户可读。泄露时到 Google Cloud 控制台删除这把密钥再生成新的 |

服务账号:`play-publisher@schoolsift-family.iam.gserviceaccount.com`(Google Cloud 项目 `schoolsift-family`,已开 Google Play Android Developer API)。它在 Google Cloud 里没有任何角色,能做什么完全由 Play Console 里的授权决定。

---

## 首次配置(只做一次)

已经由我完成:Ruby 3.3 + fastlane 2.241、服务账号与 JSON 密钥、API 开通、全部配置文件、商店资料草稿;`check` 与 `internal`(构建 + 校验)已在本机跑通。

剩下必须你本人在 Play Console 里做的(Google 不允许用 API 代办):

### 1. 建应用
Play Console → **创建应用**:应用名「学校通 · SchoolSift」,包名 `io.github.firedragonai.school_sift`,默认语言简体中文(zh-CN),类型「应用」,「免费」,勾选声明。✅ 2026-10-24 已完成

### 2. 给服务账号授权
Play Console → **用户和权限** → **邀请新用户** → 邮箱填
`play-publisher@schoolsift-family.iam.gserviceaccount.com`
→「应用权限」里添加「学校通」,勾选:
- **发布到测试轨道**(Release apps to testing tracks)
- **管理测试轨道和修改测试人员名单**(可选)
- **发布到正式版、排除设备、使用 Play App Signing**(以后要用 `production` 命令时才需要;只做内部测试可以先不勾)
- **管理商店展示**(要用 `metadata` 命令时)

→ 邀请。服务账号不用接受邀请,授权几分钟内生效。✅ 2026-10-24 已授权「发布到测试轨道」

### 3. Play App Signing
新应用默认由 Google 生成并保管**应用签名密钥**,我们只用上传密钥签名——推荐保持默认(见 PLAY_LISTING.md 问题 4 里对 GitHub 安装包用户的影响)。

### 4. 第一个版本 + 内部测试人员
现在的 Play Console 在建应用时就登记了包名,第一个版本可以直接用 API 上传(过去要求手动传,现在不用了):`play-release.cmd internal`。✅ 2026-10-24 已上传 0.4.1(versionCode 5)到内部测试。
还要你在 Play Console → 学校通 → **测试 → 内部测试 → 测试人员** 里建名单、加测试者的 Google 账号邮箱,复制「加入测试」链接发给他们;测试者在手机上打开链接接受邀请后,就能从 Play 商店安装。
(如果某个账号 / 应用状态下 API 仍报 `Package not found`,就在内部测试页手动「创建新发布」上传一次 `app/build/app/outputs/bundle/release/app-release.aab`。)

### 5. 补全「应用内容」和商店资料
Play Console 左侧「**政策 → 应用内容**」里每一项都要填完才能发布到任何轨道之外的地方。答案草稿在 [PLAY_LISTING.md](PLAY_LISTING.md):隐私政策网址、广告(无)、应用访问权限、内容分级问卷、目标受众、Data safety、账号删除网址、政府应用、金融功能、健康。
商店资料可以手动填,也可以在第 2 步授权「管理商店展示」后运行 `play-release.cmd metadata` 一次传完。

### 6. 验证
```bash
./play-release.cmd check
```
应显示「Play 上已有的 versionCode:5」。之后每次 `play-release.cmd internal` 都会自动上传。

### 7. 正式版之前(个人开发者账号)
2023-11-13 之后注册的**个人**开发者账号,要先在**封闭测试**里有至少 **12 名**测试者**连续 14 天**参与,才能申请正式版访问权限。内部测试不算。流程:Play Console → 测试 → 封闭测试 → 建轨道、加测试者 → 把版本发布到封闭测试(可在 Console 里从内部测试「提升」)→ 满 14 天后在「信息中心」申请正式版。组织账号没有这个要求。

---

## 以后每次更新的标准流程

1. 改代码,本机跑一遍。版本有新功能时改版本名:`app/pubspec.yaml` 的 `version: 0.5.0+N`(N 不用管)和 `lib/store/settings.dart` 的 `appVersion`,两处要一致(`check` 会拦)。
2. 写这次的更新说明:`app/android/fastlane/metadata/android/zh-CN/changelogs/<versionCode>.txt`(和 en-US),每份 ≤ 500 字。不知道 versionCode 时先写 `default.txt`,上传后改名或删掉。不写也能传,只是内部测试没有说明。
3. 提交代码(工作区不干净也能传,但 summary.json 会记下 `git_dirty: true`)。
4. `play-release.cmd internal` → 看到「已上传到内部测试」。versionCode 自动取 Play 上所有轨道的最大值 + 1,并写回 pubspec.yaml。
5. 提交 pubspec.yaml 的版本号改动,打 tag(如 `v0.5.0`)。
6. 用内部测试装到手机上验证。
7. 要发正式版:`play-release.cmd production` → 确认两次 → 到 Play Console 正式版页面检查草稿、选分阶段比例 → 你本人点「送审 / 发布」。
8. 商店截图、文字有变化时:改 `metadata/android/…` → `play-release.cmd metadata`。截图可用 `app/tools/store/` 里的脚本重拍。

GitHub Releases 的 APK 照旧用 `flutter build apk --split-per-abi`(见 README),和 Play 互不影响。

---

## 常见错误

| 现象 / 日志里的关键词 | 原因 | 处理 |
|---|---|---|
| `Package not found: io.github.firedragonai.school_sift` | Play Console 里还没建应用(或服务账号还没被授权) | 做首次配置第 1、4 步。`internal` 会照常构建 AAB 并停在上传前,告诉你 AAB 的路径 |
| `The caller does not have permission` / 403 | 服务账号没被邀请,或权限不够(比如没勾正式版就跑 `production`) | 首次配置第 2 步;改完等几分钟 |
| `Google Play Android Developer API has not been used` | API 没开 | 在 Google Cloud 控制台的 `schoolsift-family` 项目里启用 Google Play Android Developer API |
| `invalid_grant` / `Invalid JWT` | 密钥被删除、服务账号被删,或电脑时间不准 | 校准时间;或在 Google Cloud 里给服务账号新建密钥,放到 `~/.secrets/school-sift/play-service-account.json` |
| `Version code N has already been used` | versionCode 用过了(包括上传失败的、删掉的草稿) | 不带参数重新运行(自动取最大值 + 1),或 `version_code:` 指定更大的 |
| `Only releases with status draft may be created on draft app` | 应用还没发布过任何版本 | 流水线会自动改为「草稿」上传;去 Console 内部测试页手动点发布 |
| 「AAB 的签名证书是 …,不是上传密钥」 | key.properties 缺失 / 路径错,Gradle 回退成 debug 签名 | 检查 `app/android/key.properties` 和 `storeFile` 指向的 .jks |
| `Keystore was tampered with, or password was incorrect` | key.properties 里的密码不对 | 改正密码 |
| 「原生库不支持 16 KB 内存页」 | 某个插件的 .so 是 4 KB 对齐 | 升级 Flutter / 那个插件;Play 会拒绝这种包 |
| 「版本名不一致」 | pubspec.yaml 和 settings.dart 的 appVersion 不一样 | 改成一致 |
| `flutter analyze` / `flutter test` 失败 | 代码问题 | 看对应的 `NN-analyze.log` / `NN-test.log`,修好再跑;流水线不会跳过测试 |
| `Could not resolve` / 超时 | 网络 | 确认能访问 maven.google.com、pub.dev、androidpublisher.googleapis.com |
| 正式版:要求先完成封闭测试 | 个人账号新规 | 见首次配置第 7 步 |
| `Ruby/Bundler not found` | 新电脑 | `winget install RubyInstallerTeam.RubyWithDevKit.3.3`,然后 `cd app/android && bundle install` |

**换电脑**:装 Flutter、JDK 17、Ruby → `cd app/android && bundle install` → 拷贝上传密钥 .jks、`key.properties`、`~/.secrets/school-sift/play-service-account.json`(都不在 git 里)→ `play-release.cmd check`。

**Windows 注意**:`flutter.bat` 会被参数里的 `&` 截断(FEEDBACK_FORM_URL 里有),所以 Fastfile 在 Windows 上直接调用 Flutter 工具本体(`dart.exe flutter_tools.snapshot`)。PowerShell 默认不能运行 .ps1,所以入口是 `.cmd`。
