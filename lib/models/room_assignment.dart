// lib/models/room_assignment.dart

/// หนึ่งแถวของรายการกำหนดห้องพักในใบจอง
///
/// มาจาก GET /api/auth/bookdetails/room-assignments — ใช้แสดงผลอย่างเดียว
/// status เป็นรหัสตัวเลข ส่วน statusName คือชื่อสถานะที่ backend แปลงมาให้แล้ว
class RoomAssignment {
  final int? sequence;
  final String? roomNo;
  final String? contractName;
  final String? contractTel;
  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd
  final int? status;
  final String? statusName;

  RoomAssignment({
    this.sequence,
    this.roomNo,
    this.contractName,
    this.contractTel,
    this.startDate,
    this.stopDate,
    this.status,
    this.statusName,
  });

  factory RoomAssignment.fromJson(Map<String, dynamic> json) {
    return RoomAssignment(
      sequence: json['sequence'] as int?,
      roomNo: json['roomNo'] as String?,
      contractName: json['contractName'] as String?,
      contractTel: json['contractTel'] as String?,
      startDate: json['startDate'] as String?,
      stopDate: json['stopDate'] as String?,
      status: json['status'] as int?,
      statusName: json['statusName'] as String?,
    );
  }
}
