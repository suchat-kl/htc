// เทสต์ความสูงแถบภาพหัวหน้าแรก
//
//   จอ laptop (1366) และ desktop (1920): สูงเท่าความกว้าง ÷ สัดส่วนภาพ ภาพจึงแสดงเต็มทั้งรูปเหมือนกัน
//   จอแคบกว่านั้น: ไม่ต่ำกว่าความสูงขั้นต่ำเดิม (540 จอกว้าง / 480 จอแคบ) ให้ชื่อศูนย์ฯ และส่วนจองใส่ได้ครบ
//
// ไม่ pump HomeScreen ทั้งหน้า เพราะ initState เริ่ม Timer และเรียก API (ดู widget_test.dart)

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highway_training/utils/home_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('สัดส่วนภาพตรงกับขนาดจริงของไฟล์ view.jpg', () async {
    final bytes = await rootBundle.load(HomeBanner.image);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    expect(HomeBanner.aspectRatio, closeTo(image.width / image.height, 0.001));
  });

  test('laptop 1366 และ desktop 1920: สูงตามสัดส่วนภาพ เห็นภาพเต็มรูป', () {
    for (final width in [1366.0, 1920.0, 2560.0]) {
      final h = HomeBanner.height(width, isDesktop: true);
      expect(width / h, closeTo(HomeBanner.aspectRatio, 0.001));
    }
  });

  test('จอแคบ: ไม่ต่ำกว่าความสูงขั้นต่ำเดิม', () {
    expect(HomeBanner.height(1100, isDesktop: true), 540);
    expect(HomeBanner.height(375, isDesktop: false), 480);
    expect(HomeBanner.height(1024, isDesktop: false), 480);
  });
}
