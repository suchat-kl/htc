/// ขนาดแถบภาพหัวหน้าแรก (ภาพวิวหน้าศูนย์ฯ)
///
/// แยกจาก home_screen.dart เพื่อให้เทสต์ได้โดยไม่ดึงส่วนที่ใช้ได้เฉพาะเว็บ (ฝังเพจ Facebook) มาด้วย
class HomeBanner {
  HomeBanner._();

  /// ภาพวิวแถบหัวหน้าแรก
  static const String image = 'assets/images/view.jpg';

  /// สัดส่วนกว้าง:สูงของ [image] (ไฟล์จริง 1375 x 550) เปลี่ยนภาพแล้วต้องแก้ค่านี้ด้วย
  static const double aspectRatio = 1375 / 550;

  /// ความสูงแถบที่ความกว้าง [width]: สูงตามสัดส่วนภาพ ภาพจึงแสดงเต็มทั้งรูป
  /// แต่ไม่ต่ำกว่า 540 (จอกว้าง) / 480 (จอแคบ) ให้ชื่อศูนย์ฯ และส่วนจองห้องพักใส่ได้ครบ
  /// จอที่ความสูงตามสัดส่วนต่ำกว่าขั้นต่ำ ภาพถูกตัดด้านข้างเท่านั้น
  static double height(double width, {required bool isDesktop}) {
    final floor = isDesktop ? 540.0 : 480.0;
    final byImage = width / aspectRatio;
    return byImage > floor ? byImage : floor;
  }
}
