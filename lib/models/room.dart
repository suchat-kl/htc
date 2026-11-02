class Room {
  final int? roomID;
  final String roomNO;
  final int? roomTypeID;
  final String? roomTypeName;
  final int? building;
  final int? floor;
  final int sequence;
  final String status;

  /// ชื่อย่ออาคาร (พัก / เรียน / office)
  String get buildingShortName => RoomBuilding.shortNameOf(building);

  Room({
    this.roomID,
    required this.roomNO,
    this.roomTypeID,
    this.roomTypeName,
    this.building,
    this.floor,
    this.sequence = 0,
    this.status = "1",
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomID: json['roomID'] as int?,
      roomNO: json['roomNO'] as String? ?? '',
      roomTypeID: json['roomTypeID'] as int?,
      roomTypeName: json['roomTypeName'] as String?,
      building: json['building'] as int?,
      floor: json['floor'] as int?,
      sequence: json['sequence'] as int? ?? 0,
      status: json['status'] as String? ?? '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (roomID != null) 'roomID': roomID,
      'roomNO': roomNO,
      'roomTypeID': roomTypeID,
      'building': building,
      'floor': floor,
      'sequence': sequence,
      'status': status,
    };
  }

  String get statusName {
    switch (status) {
      case '1':
        return 'ใช้งาน';
      case '2':
        return 'ไม่ใช้งาน';
      default:
        return status;
    }
  }
}

/// อาคารที่ห้องตั้งอยู่ — m_room.building เก็บเป็นตัวเลข
///
/// ใช้ทั้งหน้าห้อง (ตัวเลือก "ตึก") และหน้าแจ้งซ่อม (เลือกอาคารแล้วกรองห้อง)
/// หน้าแจ้งซ่อมเก็บอาคารเป็นรหัสตัวอักษรใน t_maintenance.placetype
/// (R = อาคารพัก, C = อาคารเรียน, O = อาคารอำนวยการ ตาม MaintenanceCodes ฝั่ง backend)
/// จึงผูกสองรหัสไว้ที่เดียวกันตรงนี้
///
/// **เลข 1, 2, 3 เป็นค่าที่ตั้งขึ้นใหม่** ยังไม่ได้เทียบกับค่า building ที่ย้ายมาจาก
/// ระบบเดิม ถ้าข้อมูลจริงใช้เลขอื่น ให้แก้ที่นี่ที่เดียว แล้วแก้ข้อมูล m_room ให้ตรง
/// เรียงตามที่ผู้ใช้กำหนด: อาคารพัก, อาคารเรียน, อาคารอำนวยการ
class RoomBuilding {
  final int code;
  final String name;

  /// ชื่อย่อที่แสดงในตารางห้อง
  final String shortName;

  /// รหัสประเภทสถานที่ของใบแจ้งซ่อม (t_maintenance.placetype)
  final String placetype;

  const RoomBuilding(this.code, this.name, this.shortName, this.placetype);

  static const lodging = RoomBuilding(1, 'อาคารพัก', 'พัก', 'R');
  static const school = RoomBuilding(2, 'อาคารเรียน', 'เรียน', 'C');
  static const office = RoomBuilding(3, 'อาคารอำนวยการ', 'office', 'O');

  static const List<RoomBuilding> all = [lodging, school, office];

  /// อาคารจากเลขใน m_room.building ไม่รู้จัก = null
  static RoomBuilding? of(int? code) {
    for (final b in all) {
      if (b.code == code) return b;
    }
    return null;
  }

  /// อาคารจากรหัส placetype ของใบแจ้งซ่อม ไม่รู้จัก = null
  static RoomBuilding? ofPlacetype(String? placetype) {
    for (final b in all) {
      if (b.placetype == placetype) return b;
    }
    return null;
  }

  /// ชื่อย่อของเลขอาคาร เลขที่ไม่รู้จักแสดงเป็น "ตึก n" เพื่อไม่ให้ข้อมูลเดิมหาย
  static String shortNameOf(int? code) {
    if (code == null) return '-';
    return of(code)?.shortName ?? 'ตึก $code';
  }
}
