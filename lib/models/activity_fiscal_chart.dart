/// ข้อมูลกราฟการใช้ห้องกิจกรรมทั้งปีงบประมาณ
/// มาจาก GET /api/auth/report/activity-fiscal-chart/data
class ActivityFiscalChart {
  /// ปีงบประมาณ พ.ศ.
  final int fiscalYear;

  /// ช่วงเวลาแบบอ่านง่าย เช่น "1 ต.ค. 68 - 30 ก.ย. 69"
  final String periodLabel;

  /// 12 เดือน เรียงจาก ต.ค. ถึง ก.ย.
  final List<ActivityFiscalPoint> months;

  final int totalBookings;
  final int totalPeople;

  const ActivityFiscalChart({
    this.fiscalYear = 0,
    this.periodLabel = '',
    this.months = const [],
    this.totalBookings = 0,
    this.totalPeople = 0,
  });

  factory ActivityFiscalChart.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return ActivityFiscalChart(
      fiscalYear: asInt(json['fiscalYear']),
      periodLabel: json['periodLabel'] as String? ?? '',
      months: (json['months'] as List? ?? const [])
          .map((e) => ActivityFiscalPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalBookings: asInt(json['totalBookings']),
      totalPeople: asInt(json['totalPeople']),
    );
  }

  /// ค่าสูงสุดของชุดข้อมูล ใช้กำหนดความสูงของแกนตั้ง
  /// คืน 1 เมื่อไม่มีข้อมูลเลย กันหารด้วยศูนย์ตอนวาดกราฟ
  int maxOf(bool people) {
    var max = 0;
    for (final m in months) {
      final v = people ? m.people : m.bookings;
      if (v > max) max = v;
    }
    return max == 0 ? 1 : max;
  }
}

/// ยอดของหนึ่งเดือนในปีงบประมาณ
class ActivityFiscalPoint {
  /// เลขเดือนตามปฏิทิน 1-12
  final int month;

  /// ปี พ.ศ. ของเดือนนั้น (ต.ค.-ธ.ค. เป็นปีก่อนหน้าปีงบประมาณ)
  final int buddhistYear;

  /// ชื่อย่อสำหรับแกนนอน เช่น "ต.ค. 68"
  final String label;

  final int bookings;
  final int people;

  const ActivityFiscalPoint({
    this.month = 0,
    this.buddhistYear = 0,
    this.label = '',
    this.bookings = 0,
    this.people = 0,
  });

  factory ActivityFiscalPoint.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    return ActivityFiscalPoint(
      month: asInt(json['month']),
      buddhistYear: asInt(json['buddhistYear']),
      label: json['label'] as String? ?? '',
      bookings: asInt(json['bookings']),
      people: asInt(json['people']),
    );
  }
}
