# Flutter 引擎与插件
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit 文字识别:只打包了拉丁 + 中文模型,其余脚本的类不存在,别让 R8 报 missing class
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
# flutter_local_notifications 用 Gson 反序列化排程
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature, *Annotation*
