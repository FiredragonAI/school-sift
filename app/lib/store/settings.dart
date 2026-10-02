// 用户设置:AI 密钥(只存本机)、OCR 语言、提醒。和业务数据分开存,备份导出时不带密钥。

class Settings {
  /// 用户自己的 Claude API key;空 = 不用 AI,走本机 OCR + 规则解析
  String apiKey;
  String model;
  /// 用户已看过并同意"调用 AI 会把这条通知发给 Anthropic"的提示
  bool aiConsent;
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
    this.ocrLang = 'auto',
    this.remindersEnabled = true,
    this.briefEnabled = true,
    this.briefHour = 7,
    this.briefMinute = 30,
  });

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
        ocrLang: j['ocrLang'] ?? 'auto',
        remindersEnabled: j['remindersEnabled'] ?? true,
        briefEnabled: j['briefEnabled'] ?? true,
        briefHour: j['briefHour'] ?? 7,
        briefMinute: j['briefMinute'] ?? 30,
      );
}
