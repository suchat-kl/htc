// lib/utils/fiscal_year.dart

/// ตัวช่วยเรื่องปีงบประมาณไทย
///
/// ปีงบประมาณ = 1 ตุลาคม ของปีก่อน ถึง 30 กันยายน ของปีที่เอามาตั้งชื่อ
/// เช่น ปีงบประมาณ 2569 คือ 1 ต.ค. 2568 ถึง 30 ก.ย. 2569
///
/// กับดักที่เจอบ่อยคือเอาปี พ.ศ. ไปลบ 543 แล้วใช้เป็นปีเริ่มต้นตรง ๆ
/// ซึ่งจะได้ปีสิ้นสุด ไม่ใช่ปีเริ่ม
class FiscalYear {
  const FiscalYear._();

  static const List<String> _monthNames = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  /// ปีงบประมาณ พ.ศ. ของวันที่ที่ระบุ ไม่ระบุคือวันนี้
  ///
  /// ตั้งแต่ 1 ต.ค. เป็นต้นไปถือเป็นปีงบประมาณถัดไปแล้ว
  static int current([DateTime? at]) {
    final d = at ?? DateTime.now();
    final be = d.year + 543;
    return d.month >= 10 ? be + 1 : be;
  }

  /// วันแรกของปีงบประมาณ (ค.ศ.)
  static DateTime start(int buddhistYear) =>
      DateTime(buddhistYear - 543 - 1, 10, 1);

  /// วันสุดท้ายของปีงบประมาณ (ค.ศ.)
  static DateTime end(int buddhistYear) => DateTime(buddhistYear - 543, 9, 30);

  /// ข้อความช่วงวันที่แบบเต็ม เช่น "1 ตุลาคม 2568 ถึง 30 กันยายน 2569"
  static String rangeLabel(int buddhistYear) {
    final s = start(buddhistYear);
    final e = end(buddhistYear);
    return '${s.day} ${_monthNames[s.month - 1]} ${s.year + 543}'
        ' ถึง ${e.day} ${_monthNames[e.month - 1]} ${e.year + 543}';
  }
}
