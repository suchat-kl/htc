class Roomtype {
  final int? roomtypeID;
  final String name;
  final String? type;
  final String? description;
  final String status;
  final int sequence;
  final double? price;
  final String? remark;

  Roomtype({
    this.roomtypeID,
    required this.name,
    this.type,
    this.description,
    this.status = "1",
    this.sequence = 0,
    this.price,
    this.remark,
  });

  factory Roomtype.fromJson(Map<String, dynamic> json) {
    return Roomtype(
      roomtypeID: json['roomtypeID'] as int?,
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? '1',
      sequence: json['sequence'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble(),
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (roomtypeID != null) 'roomtypeID': roomtypeID,
      'name': name,
      'type': type,
      'description': description,
      'status': status,
      'sequence': sequence,
      'price': price,
      'remark': remark,
    };
  }

  // ✅ Hardcoded type names
  String get typeName {
    switch (type) {
      case 'R':
        return 'Room';
      case 'C':
        return 'Conference';
      default:
        return type ?? '-';
    }
  }

  // ✅ Hardcoded status names
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
