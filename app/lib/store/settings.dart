// 用户设置:AI 密钥(只存本机)、OCR 语言、提醒、英文回信署名。和业务数据分开存,备份导出时不带密钥。

class Settings {
  /// 用户自己的 Claude API key;空 = 不用 AI,走本机 OCR + 规则解析
  String apiKey;
  String model;
  /// 用户已看过并同意"调用 AI 会把这条通知发给 Anthropic"的提示
  bool aiConsent;
  /// 「用英文回复」发的是家长写的要点,和通知识别分开告知、分开记同意
  bool aiReplyConsent;
  /// 英文回信的署名:只在本机替换 [Your name],不发给 AI
  String replySignature;
  /// 第 3 封回信后的反馈卡已经处理过(发送或关掉),不再自动出现;回信记录页里还能手动打开
  bool replyFeedbackHandled;
  /// OCR 语言:auto(跟界面语言) / eng / chi
  String ocrLang;
  bool remindersEnabled;
  bool briefEnabled;
  int briefHour;
  int briefMinute;

  Settings({
    this.apiKey = '',
    this.model = defaultModel,
    this.aiConsent = false,
    this.aiReplyConsent = false,
    this.replySignature = '',
    this.replyFeedbackHandled = false,
    this.ocrLang = 'auto',
    this.remindersEnabled = true,
    this.briefEnabled = true,
    this.briefHour = 7,
    this.briefMinute = 30,
  });

  /// 显示用版本号;发版时与 pubspec.yaml 同步改
  static const appVersion = '0.3.0';

  static const defaultModel = 'claude-opus-5-5';
  static const models = <(String, String)>[
    ('claude-opus-5-5', 'Claude Opus 5.5(默认,最准)'),
    ('claude-sonnet-5-5', 'Claude Sonnet 5.5(快,便宜一半)'),
    ('claude-haiku-4-5', 'Claude Haiku 4.5(最便宜)'),
  ];

  bool get aiEnabled => apiKey.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'model': model,
        'aiConsent': aiConsent,
        'aiReplyConsent': aiReplyConsent,
        'replySignature': replySignature,
        'replyFeedbackHandled': replyFeedbackHandled,
        'ocrLang': ocrLang,
        'remindersEnabled': remindersEnabled,
        'briefEnabled': briefEnabled,
        'briefHour': briefHour,
        'briefMinute': briefMinute,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        apiKey: j['apiKey'] ?? '',
        model: j['model'] ?? defaultModel,
        aiConsent: j['aiConsent'] ?? false,
        aiReplyConsent: j['aiReplyConsent'] ?? false,
        replySignature: j['replySignature'] ?? '',
        replyFeedbackHandled: j['replyFeedbackHandled'] ?? false,
        ocrLang: j['ocrLang'] ?? 'auto',
        remindersEnabled: j['remindersEnabled'] ?? true,
        briefEnabled: j['briefEnabled'] ?? true,
        briefHour: j['briefHour'] ?? 7,
        briefMinute: j['briefMinute'] ?? 30,
      );
}
