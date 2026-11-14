// เทสต์ความสูงแถบภาพหัวหน้าแรก
//
//   ปกติ: สูงเท่าความกว้าง ÷ สัดส่วนภาพ ภาพจึงแสดงเต็มทั้งรูป
//   จอกว้างมาก: ไม่เกิน 70% ของความสูงหน้าต่าง ให้ส่วนประกาศใต้ภาพยังอยู่ในจอแรก
//   จอแคบ/เตี้ย: ไม่ต่ำกว่าความสูงขั้นต่ำเดิม (540 จอกว้าง / 480 จอแคบ) ให้ชื่อศูนย์ฯ และส่วนจองใส่ได้ครบ
//
// ความสูงหน้าต่างในเทสต์ = พื้นที่หน้าเว็บในเบราว์เซอร์ (ความสูงจอหักแถบของเบราว์เซอร์แล้ว)
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

  test('หน้าต่างสูงพอ: สูงตามสัดส่วนภาพ เห็นภาพเต็มรูป', () {
    for (final width in [1366.0, 1920.0, 2560.0]) {
      final h = HomeBanner.height(width, isDesktop: true, viewportHeight: 2000);
      expect(width / h, closeTo(HomeBanner.aspectRatio, 0.001));
    }
  });

  test('จอกว้างมาก: ไม่เกิน 70% ของความสูงหน้าต่าง', () {
    // Full HD 1920x1080 พื้นที่หน้าเว็บราว 950: ตามสัดส่วนภาพ 768 ถูกจำกัดเหลือ 665
    expect(
      HomeBanner.height(1920, isDesktop: true, viewportHeight: 950),
      closeTo(665, 0.001),
    );
    // 2560x1440 พื้นที่หน้าเว็บราว 1310: ตามสัดส่วนภาพ 1024 ถูกจำกัดเหลือ 917
    expect(
      HomeBanner.height(2560, isDesktop: true, viewportHeight: 1310),
      closeTo(917, 0.001),
    );
  });

  test('จอแคบหรือเตี้ย: ไม่ต่ำกว่าความสูงขั้นต่ำเดิม แม้เกินเพดาน', () {
    expect(HomeBanner.height(1100, isDesktop: true, viewportHeight: 900), 540);
    expect(HomeBanner.height(375, isDesktop: false, viewportHeight: 700), 480);
    expect(HomeBanner.height(1024, isDesktop: false, viewportHeight: 700), 480);
    // laptop 1366x768 พื้นที่หน้าเว็บราว 650: เพดาน 455 ต่ำกว่าขั้นต่ำ ใช้ 540
    expect(HomeBanner.height(1366, isDesktop: true, viewportHeight: 650), 540);
  });
}
