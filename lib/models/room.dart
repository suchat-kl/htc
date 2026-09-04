class Room {
  final int? roomID;
  final String roomNO;
  final int? roomTypeID;
  final String? roomTypeName;
  final int? building;
  final int? floor;
  final int sequence;
  final String status;

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
