// lib/models/room_assignment.dart

/// หนึ่งแถวของรายการกำหนดห้องในใบจอง — ห้องพัก (type 'R') หรือห้องกิจกรรม (type 'C')
///
/// มาจาก GET /api/auth/bookdetails/room-assignments — ใช้แสดงผลอย่างเดียว
/// status เป็นรหัสตัวเลข ส่วน statusName คือชื่อสถานะที่ backend แปลงมาให้แล้ว
class RoomAssignment {
  /// PK ของ bookdetail — ใช้อ้างถึงแถวตอนลบ
  final int? bookIdDetail;

  /// คอลัมน์ NOT NULL ของ bookdetail — ส่งกลับไปพร้อม update ให้ครบ
  final int? bookRoomId;
  final int? bookId;
  final int? roomId;

  final int? sequence;
  final String? roomNo;

  /// ชื่อ-สกุลผู้เข้าพักคนที่หนึ่ง (คอลัมน์ contractname)
  final String? contractName;

  /// ชื่อ-สกุลผู้เข้าพักคนที่สอง (คอลัมน์ contractname2) — ห้องหนึ่งพักได้ 2 คน
  final String? contractName2;

  /// เบอร์ติดต่อ — เลิกแสดงในหน้ากำหนดห้องแล้ว คงไว้ส่งค่าเดิมกลับตอนบันทึก
  final String? contractTel;
  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd
  final int? status;
  final String? statusName;

  /// ช่วงเวลาที่ใช้ห้อง (t_schedule) — มีเฉพาะห้องกิจกรรม ห้องพักเป็นรายการว่าง
  final List<AssignmentTimeSlot> timeSlots;

  RoomAssignment({
    this.bookIdDetail,
    this.bookRoomId,
    this.bookId,
    this.roomId,
    this.sequence,
    this.roomNo,
    this.contractName,
    this.contractName2,
    this.contractTel,
    this.startDate,
    this.stopDate,
    this.status,
    this.statusName,
    this.timeSlots = const [],
  });

  factory RoomAssignment.fromJson(Map<String, dynamic> json) {
    return RoomAssignment(
      bookIdDetail: json['bookIdDetail'] as int?,
      bookRoomId: json['bookRoomId'] as int?,
      bookId: json['bookId'] as int?,
      roomId: json['roomId'] as int?,
      sequence: json['sequence'] as int?,
      roomNo: json['roomNo'] as String?,
      contractName: json['contractName'] as String?,
      contractName2: json['contractName2'] as String?,
      contractTel: json['contractTel'] as String?,
      startDate: json['startDate'] as String?,
      stopDate: json['stopDate'] as String?,
      status: json['status'] as int?,
      statusName: json['statusName'] as String?,
      timeSlots: (json['timeSlots'] as List? ?? const [])
          .map((j) => AssignmentTimeSlot.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// สถานะห้องที่ปุ่ม check in / check out ในหน้ากำหนดห้องใช้ — มีแค่ 2 สถานะ
///
/// ตาราง statuscheck แก้ไขได้จากหน้า "สถานะห้องพัก" จึงหารหัสจากชื่อ ไม่ผูกเลขตายตัว
/// เทียบแบบไม่สนตัวพิมพ์และช่องว่าง: "check in" กับ "check out แล้ว"
/// (ถ้าไม่มี "check out แล้ว" ใช้ "check out" แทน) สถานะอื่นของข้อมูลเก่า
/// เช่น "รอ check out" ยังแสดงชื่อได้ตามเดิม แต่ปุ่มถือว่ายังไม่ได้ check in
class RoomCheckStatus {
  final int? checkIn;
  final int? checkOut;

  const RoomCheckStatus({this.checkIn, this.checkOut});

  static String _norm(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// หารหัสสองสถานะจากรายการ statuscheck (คู่ status + name)
  factory RoomCheckStatus.from(Iterable<({int? status, String? name})> list) {
    int? find(String target) {
      for (final s in list) {
        if (s.status != null && _norm(s.name) == target) return s.status;
      }
      return null;
    }

    return RoomCheckStatus(
      checkIn: find('checkin'),
      checkOut: find('checkoutแล้ว') ?? find('checkout'),
    );
  }

  /// ใช้ปุ่มได้เมื่อหาได้ครบทั้งสองสถานะ
  bool get ready => checkIn != null && checkOut != null && checkIn != checkOut;

  bool isCheckedIn(int? status) => status != null && status == checkIn;
  bool isCheckedOut(int? status) => status != null && status == checkOut;
}

/// หนึ่งช่วงเวลาที่ใช้ห้องกิจกรรมในหนึ่งวัน เวลาเป็นตัวเลขแบบในฐาน (800 = 08:00)
class AssignmentTimeSlot {
  final String? date; // yyyy-MM-dd
  final int? fromTime;
  final int? toTime;

  const AssignmentTimeSlot({this.date, this.fromTime, this.toTime});

  factory AssignmentTimeSlot.fromJson(Map<String, dynamic> json) {
    return AssignmentTimeSlot(
      date: json['date']?.toString(),
      fromTime: (json['fromTime'] as num?)?.toInt(),
      toTime: (json['toTime'] as num?)?.toInt(),
    );
  }
}
