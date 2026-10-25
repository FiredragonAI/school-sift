# Google Play 商店资料与「应用内容」问卷草稿

能从代码确定的已经填好;标 **❓** 的需要你确认,我不替你编。

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
| 删除账号网址 | https://firedragonai.github.io/school-sift/delete-account.html | | 随这次提交部署 |

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

## Data safety(数据安全)草稿

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
| 个人信息 → 姓名 ❓ | 可选 | 应用功能 | 家长录入的孩子名字、家庭成员称呼(同步时上传)。孩子的名字算不算「姓名」由你判断,保守起见建议勾上 |
| 照片和视频 → 照片 | 可选 | 应用功能 | 同步时上传的通知 / 回执照片(压缩后) |
| 应用活动 → 其他用户生成的内容 | 可选 | 应用功能 | 通知原文、日程、待办、成绩、学习记录、英文回信 |
| 应用信息和性能 → 诊断信息 | 必需 ❓ | 分析(诊断) | ML Kit 文字识别会发送设备型号、系统版本、延迟、错误码等诊断数据(官方说明) |
| 设备或其他 ID ❓ | 必需 | 分析(诊断) | ML Kit 说明里列了「按安装生成的标识,不用于识别用户或设备」 |

**不收集**:位置、通讯录、短信、通话、财务信息、健康、网页浏览记录、已安装应用、音频、文件和文档(PDF 只在本机识别,同步的是识别出来的文字)。

**❓ 用户自己的 Claude API key 的场景**:家长主动点「用 AI 识别 / 用英文回复」时,这一条通知的文字和图片会从手机直接发到 Anthropic(api.anthropic.com),用的是家长自己的 key,不经过我们。这些内容已经被上面的「照片」「其他用户生成的内容」覆盖;要不要把 Anthropic 视为「分享」,建议你读一下 Play 对「用户主动发起的传输」的豁免条款后决定。我的建议:不勾「分享」,在隐私政策里写清楚(已写)。

Firebase Authentication 还会为了安全和防滥用收集 **IP 地址**;Play 表格里没有单独的「IP 地址」类型,Google 的说明是按用途归类——只用于安全时一般不需要单独勾选,❓ 由你确认。

## 内容分级(IARC 问卷)草稿

- 类别:**实用工具、生产力、通讯或其他**(Utility, Productivity, Communication, or Other)
- 暴力、恐怖、性、粗话、毒品 / 烟酒、赌博、模拟赌博:**都没有**
- **❓ 用户之间是否可以互动或交换内容?** 家庭同步让被邀请的家人看到、修改同一份数据。建议答「**是**」(只限受邀家人;没有公开聊天、没有陌生人)。答「是」会多一个「用户互动」标签,不影响年龄分级
- 是否分享用户的实时位置:**否**
- 是否允许购买数字商品:**否**
- 是否包含不受限制的网络访问(内置浏览器):**否**(链接用系统浏览器打开)
- 预计结果:各地区最低年龄档(如 IARC 3+ / Everyone)

## 目标受众和内容

- **❓ 目标年龄:18 岁以上**(应用给家长用;孩子不需要也不应该注册——隐私政策已写)。选 18+ 可以避开「家庭政策」的额外要求
- 应用是否会无意中吸引儿童?**否**(界面是家长工具,无卡通游戏元素)

## 其他「应用内容」声明

| 项目 | 答案 |
|---|---|
| 隐私政策 | https://firedragonai.github.io/school-sift/privacy-policy.html |
| 广告 | 不含广告 |
| 应用访问权限 | **所有功能无需登录即可使用**;家庭同步需要账号——审核员可自行注册(邮箱验证)。❓ 如果你希望审核员直接看到家庭同步,需要提供一个测试账号,我可以帮你建 |
| 账号删除 | 应用内可删除;网址 https://firedragonai.github.io/school-sift/delete-account.html |
| 政府应用 | 否 |
| 金融功能 | 无(「缴费」只是记录提醒,不处理付款) |
| 健康 | 无 |
| 新闻应用 | 否 |
| 数据安全 | 见上 |

---

## 需要你确认的问题

1. **开发者账号**:用和 Listen Everything 同一个 Play 开发者账号吗?是**个人**账号还是**组织**账号?(个人账号要先完成 12 人 × 14 天的封闭测试才能上正式版。)
2. **Play Console 里是否已经建过「学校通」?**(`check` 显示 API 找不到 `io.github.firedragonai.school_sift`,应该是还没建。)
3. **默认语言和上架地区**:默认语言用 **中文(简体)zh-CN** 还是 **英语(美国)en-US**?先只上美国,还是全球(中国大陆没有 Google Play)?
4. **签名方式**:推荐用 Google 生成的应用签名密钥(默认,丢了也不怕)。代价:Play 下载的版本和 GitHub Releases 的 APK 签名不同,装过 GitHub 版的人要先导出备份(或开家庭同步)、卸载,再从 Play 安装。另一选择是把现有上传密钥导入为应用签名密钥,两边签名一致,但 Play 不能替你轮换密钥。你选哪个?
5. **商店联系邮箱**:Play 要求在商店页公开一个开发者邮箱(应用和源码里依旧不写个人邮箱)。用哪个邮箱?建议单独建一个支持邮箱。
6. **英文标题**用「SchoolSift: School Notices」可以吗?中文标题「学校通 · SchoolSift」可以吗?
7. **应用类别**:「教育」还是「育儿」(Parenting)?我建议「育儿」——用户是家长。
8. **内部测试人员**:要加哪些 Google 账号邮箱?(在 Play Console 里加,不写进代码。)
9. Data safety 里标 ❓ 的三项(孩子姓名、ML Kit 诊断与标识、Anthropic)和内容分级的「用户互动」,按我的建议填可以吗?
10. 审核员要不要一个家庭同步的测试账号?
