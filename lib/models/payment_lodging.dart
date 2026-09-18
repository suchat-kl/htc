// lib/models/payment_lodging.dart

/// ค่าห้องพักของใบจองหนึ่ง แยกตามประเภทห้อง
///
/// มาจาก GET /api/auth/payment/lodging ใช้เป็นแถวในกลุ่มห้องพักของตาราง
/// สรุปค่าบริการ: [name] = รายการ, [rooms] = ห้อง, [nights] = คืน/วัน/ชั่วโมง,
/// [baht] = เงิน(บาท)
class PaymentLodging {
  final int? roomTypeId;
  final String? name;

  /// ราคาต่อคืนของประเภทห้อง
  final double price;

  /// จำนวนห้อง
  final int rooms;

  /// จำนวนคืนรวมทุกห้อง (ผลรวมของวันสิ้นสุด - วันเริ่มต้น)
  final int nights;

  /// ราคา x จำนวนคืนรวม
  final double baht;

  const PaymentLodging({
    this.roomTypeId,
    this.name,
    required this.price,
    required this.rooms,
    required this.nights,
    required this.baht,
  });

  static double _num(Object? v) => v is num ? v.toDouble() : 0;

  factory PaymentLodging.fromJson(Map<String, dynamic> json) {
    return PaymentLodging(
      roomTypeId: json['roomTypeId'] as int?,
      name: json['name'] as String?,
      price: _num(json['price']),
      rooms: (json['rooms'] as num?)?.toInt() ?? 0,
      nights: (json['nights'] as num?)?.toInt() ?? 0,
      baht: _num(json['baht']),
    );
  }
}
