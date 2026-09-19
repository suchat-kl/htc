// lib/models/payment_activity.dart

/// ค่าห้องกิจกรรมของใบจองหนึ่ง แยกตามประเภทห้อง
///
/// มาจาก GET /api/auth/payment/activity ใช้เป็นแถวในกลุ่มห้องกิจกรรมของตาราง
/// สรุปค่าบริการ: [name] = รายการ, [rooms] = ห้อง, [units] = คืน/วัน/ชั่วโมง,
/// [baht] = เงิน(บาท)
///
/// [units] เป็นทศนิยมได้ เพราะช่วง 08:00-16:00 นับ 1 วัน ส่วนช่วงอื่นนับ 0.5
class PaymentActivity {
  final int? roomTypeId;
  final String? name;

  /// จำนวนห้องไม่ซ้ำกัน
  final int rooms;

  /// จำนวนวันรวม
  final double units;

  /// ราคา x จำนวนวัน รวมทุกช่วงเวลา
  final double baht;

  const PaymentActivity({
    this.roomTypeId,
    this.name,
    required this.rooms,
    required this.units,
    required this.baht,
  });

  static double _num(Object? v) => v is num ? v.toDouble() : 0;

  factory PaymentActivity.fromJson(Map<String, dynamic> json) {
    return PaymentActivity(
      roomTypeId: json['roomTypeId'] as int?,
      name: json['name'] as String?,
      rooms: (json['rooms'] as num?)?.toInt() ?? 0,
      units: _num(json['units']),
      baht: _num(json['baht']),
    );
  }
}
