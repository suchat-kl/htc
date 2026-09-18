// lib/models/payment_room_summary.dart

/// จำนวนห้องของใบจองหนึ่ง แยกตามประเภทห้อง
///
/// มาจาก GET /api/auth/payment/room-summary ใช้เติมช่อง รายการ และ ห้อง
/// ของตารางสรุปค่าบริการในหน้ารับชำระเงิน
class PaymentRoomSummary {
  /// m_roomtype.type — 'R' ห้องพัก, 'C' ห้องกิจกรรม
  final String? type;

  final int? roomTypeId;

  /// ชื่อประเภทห้อง เช่น ห้องพักธรรมดา, ห้องสัมนา 1
  final String? roomTypeName;

  /// จำนวนห้องไม่ซ้ำกันที่กำหนดในใบจองนี้
  final int rooms;

  const PaymentRoomSummary({
    this.type,
    this.roomTypeId,
    this.roomTypeName,
    required this.rooms,
  });

  factory PaymentRoomSummary.fromJson(Map<String, dynamic> json) {
    return PaymentRoomSummary(
      type: json['type'] as String?,
      roomTypeId: json['roomTypeId'] as int?,
      roomTypeName: json['roomTypeName'] as String?,
      rooms: (json['rooms'] as int?) ?? 0,
    );
  }
}
