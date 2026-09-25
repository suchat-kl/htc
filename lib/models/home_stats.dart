/// ตัวเลขสรุปที่แสดงบนหน้าแรก มาจาก GET /api/auth/home-stats
///
/// เรียกได้โดยไม่ต้องล็อกอิน เพราะหน้าแรกเป็นหน้าสาธารณะ
class HomeStats {
  /// ห้องพักที่เปิดใช้งานทั้งหมด
  final int lodgingTotal;

  /// ห้องพักที่ยังว่างในวันนี้
  final int lodgingFree;

  /// ห้องกิจกรรมที่เปิดใช้งานทั้งหมด
  final int activityTotal;

  /// ห้องกิจกรรมที่ยังว่างในวันนี้
  final int activityFree;

  /// ใบจองที่เริ่มเข้าพักในเดือนนี้ ไม่นับใบที่ยกเลิก
  final int bookingsThisMonth;

  /// ชื่อเดือนภาษาไทย เช่น "กันยายน 2569"
  final String monthLabel;

  /// วันที่ของข้อมูล เช่น "25 กันยายน 2569"
  final String asOfDate;

  const HomeStats({
    this.lodgingTotal = 0,
    this.lodgingFree = 0,
    this.activityTotal = 0,
    this.activityFree = 0,
    this.bookingsThisMonth = 0,
    this.monthLabel = '',
    this.asOfDate = '',
  });

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return HomeStats(
      lodgingTotal: asInt(json['lodgingTotal']),
      lodgingFree: asInt(json['lodgingFree']),
      activityTotal: asInt(json['activityTotal']),
      activityFree: asInt(json['activityFree']),
      bookingsThisMonth: asInt(json['bookingsThisMonth']),
      monthLabel: json['monthLabel'] as String? ?? '',
      asOfDate: json['asOfDate'] as String? ?? '',
    );
  }
}
