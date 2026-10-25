# Google Play 商店资料与「应用内容」问卷

能从代码确定的已经填好;需要人决定的,2026-10-24 已由开发者确认(见文末「已确认的决定」)。

## 商店资料(已在 `app/android/fastlane/metadata/android/`)

| 项目 | zh-CN | en-US | 要求 |
|---|---|---|---|
| 应用名称 | 学校通 · SchoolSift | SchoolSift: School Notices | ≤ 30 字符 ✓ |
| 简短说明 | short_description.txt | short_description.txt | ≤ 80 ✓ |
| 完整说明 | full_description.txt | full_description.txt | ≤ 4000 ✓ |
| 应用图标 | images/icon.png | 同左 | 512×512 PNG,满版方形(Play 自动切圆角)✓ |
| 置顶大图 | images/featureGraphic.png | 同左(英文) | 1024×500,24 位 PNG ✓ |
| 手机截图 | images/phoneScreenshots/1–6 | 同左(英文界面 + 英文演示数据) | 2–8 张,1080×1920(9:16)✓ |
| 首版更新说明 | changelogs/5.txt | changelogs/5.txt | ≤ 500 ✓ |
| 隐私政策网址 | https://firedragonai.github.io/school-sift/privacy-policy.html | | 已上线 ✓ |
| 删除账号网址 | https://firedragonai.github.io/school-sift/delete-account.html | | 已上线 ✓ |

截图来自网页版(和 Android 同一套 Flutter 界面),演示数据,不含真实个人信息;没有手机状态栏。重拍:`app/tools/store/`(`npm run shots`、`npm run feature`)。

应用里的显示名(手机桌面上)是「学校通」,英文系统下也是「学校通」;商店标题可以和它不同。

## 技术条件(审计结果)

| 条件 | 状态 |
|---|---|
| 技术栈 | Flutter 3.47.3(Dart)+ Kotlin DSL Gradle,出 AAB |
| applicationId | `io.github.firedragonai.school_sift` |
| versionName / versionCode | 来自 `pubspec.yaml`(现为 0.4.1+5);上传时自动取 Play 最大值 + 1 |
| targetSdk / minSdk / compileSdk | 36 / 24 / 36(Play 下限 35 ✓) |
| 64 位、16 KB 页 | arm64-v8a / armeabi-v7a / x86_64;64 位原生库 16 KB 对齐(流水线每次检查) |
| Release 签名 | 上传密钥 `~/schoolsift-upload-firedragonai.jks`,SHA-1 `04:98:37:69:3D:C8:5E:A0:8E:5F:58:BF:63:C9:FB:18:98:60:BE:57` |
| Play App Signing | 新应用默认开启,Google 保管应用签名密钥 |
| R8 混淆 | 开启;mapping.txt 随每次上传,崩溃堆栈可还原 |
| 权限 | 相机(拍通知,`required=false`)、通知、开机后恢复提醒、震动、网络;无位置、通讯录、存储、精确闹钟、后台定位等敏感权限 |
| 账号删除 | 应用内「更多 → 家庭同步 → 删除账号」+ 网页版同一入口 + 说明页 ✓ |
| 广告 / 应用内购买 | 无 / 无 |

---

## Data safety(数据安全)——按此填写

依据:代码、[Firebase 的 Play 数据披露说明](https://firebase.google.com/docs/android/play-data-disclosure)、[ML Kit 的 Android 数据披露说明](https://developers.google.com/ml-kit/android-data-disclosure)。最终怎么填由你决定(Google 也是这么要求的)。

**总问题**
- 应用是否收集或分享用户数据?**是**(只在开启家庭同步时,以及 ML Kit 的诊断数据)
- 所有数据是否在传输中加密?**是**(Firebase、ML Kit、Anthropic 都走 HTTPS)
- 是否提供删除数据的方式?**是**:应用内删除账号 + 删除账号网址

**收集的数据**(都**不分享**给第三方——Firebase、ML Kit 是 Google 作为服务提供方代为处理,按 Play 的定义不算「分享」)

| 数据类型 | 必需 / 可选 | 用途 | 来源 |
|---|---|---|---|
| 个人信息 → 电子邮件地址 | 可选(只在开启家庭同步时) | 账号管理、应用功能 | 家庭同步登录、邀请家人 |
| 个人信息 → 用户 ID | 可选 | 账号管理、应用功能 | Firebase 账号 UID |
| 个人信息 → 姓名 | 可选 | 应用功能 | 家长录入的孩子名字、家庭成员称呼(同步时上传);保守起见申报 |
| 照片和视频 → 照片 | 可选 | 应用功能 | 同步时上传的通知 / 回执照片(压缩后) |
| 应用活动 → 其他用户生成的内容 | 可选 | 应用功能 | 通知原文、日程、待办、成绩、学习记录、英文回信 |
| 应用信息和性能 → 诊断信息 | 必需 | 分析(诊断) | ML Kit 文字识别会发送设备型号、系统版本、延迟、错误码等诊断数据(官方说明) |
| 设备或其他 ID | 必需 | 分析(诊断) | ML Kit 说明里列了「按安装生成的标识,不用于识别用户或设备」 |

**不收集**:位置、通讯录、短信、通话、财务信息、健康、网页浏览记录、已安装应用、音频、文件和文档(PDF 只在本机识别,同步的是识别出来的文字)。

**用户自己的 Claude API key 的场景**:家长主动点「用 AI 识别 / 用英文回复」时,这一条通知的文字和图片会从手机直接发到 Anthropic(api.anthropic.com),用的是家长自己的 key,不经过我们。这些内容已经被上面的「照片」「其他用户生成的内容」覆盖;属于用户主动发起、发往用户自己选择的服务:**不勾「分享」**,隐私政策里已写清楚。

Firebase Authentication 还会为了安全和防滥用收集 **IP 地址**;Play 表格里没有单独的「IP 地址」类型,Google 的说明是按用途归类——只用于安全,**不单独申报**。

## 内容分级(IARC 问卷)——按此填写

- 类别:**实用工具、生产力、通讯或其他**(Utility, Productivity, Communication, or Other)
- 暴力、恐怖、性、粗话、毒品 / 烟酒、赌博、模拟赌博:**都没有**
- **用户之间是否可以互动或交换内容?答「是」**:家庭同步让被邀请的家人看到、修改同一份数据(只限受邀家人;没有公开聊天、没有陌生人)。答「是」会多一个「用户互动」标签,不影响年龄分级
- 是否分享用户的实时位置:**否**
- 是否允许购买数字商品:**否**
- 是否包含不受限制的网络访问(内置浏览器):**否**(链接用系统浏览器打开)
- 预计结果:各地区最低年龄档(如 IARC 3+ / Everyone)

## 目标受众和内容

- **目标年龄:18 岁以上**(应用给家长用;孩子不需要也不应该注册——隐私政策已写)。选 18+ 可以避开「家庭政策」的额外要求
- 应用是否会无意中吸引儿童?**否**(界面是家长工具,无卡通游戏元素)

## 其他「应用内容」声明

| 项目 | 答案 |
|---|---|
| 隐私政策 | https://firedragonai.github.io/school-sift/privacy-policy.html |
| 广告 | 不含广告 |
| 应用访问权限 | 不提供测试账号(已确认)。选「部分功能受限」,说明写:*Core features work without an account. Family sync (More → Family sync) needs an account: tap Sign up, enter any email you can receive mail at, verify it, then create a family.* 不填用户名密码。若审核要求测试账号再补 |
| 账号删除 | 应用内可删除;网址 https://firedragonai.github.io/school-sift/delete-account.html |
| 政府应用 | 否 |
| 金融功能 | 无(「缴费」只是记录提醒,不处理付款) |
| 健康 | 无 |
| 新闻应用 | 否 |
| 数据安全 | 见上 |

---

## 已确认的决定(2026-10-24)

| 问题 | 决定 |
|---|---|
| 开发者账号 | **个人**账号 → 正式版前要封闭测试 12 人 × 连续 14 天 |
| Play 应用 | 已建,包名 `io.github.firedragonai.school_sift`;0.4.1(versionCode 5)已用 API 传到内部测试 |
| 默认语言 | **英语(美国)en-US**(建应用时选的是 zh-CN,用 `play-release.cmd details` 改,需要「管理商店展示」权限);中文作为翻译 |
| 上架地区 | **全球**(Play Console 里给每个轨道选「所有国家/地区」;中国大陆没有 Google Play) |
| 签名 | Google 生成并保管应用签名密钥(默认) |
| 联系邮箱 | 已定,只写在本机 `app/android/fastlane/.env`(不进 git),由 `play-release.cmd details` 命令设置;会公开显示在商店页 |
| 类别 | **教育**(Education)——API 改不了,在 Play Console「商店设置」里选 |
| 英文标题 | SchoolSift: School Notices |
| Data safety / 内容分级 | 按上面的建议填 |
| 审核测试账号 | 不提供 |
| 内部测试人员 | 开发者在 Play Console 里自己加 |
