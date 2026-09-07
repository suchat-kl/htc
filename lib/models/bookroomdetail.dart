// lib/models/bookroomdetail.dart
class BookRoomDetail {
  final int? bookRoomId;
  final int? bookId;
  final int? roomTypeId;
  final int? numberMember;
  final int? numberRoom;
  final String? status;
  final int? price;
  final int? sequence;
  final String? startDate;
  final String? stopDate;
  final String? name;

  BookRoomDetail({
    this.bookRoomId,
    this.bookId,
    this.roomTypeId,
    this.numberMember,
    this.numberRoom,
    this.status,
    this.price,
    this.sequence,
    this.startDate,
    this.stopDate,
    this.name,
  });

  /// อ่านค่าจาก key แรกที่เจอ — endpoint by-bookidtype ฝั่ง Spring ใช้ native
  /// query ซึ่งอาจส่งชื่อคอลัมน์ (ตัวพิมพ์เล็ก) กลับมาแทนชื่อ field แบบ camelCase
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

  static String? _str(Object? v) => v?.toString();

  factory BookRoomDetail.fromJson(Map<String, dynamic> json) {
    return BookRoomDetail(
      bookRoomId: _int(_pick(json, ['bookRoomId', 'bookroomid', 'BookRoomId'])),
      bookId: _int(_pick(json, ['bookId', 'bookid', 'BookId'])),
      roomTypeId: _int(
        _pick(json, ['roomTypeId', 'roomtypeid', 'RoomTypeId']),
      ),
      numberMember: _int(
        _pick(json, ['numberMember', 'numbermember', 'NumberMember']),
      ),
      numberRoom: _int(
        _pick(json, ['numberRoom', 'numberroom', 'NumberRoom']),
      ),
      status: _str(_pick(json, ['status', 'Status'])),
      price: _int(_pick(json, ['price', 'Price'])),
      sequence: _int(_pick(json, ['sequence', 'Sequence'])),
      startDate: _str(_pick(json, ['startDate', 'startdate', 'StartDate'])),
      stopDate: _str(_pick(json, ['stopDate', 'stopdate', 'StopDate'])),
      name: _str(_pick(json, ['name', 'Name'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookRoomId': bookRoomId,
      'bookId': bookId,
      'roomTypeId': roomTypeId,
      'numberMember': numberMember,
      'numberRoom': numberRoom,
      'status': status,
      'price': price,
      'sequence': sequence,
      'startDate': startDate,
      'stopDate': stopDate,
    };
  }

  BookRoomDetail copyWith({
    int? bookRoomId,
    int? bookId,
    int? roomTypeId,
    int? numberMember,
    int? numberRoom,
    String? status,
    int? price,
    int? sequence,
    String? startDate,
    String? stopDate,
    String? name,
  }) {
    return BookRoomDetail(
      bookRoomId: bookRoomId ?? this.bookRoomId,
      bookId: bookId ?? this.bookId,
      roomTypeId: roomTypeId ?? this.roomTypeId,
      numberMember: numberMember ?? this.numberMember,
      numberRoom: numberRoom ?? this.numberRoom,
      status: status ?? this.status,
      price: price ?? this.price,
      sequence: sequence ?? this.sequence,
      startDate: startDate ?? this.startDate,
      stopDate: stopDate ?? this.stopDate,
      // เดิมตกหล่นไป ทำให้ชื่อประเภทห้องหายทุกครั้งที่ copyWith
      name: name ?? this.name,
    );
  }
}