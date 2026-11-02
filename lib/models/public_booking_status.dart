/// สถานะใบจองที่ผู้จองตรวจเองโดยไม่ต้องล็อกอิน (เลขใบจอง + เลขบัตรประชาชน)
///
/// backend ส่งมาแค่สถานะกับช่วงวันที่ ไม่มีชื่อ เบอร์โทร หรือรายละเอียดอื่นของใบจอง
class PublicBookingStatus {
  final int bookId;

  /// A = กองฝึก, B = หน่วยราชการอื่น, C = รายย่อย
  final String? bookingtype;
  final int? statusId;
  final String statusName;
  final DateTime? startdate;
  final DateTime? stopdate;

  /// ชำระเงินผ่านหน้าเว็บได้ (ใบ Pay-in / แนบหลักฐาน) — รายย่อยเท่านั้น
  final bool onlinePayment;

  const PublicBookingStatus({
    required this.bookId,
    this.bookingtype,
    this.statusId,
    this.statusName = '',
    this.startdate,
    this.stopdate,
    this.onlinePayment = false,
  });

  factory PublicBookingStatus.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return PublicBookingStatus(
      bookId: (json['bookId'] as num).toInt(),
      bookingtype: json['bookingtype'] as String?,
      statusId: (json['statusId'] as num?)?.toInt(),
      statusName: (json['statusName'] as String?) ?? '',
      startdate: date(json['startdate']),
      stopdate: date(json['stopdate']),
      onlinePayment: json['onlinePayment'] == true,
    );
  }

  String get bookingtypeName => switch (bookingtype) {
    'A' => 'กองฝึก กรมทางหลวง',
    'B' => 'หน่วยราชการอื่น',
    'C' => 'รายย่อย',
    _ => '-',
  };
}
