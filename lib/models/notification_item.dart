/// ประกาศประชาสัมพันธ์หนึ่งรายการ
///
/// ตั้งชื่อคลาสว่า NotificationItem ไม่ใช่ Notification
/// เพราะชนกับ Notification ของ Flutter เองที่ใช้กับ NotificationListener
class NotificationItem {
  final int? id;
  final String? title;
  final String? message;

  /// รูปแบบ yyyy-MM-dd ตามที่ backend ส่งมา ว่างได้
  final String? startDate;
  final String? stopDate;

  final int? sequence;

  /// '1' = ใช้งาน, '2' = ไม่ใช้งาน
  final String? status;

  final String? createdBy;

  /// ช่วงวันที่แบบอ่านง่ายที่ backend เตรียมมาให้ เช่น "1 ต.ค. 68 - 30 ก.ย. 69"
  final String? periodLabel;

  const NotificationItem({
    this.id,
    this.title,
    this.message,
    this.startDate,
    this.stopDate,
    this.sequence = 0,
    this.status = '1',
    this.createdBy,
    this.periodLabel,
  });

  /// ยังเปิดใช้งานอยู่หรือไม่ null ถือว่าใช้งาน เหมือนตารางหลักอื่นในระบบ
  bool get isActive => status == null || status == '1';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int?,
      title: json['title'] as String?,
      message: json['message'] as String?,
      startDate: json['startDate'] as String?,
      stopDate: json['stopDate'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      status: json['status'] as String? ?? '1',
      createdBy: json['createdBy'] as String?,
      periodLabel: json['periodLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'message': message,
      'startDate': startDate,
      'stopDate': stopDate,
      'sequence': sequence,
      'status': status,
    };
  }
}
