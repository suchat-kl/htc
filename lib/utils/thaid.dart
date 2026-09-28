// lib/utils/thaid.dart
import 'dart:async';

import 'package:universal_html/html.dart' as html;

import '../services/api_service.dart';

/// ผลยืนยันตัวตนจาก ThaID ที่ใช้เติมใบจอง
class ThaidIdentity {
  final String pid;
  final String? title;
  final String? givenName;
  final String? familyName;

  /// คำนำหน้าติดชื่อ เว้นวรรคก่อนนามสกุล เช่น "นายสมชาย ใจดี"
  final String fullName;

  /// ที่อยู่ตามหน้าบัตร เก็บลงใบจองไว้ใช้กับใบเสร็จ
  final String? address;

  const ThaidIdentity({
    required this.pid,
    this.title,
    this.givenName,
    this.familyName,
    required this.fullName,
    this.address,
  });

  factory ThaidIdentity.fromJson(Map<String, dynamic> json) => ThaidIdentity(
    pid: json['pid'] as String,
    title: json['title'] as String?,
    givenName: json['givenName'] as String?,
    familyName: json['familyName'] as String?,
    fullName: json['fullName'] as String? ?? '',
    address: json['address'] as String?,
  );
}

/// หน้า thaid_callback.html ของเว็บที่เปิดอยู่ ใช้ base href ของแอป (/htc/)
/// เข้าผ่าน inf.doh.go.th dbdoh หรือ backupdoh ก็กลับมาที่เดิม
String thaidReturnUrl() {
  final base = html.document.baseUri ?? html.window.location.href;
  return Uri.parse(base).resolve('thaid_callback.html').toString();
}

/// ยืนยันตัวตนด้วย ThaID ในหน้าต่างใหม่ คืน null ถ้าผู้ใช้ปิดหน้าต่างเอง
///
/// เปิดหน้าต่างใหม่แทนการพาหน้านี้ไป ฟอร์มที่กรอกไว้จะได้ไม่หาย
/// ต้องเรียกจากการกดปุ่มโดยตรง เพราะเบราว์เซอร์บล็อกหน้าต่างที่ไม่ได้เปิดจากการกด
/// จึงเปิดหน้าต่างเปล่าก่อน แล้วค่อยใส่ URL ของ ThaID เมื่อได้จาก backend
///
/// ขั้นตอน:
///   1. backend สุ่ม state ส่งไปกับ URL ของ ThaID หน้านี้เก็บ state ไว้
///   2. ผู้ใช้สแกน QR -> ThaID ส่ง state กลับมาที่ backend ตรวจว่าตรงกับที่ส่งไป
///   3. thaid_callback.html ส่ง state กลับมาทาง postMessage หน้านี้เทียบกับค่าที่เก็บไว้ ต้องตรงกัน
///   4. ขอเลขบัตรและชื่อจาก backend ด้วย state นั้น ได้ครั้งเดียว
Future<ThaidIdentity?> verifyWithThaid(ApiService api) async {
  final state = await thaidAuthorize(api);
  if (state == null) return null;
  return api.thaidResult(state);
}

/// เปิดหน้าต่าง ThaID ให้สแกน แล้วรอผล คืน state ที่ตรวจแล้วว่าตรงกับที่ส่งไป
/// ผู้เรียกนำ state ไปขอผล ([ApiService.thaidResult]) หรือเข้าสู่ระบบ ([ApiService.loginWithThaid])
/// คืน null ถ้าผู้ใช้ปิดหน้าต่างเอง
Future<String?> thaidAuthorize(ApiService api) async {
  final popup = html.window.open(
    '',
    'thaid',
    'width=520,height=780,menubar=no,toolbar=no',
  );

  final String sentState;
  try {
    final start = await api.thaidStart(thaidReturnUrl());
    sentState = start.state;
    popup.location.href = start.url;
  } catch (e) {
    popup.close();
    rethrow;
  }

  final done = Completer<String?>();
  late final StreamSubscription<html.MessageEvent> sub;
  Timer? watcher;

  void finish(Object? result, {bool isError = false}) {
    if (done.isCompleted) return;
    sub.cancel();
    watcher?.cancel();
    if (isError) {
      done.completeError(result!);
    } else {
      done.complete(result as String?);
    }
  }

  sub = html.window.onMessage.listen((event) async {
    // รับเฉพาะข้อความจากเว็บเดียวกัน (หน้า thaid_callback.html)
    if (event.origin != html.window.location.origin) return;
    final data = event.data;
    if (data is! Map || data['type'] != 'thaid') return;
    // ค่าสุ่มที่ได้กลับมาต้องตรงกับที่ส่งไป ไม่งั้นเป็นผลของคำขออื่น ไม่รับ
    if (data['state'] != sentState) {
      finish(
        Exception('ค่าตรวจสอบไม่ตรงกับที่ส่งไป กรุณายืนยันตัวตนใหม่'),
        isError: true,
      );
      return;
    }
    final error = data['error'];
    if (error is String && error.isNotEmpty) {
      finish(Exception(error), isError: true);
      return;
    }
    finish(sentState);
  });

  // ผู้ใช้ปิดหน้าต่างเองก่อนยืนยันเสร็จ = ยกเลิก
  // รอเผื่อข้อความที่ส่งมาก่อนหน้าต่างปิดอีกนิด
  watcher = Timer.periodic(const Duration(seconds: 1), (_) {
    if (popup.closed == true) {
      Future.delayed(const Duration(seconds: 2), () => finish(null));
    }
  });

  return done.future.timeout(
    const Duration(minutes: 11),
    onTimeout: () {
      sub.cancel();
      watcher?.cancel();
      popup.close();
      throw Exception('หมดเวลายืนยันตัวตน กรุณาลองใหม่');
    },
  );
}
