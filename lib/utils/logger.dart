import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logger ที่ถูกตัดทิ้งทั้งหมดใน release build
///
/// หลักการ: [kDebugMode] เป็น `const bool` ทำให้ใน release มันคือ `const false`
/// คอมไพเลอร์ (dart2js / AOT) จึงตัดโค้ดในบล็อกทิ้งได้ตั้งแต่ตอน compile
/// ข้อความ log จะไม่ปรากฏใน `build/web/main.dart.js` เลย
///
/// ห้ามเปลี่ยน [_on] เป็นตัวแปรธรรมดา (`static bool`) เพราะจะ tree-shake ไม่ได้
/// โค้ดและข้อความทั้งหมดจะยังติดไปกับ bundle
///
/// ตรวจสอบว่าใช้ได้จริง:
///   flutter build web --release
///   grep -c "Login Attempt" build/web/main.dart.js   # ต้องได้ 0
class AppLogger {
  AppLogger._();

  static const bool _on = kDebugMode;

  /// debug — รายละเอียดระหว่างพัฒนา
  static void d(Object? msg, {String tag = 'APP'}) => _log(tag, msg, 500);

  /// info — เหตุการณ์สำคัญที่สำเร็จ
  static void i(Object? msg, {String tag = 'APP'}) => _log(tag, msg, 800);

  /// warning — ผิดปกติแต่ยังทำงานต่อได้
  static void w(Object? msg, {String tag = 'APP'}) => _log(tag, msg, 900);

  /// error — ล้มเหลว
  static void e(
    Object? msg, {
    String tag = 'APP',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_on) return;
    developer.log(
      '$msg',
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// สำหรับ log ที่แพงหรือมีข้อมูลอ่อนไหว
  ///
  /// closure จะไม่ถูกเรียกเลยใน release ต่างจาก [d] ที่ string interpolation
  /// ที่ call site อาจยังทำงานอยู่
  ///
  ///   AppLogger.lazy(() => 'payload: ${jsonEncode(bigObject)}');
  static void lazy(Object? Function() build, {String tag = 'APP'}) {
    if (!_on) return;
    developer.log('${build()}', name: tag);
  }

  /// ปิดบังข้อมูลอ่อนไหวก่อน log — ใช้กับ response ของ endpoint auth เสมอ
  ///
  /// คืน `null` ใน release เพื่อไม่ให้เหลือร่องรอยของข้อมูลจริง
  static Object? redact(Object? data) {
    if (!_on) return null;
    return _redact(data, 0);
  }

  static const Set<String> _secretKeys = {
    'access_token',
    'refresh_token',
    'accessToken',
    'refreshToken',
    'token',
    'id_token',
    'idToken',
    'password',
    'newPassword',
    'oldPassword',
    'secret',
    'apiKey',
    'api_key',
    'authorization',
    'Authorization',
  };

  static Object? _redact(Object? data, int depth) {
    if (depth > 5) return data;
    if (data is Map) {
      return {
        for (final entry in data.entries)
          entry.key: _secretKeys.contains('${entry.key}')
              ? '***REDACTED***'
              : _redact(entry.value, depth + 1),
      };
    }
    if (data is List) {
      return [for (final item in data) _redact(item, depth + 1)];
    }
    return data;
  }

  static void _log(String tag, Object? msg, int level) {
    if (!_on) return;
    developer.log('$msg', name: tag, level: level);
  }
}
