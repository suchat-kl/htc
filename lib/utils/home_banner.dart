/// ขนาดแถบภาพหัวหน้าแรก (ภาพวิวหน้าศูนย์ฯ)
///
/// แยกจาก home_screen.dart เพื่อให้เทสต์ได้โดยไม่ดึงส่วนที่ใช้ได้เฉพาะเว็บ (ฝังเพจ Facebook) มาด้วย
class HomeBanner {
  HomeBanner._();

  /// ภาพวิวแถบหัวหน้าแรก
  static const String image = 'assets/images/view.jpg';

  /// สัดส่วนกว้าง:สูงของ [image] (ไฟล์จริง 1375 x 550) เปลี่ยนภาพแล้วต้องแก้ค่านี้ด้วย
  static const double aspectRatio = 1375 / 550;

  /// แถบภาพสูงได้ไม่เกินสัดส่วนนี้ของความสูงหน้าต่าง
  /// เหลือที่ให้เห็นส่วนประกาศใต้ภาพโดยไม่ต้องเลื่อน (จอ Full HD แถบสูงราว 650 แทน 768)
  static const double maxViewportFraction = 0.7;

  /// ความสูงแถบที่ความกว้าง [width] และความสูงหน้าต่าง [viewportHeight]
  ///
  /// - ปกติสูงตามสัดส่วนภาพ ภาพจึงแสดงเต็มทั้งรูป (จอกว้างราว 1350 ถึงราว 1.75 เท่าของความสูงหน้าต่าง)
  /// - ไม่เกิน [maxViewportFraction] ของความสูงหน้าต่าง จอกว้างมากจึงถูกตัดภาพบน-ล่างบ้าง
  ///   แลกกับให้ส่วนประกาศยังอยู่ในจอแรก
  /// - ไม่ต่ำกว่า 540 (จอกว้าง) / 480 (จอแคบ) ให้ชื่อศูนย์ฯ และส่วนจองห้องพักใส่ได้ครบ
  ///   ค่าต่ำสุดชนะเพดานเสมอ จอที่ต่ำกว่าค่าต่ำสุดภาพถูกตัดด้านข้าง
  static double height(
    double width, {
    required bool isDesktop,
    required double viewportHeight,
  }) {
    final floor = isDesktop ? 540.0 : 480.0;
    final cap = viewportHeight * maxViewportFraction;
    var h = width / aspectRatio;
    if (h > cap) h = cap;
    return h > floor ? h : floor;
  }
}
