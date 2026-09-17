// lib/models/room_type_option.dart

/// ตัวเลือกประเภทห้องสำหรับช่องค้นหา — มาจาก GET /api/auth/room-search/room-types
///
/// ค่าที่ส่งไปค้นหาคือ [roomTypeId] ส่วนข้อความที่แสดงคือ [name]
class RoomTypeOption {
  final int roomTypeId;
  final String name;

  const RoomTypeOption({required this.roomTypeId, required this.name});

  factory RoomTypeOption.fromJson(Map<String, dynamic> json) {
    return RoomTypeOption(
      roomTypeId: json['roomTypeId'] as int,
      name: (json['name'] as String?) ?? '-',
    );
  }
}
