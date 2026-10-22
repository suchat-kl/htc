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
/// ข้อความเมื่อผู้ใช้ยกเลิก ใช้ข้อความเดียวกันทุกหน้าจอ
const String thaidCancelledMessage = 'ผู้ใช้งานยกเลิกการใช้ ThaID';

String thaidReturnUrl() {
  final base = html.document.baseUri ?? html.window.location.href;
  return Uri.parse(base).resolve('thaid_callback.html').toString();
}

/// ยืนยันตัวตนด้วย ThaID ในหน้าต่างใหม่ คืน null ถ้าผู้ใช้ยกเลิก ([thaidCancelledMessage])
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
///
/// มือถือ: แอป ThaID เปิดหน้า callback ใน**แท็บใหม่**ที่ไม่มี window.opener ข้อ 3 จึงไม่เกิด
/// [thaidAuthorize] จึงถามสถานะของ state จาก backend แทน (ดูคำอธิบายที่ฟังก์ชันนั้น)
Future<ThaidIdentity?> verifyWithThaid(ApiService api) async {
  final state = await thaidAuthorize(api);
  if (state == null) return null;
  return api.thaidResult(state);
}

/// เปิดหน้าต่าง ThaID ให้สแกน แล้วรอผล คืน state ที่ตรวจแล้วว่าตรงกับที่ส่งไป
/// ผู้เรียกนำ state ไปขอผล ([ApiService.thaidResult]) หรือเข้าสู่ระบบ ([ApiService.loginWithThaid])
/// คืน null ถ้าผู้ใช้ยกเลิก: กดยกเลิกในแอป ThaID หรือปิดหน้าต่างเอง
///
/// รับผลได้สองทาง ทางไหนมาก่อนใช้ทางนั้น
///   - คอมพิวเตอร์: thaid_callback.html ในหน้าต่างที่เปิดไว้ส่ง state กลับมาทาง postMessage
///   - มือถือ: แอป ThaID เปิดหน้า callback ใน**แท็บใหม่**ที่ไม่มี window.opener postMessage จึงไม่มา
///     หน้านี้ถามสถานะของ state จาก backend ([ApiService.thaidStatus]) ทุก 3 วินาที
///     และทันทีที่ผู้ใช้สลับกลับมาที่แท็บนี้ DONE / ERROR = คืน state ให้ผู้เรียกไปขอผลต่อ
///     (ผลสำเร็จหรือข้อความผิดพลาดได้จากเส้น result / login ตามเดิม) GONE = ยกเลิกในแอป ThaID
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
  StreamSubscription<html.Event>? visibility;
  Timer? watcher;
  Timer? poller;

  void finish(Object? result, {bool isError = false}) {
    if (done.isCompleted) return;
    sub.cancel();
    visibility?.cancel();
    watcher?.cancel();
    poller?.cancel();
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
    // ผู้ใช้กดยกเลิกในแอป ThaID (รหัส user_denied) = ยกเลิก ไม่ใช่ข้อผิดพลาด
    if (data['cancelled'] == true) {
      finish(null);
      return;
    }
    final error = data['error'];
    if (error is String && error.isNotEmpty) {
      finish(Exception(error), isError: true);
      return;
    }
    finish(sentState);
  });

  // ถามสถานะจาก backend (ทางของมือถือ ที่ผลไม่ได้กลับมาทาง postMessage)
  // [cancelIfPending] = ถามครั้งสุดท้ายหลังหน้าต่าง ThaID ปิด: ยังไม่เสร็จ/ถามไม่ได้ = ผู้ใช้ยกเลิก
  var checking = false;
  Future<void> check({bool cancelIfPending = false}) async {
    if (done.isCompleted || checking) return;
    checking = true;
    try {
      final status = await api.thaidStatus(sentState);
      if (status == 'DONE' || status == 'ERROR') {
        finish(sentState);
      } else if (status == 'GONE' || cancelIfPending) {
        finish(null);
      }
    } finally {
      checking = false;
    }
  }

  bool pageVisible() => html.document.visibilityState != 'hidden';

  poller = Timer.periodic(const Duration(seconds: 3), (_) {
    if (pageVisible()) check();
  });
  // มือถือหยุดตัวจับเวลาของแท็บที่อยู่เบื้องหลัง ถามทันทีเมื่อผู้ใช้กลับมาที่แท็บนี้
  visibility = html.document.onVisibilityChange.listen((_) {
    if (pageVisible()) check();
  });

  // หน้าต่าง ThaID ปิดแล้ว (ผู้ใช้ปิดเอง หรือมือถือปิดแท็บตอนเปิดแอป ThaID)
  // ถามสถานะครั้งสุดท้ายเมื่อหน้านี้แสดงอยู่ (ผู้ใช้อยู่ที่หน้านี้จริง) — เสร็จแล้วไปต่อ ยังไม่เสร็จ = ยกเลิก
  // รอเผื่อข้อความที่ส่งมาก่อนหน้าต่างปิดอีกนิด; ระหว่างผู้ใช้อยู่ในแอป ThaID (หน้านี้ซ่อน) ยังไม่ตัดสิน
  var popupClosedFor = 0;
  watcher = Timer.periodic(const Duration(seconds: 1), (_) {
    if (popup.closed != true) return;
    popupClosedFor++;
    if (popupClosedFor >= 2 && pageVisible()) check(cancelIfPending: true);
  });

  return done.future.timeout(
    const Duration(minutes: 11),
    onTimeout: () {
      sub.cancel();
      visibility?.cancel();
      watcher?.cancel();
      poller?.cancel();
      popup.close();
      throw Exception('หมดเวลายืนยันตัวตน กรุณาลองใหม่');
    },
  );
}
