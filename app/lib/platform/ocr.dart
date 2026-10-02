// 本机 OCR(没有 AI key 时的兜底,也是隐私默认):
//   Web      → Tesseract.js(按需从 CDN 加载,识别在浏览器里跑,图片不离开本机)
//   Android  → Google ML Kit 文字识别(端侧模型,离线)
export 'ocr_native.dart' if (dart.library.js_interop) 'ocr_web.dart';
