// lib/models/schedule.dart
//
// ตารางการใช้ห้อง (dbo.t_schedule)
// composite key คือ roomID + scheduleDate + fromTime + toTime
// ไม่มี id เดี่ยว ทุกคำสั่งที่อ้างถึงรายการเดียวจึงต้องส่งครบทั้งสี่ค่า
class Schedule {
  final int? roomID;

  /// คอลัมน์ date ในฐานข้อมูล — รูปแบบ yyyy-MM-dd
  final String? scheduleDate;

  /// คอลัมน์ time
  final int? fromTime;

  /// คอลัมน์ totime
  final int? toTime;

  final int? bookingReservationId;
  final String? reservationStatus;
  final String? cleaningStatus;
  final int? roomIdChange;
  final String? remarkChange;
  final double? price;
  final String? remark;

  const Schedule({
    this.roomID,
    this.scheduleDate,
    this.fromTime,
    this.toTime,
    this.bookingReservationId,
    this.reservationStatus,
    this.cleaningStatus,
    this.roomIdChange,
    this.remarkChange,
    this.price,
    this.remark,
  });

  static Object? _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) return j[k];
    }
    return null;
  }

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _double(Object? v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _str(Object? v) => v?.toString();

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      roomID: _int(_pick(json, ['roomID', 'roomId', 'roomid'])),
      scheduleDate: _str(_pick(json, ['scheduleDate', 'date'])),
      fromTime: _int(_pick(json, ['fromTime', 'time'])),
      toTime: _int(_pick(json, ['toTime', 'totime'])),
      bookingReservationId: _int(
        _pick(json, ['bookingReservationId', 'bookingreservationid']),
      ),
      reservationStatus: _str(
        _pick(json, ['reservationStatus', 'reservation_status']),
      ),
      cleaningStatus: _str(
        _pick(json, ['cleaningStatus', 'cleaning_status']),
      ),
      roomIdChange: _int(_pick(json, ['roomIdChange', 'roomidchange'])),
      remarkChange: _str(_pick(json, ['remarkChange', 'remarkchange'])),
      price: _double(_pick(json, ['price'])),
      remark: _str(_pick(json, ['remark'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomID': roomID,
      'scheduleDate': scheduleDate,
      'fromTime': fromTime,
      'toTime': toTime,
      'bookingReservationId': bookingReservationId,
      'reservationStatus': reservationStatus,
      'cleaningStatus': cleaningStatus,
      'roomIdChange': roomIdChange,
      'remarkChange': remarkChange,
      'price': price,
      'remark': remark,
    };
  }

  Schedule copyWith({
    int? roomID,
    String? scheduleDate,
    int? fromTime,
    int? toTime,
    int? bookingReservationId,
    String? reservationStatus,
    String? cleaningStatus,
    int? roomIdChange,
    String? remarkChange,
    double? price,
    String? remark,
  }) {
    return Schedule(
      roomID: roomID ?? this.roomID,
      scheduleDate: scheduleDate ?? this.scheduleDate,
      fromTime: fromTime ?? this.fromTime,
      toTime: toTime ?? this.toTime,
      bookingReservationId: bookingReservationId ?? this.bookingReservationId,
      reservationStatus: reservationStatus ?? this.reservationStatus,
      cleaningStatus: cleaningStatus ?? this.cleaningStatus,
      roomIdChange: roomIdChange ?? this.roomIdChange,
      remarkChange: remarkChange ?? this.remarkChange,
      price: price ?? this.price,
      remark: remark ?? this.remark,
    );
  }
}
