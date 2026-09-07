// lib/models/bookdetail.dart
class BookDetail {
  final int? bookIdDetail;
  final int? bookRoomId;
  final int? bookId;
  final int? roomId;
  final int? status;
  final String? checkIn;
  final String? checkOut;
  final String? contractName;
  final String? address;
  final String? contractTel;
  final int? numberMember;
  final String? remark;
  final String? position;
  final int? price;
  final String? roomCategory;
  final String? remarkFolio;
  final int? numberDay;
  final String? roomNo;
  final int? roomTypeId;
  final int? sequence;
  final String? startDate;
  final String? stopDate;

  BookDetail({
    this.bookIdDetail,
    this.bookRoomId,
    this.bookId,
    this.roomId,
    this.status,
    this.checkIn,
    this.checkOut,
    this.contractName,
    this.address,
    this.contractTel,
    this.numberMember,
    this.remark,
    this.position,
    this.price,
    this.roomCategory,
    this.remarkFolio,
    this.numberDay,
    this.roomNo,
    this.roomTypeId,
    this.sequence,
    this.startDate,
    this.stopDate,
  });

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
      bookIdDetail: json['bookIdDetail'] as int?,
      bookRoomId: json['bookRoomId'] as int?,
      bookId: json['bookId'] as int?,
      roomId: json['roomId'] as int?,
      status: json['status'] as int?,
      checkIn: json['checkIn'] as String?,
      checkOut: json['checkOut'] as String?,
      contractName: json['contractName'] as String?,
      address: json['address'] as String?,
      contractTel: json['contractTel'] as String?,
      numberMember: json['numberMember'] as int?,
      remark: json['remark'] as String?,
      position: json['position'] as String?,
      price: json['price'] as int?,
      roomCategory: json['roomCategory'] as String?,
      remarkFolio: json['remarkFolio'] as String?,
      numberDay: json['numberDay'] as int?,
      roomNo: json['roomNo'] as String?,
      roomTypeId: json['roomTypeId'] as int?,
      sequence: json['sequence'] as int?,
      startDate: json['startDate'] as String?,
      stopDate: json['stopDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookIdDetail': bookIdDetail,
      'bookRoomId': bookRoomId,
      'bookId': bookId,
      'roomId': roomId,
      'status': status,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'contractName': contractName,
      'address': address,
      'contractTel': contractTel,
      'numberMember': numberMember,
      'remark': remark,
      'position': position,
      'price': price,
      'roomCategory': roomCategory,
      'remarkFolio': remarkFolio,
      'numberDay': numberDay,
      'roomNo': roomNo,
      'roomTypeId': roomTypeId,
      'sequence': sequence,
      'startDate': startDate,
      'stopDate': stopDate,
    };
  }

  BookDetail copyWith({
    int? bookIdDetail,
    int? bookRoomId,
    int? bookId,
    int? roomId,
    int? status,
    String? checkIn,
    String? checkOut,
    String? contractName,
    String? address,
    String? contractTel,
    int? numberMember,
    String? remark,
    String? position,
    int? price,
    String? roomCategory,
    String? remarkFolio,
    int? numberDay,
    String? roomNo,
    int? roomTypeId,
    int? sequence,
    String? startDate,
    String? stopDate,
  }) {
    return BookDetail(
      bookIdDetail: bookIdDetail ?? this.bookIdDetail,
      bookRoomId: bookRoomId ?? this.bookRoomId,
      bookId: bookId ?? this.bookId,
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      contractName: contractName ?? this.contractName,
      address: address ?? this.address,
      contractTel: contractTel ?? this.contractTel,
      numberMember: numberMember ?? this.numberMember,
      remark: remark ?? this.remark,
      position: position ?? this.position,
      price: price ?? this.price,
      roomCategory: roomCategory ?? this.roomCategory,
      remarkFolio: remarkFolio ?? this.remarkFolio,
      numberDay: numberDay ?? this.numberDay,
      roomNo: roomNo ?? this.roomNo,
      roomTypeId: roomTypeId ?? this.roomTypeId,
      sequence: sequence ?? this.sequence,
      startDate: startDate ?? this.startDate,
      stopDate: stopDate ?? this.stopDate,
    );
  }
}