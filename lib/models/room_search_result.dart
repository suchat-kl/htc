// lib/models/room_search_result.dart

/// หนึ่งแถวของผลค้นหาห้อง — มาจาก GET /api/auth/room-search
///
/// ใช้แสดงผลอย่างเดียว bookId ไม่ได้แสดงในตาราง แต่ใช้เปิดหน้ารายละเอียดการจอง
class RoomSearchResult {
  final String? roomNo;

  /// ชื่อประเภทห้อง (m_roomtype.name)
  final String? roomTypeName;

  final String? contractName1;
  final String? contractNumber1;
  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd
  final int? status;

  /// ชื่อสถานะ (statuscheck.name)
  final String? statusName;

  final String? departmentName;
  final String? bookTitle;
  final int? bookId;

  const RoomSearchResult({
    this.roomNo,
    this.roomTypeName,
    this.contractName1,
    this.contractNumber1,
    this.startDate,
    this.stopDate,
    this.status,
    this.statusName,
    this.departmentName,
    this.bookTitle,
    this.bookId,
  });

  factory RoomSearchResult.fromJson(Map<String, dynamic> json) {
    return RoomSearchResult(
      roomNo: json['roomNo'] as String?,
      roomTypeName: json['roomTypeName'] as String?,
      contractName1: json['contractName1'] as String?,
      contractNumber1: json['contractNumber1'] as String?,
      startDate: json['startDate'] as String?,
      stopDate: json['stopDate'] as String?,
      status: json['status'] as int?,
      statusName: json['statusName'] as String?,
      departmentName: json['departmentName'] as String?,
      bookTitle: json['bookTitle'] as String?,
      bookId: json['bookId'] as int?,
    );
  }
}
