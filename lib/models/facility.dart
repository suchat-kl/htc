class Facility {
  final int? facilityID;
  final String name;
  final String? description;
  final String status;
  final int sequence;
  // final String type;
  // final double stockLevel;

  Facility({
    this.facilityID,
    required this.name,
    this.description,
    this.status = "1",
    this.sequence = 0,
    // this.type = "B",
    // this.stockLevel = 0.0,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      facilityID: json['facilityID'] as int?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? '1',
      sequence: json['sequence'] as int? ?? 0,
      // type: json['type'] as String? ?? 'B',
      // stockLevel: (json['stockLevel'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (facilityID != null) 'facilityID': facilityID,
      'name': name,
      'description': description,
      'status': status,
      'sequence': sequence,
      // 'type': type,
      // 'stockLevel': stockLevel,
    };
  }

  // String get typeName {
  //   switch (type) {
  //     case 'B':
  //       return 'เครื่องนอน';
  //     case 'C':
  //       return 'ของใช้';
  //     default:
  //       return type;
  //   }
  // }

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
