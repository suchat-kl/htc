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
/// เลขตามข้อมูลจริงใน m_room (ผู้ใช้รัน SELECT ยืนยัน 3 พ.ย. 2569):
///   0 = ห้องพัก 67 ห้อง (202 ถึง 809(VIP8)), 2 = ห้องกิจกรรม 6 ห้อง (บรรยาย 1 ถึง เอนกประสงค์)
///   NULL 1 ห้อง (201) ยังไม่ได้ตั้ง ไม่มีห้องไหนใช้ 1 หรือ 3
/// อาคารอำนวยการยังไม่มีห้อง จึงตั้งเป็น 3 ใหม่ ห้องที่จะเพิ่ม (ห้องต้อนรับ ห้องสำนักงาน) ใช้เลขนี้
/// เรียงตามที่ผู้ใช้กำหนด: อาคารพัก, อาคารเรียน, อาคารอำนวยการ
class RoomBuilding {
  final int code;
  final String name;

  /// ชื่อย่อที่แสดงในตารางห้อง
  final String shortName;

  /// รหัสประเภทสถานที่ของใบแจ้งซ่อม (t_maintenance.placetype)
  final String placetype;

  const RoomBuilding(this.code, this.name, this.shortName, this.placetype);

  static const lodging = RoomBuilding(0, 'อาคารพัก', 'พัก', 'R');
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
