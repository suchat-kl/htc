// เทสต์สถานะของคำขอ ThaID (POST /api/auth/public-thaid/status) ที่หน้าเว็บบนมือถือใช้แทนการรอ postMessage
//
// บนมือถือแอป ThaID เปิดหน้า callback ในแท็บใหม่ที่ไม่มี window.opener — thaidAuthorize จึงถามสถานะเป็นระยะ
// ส่วนที่เปิดหน้าต่าง/จับเวลาต้องใช้เบราว์เซอร์ เทสต์นี้ตรวจตัวเรียก API: ส่ง state ใน body ไม่แนบ token
// และถามไม่ได้ (เครือข่าย / 5xx / รูปผิด) = null ไม่ใช่ยกเลิก

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highway_training/services/api_service.dart';

/// backend จำลองเฉพาะเส้น status ตอบตาม [statuses] (ไม่อยู่ในนี้ = GONE)
class _FakeStatusBackend implements HttpClientAdapter {
  final Map<String, String> statuses = {};
  final List<RequestOptions> requests = [];

  /// ตั้งค่าแล้วเส้นถัดไปตอบ HTTP นี้แทน (ทดสอบ 5xx)
  int? forceStatusCode;

  /// ตั้งค่าแล้วเส้นถัดไปตอบ body นี้แทน (ทดสอบรูปผิด)
  Object? forceBody;

  /// ตั้งค่าแล้วเครือข่ายล้ม
  bool failNetwork = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failNetwork) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'ต่อไม่ได้',
      );
    }
    if (options.path != '/api/auth/public-thaid/status' ||
        options.method != 'POST') {
      return _json(404, {'message': 'ไม่มีเส้นนี้'});
    }
    if (forceStatusCode != null) {
      return _json(forceStatusCode!, {'message': 'ล้ม'});
    }
    if (forceBody != null) return _json(200, forceBody!);
    final state = (options.data as Map)['state'];
    return _json(200, {'status': statuses[state] ?? 'GONE'});
  }

  ResponseBody _json(int code, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    code,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  final api = ApiService();
  late _FakeStatusBackend backend;

  setUp(() {
    backend = _FakeStatusBackend();
    api.publicDio.httpClientAdapter = backend;
  });

  test('ตอบสถานะตามที่ backend บอก ส่ง state ใน body และไม่แนบ token', () async {
    backend.statuses['state-wait'] = 'PENDING';
    backend.statuses['state-ok'] = 'DONE';
    backend.statuses['state-bad'] = 'ERROR';

    expect(await api.thaidStatus('state-wait'), 'PENDING');
    expect(await api.thaidStatus('state-ok'), 'DONE');
    expect(await api.thaidStatus('state-bad'), 'ERROR');
    expect(await api.thaidStatus('state-ไม่มี'), 'GONE');
    // ถามซ้ำได้ (อ่านอย่างเดียว)
    expect(await api.thaidStatus('state-ok'), 'DONE');

    for (final r in backend.requests) {
      expect(r.method, 'POST');
      // state อยู่ใน body ไม่อยู่ใน URL จึงไม่ไปอยู่ใน log ของ nginx
      expect(r.queryParameters, isEmpty);
      expect(r.headers['Authorization'], isNull);
    }
    expect(backend.requests.first.data, {'state': 'state-wait'});
  });

  test('ถามไม่ได้ = null ให้ตัวรอถามใหม่รอบหน้า ไม่ถือว่ายกเลิก', () async {
    backend.forceStatusCode = 503;
    expect(await api.thaidStatus('state-x'), isNull);

    backend.forceStatusCode = null;
    backend.forceBody = {'อื่น': 1};
    expect(await api.thaidStatus('state-x'), isNull);

    backend.forceBody = null;
    backend.failNetwork = true;
    expect(await api.thaidStatus('state-x'), isNull);
  });
}
