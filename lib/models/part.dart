class Part {
  final int? partID;
  final String? name;
  final String type;
  final double stockLevel;
  final String? unit;
  final String status;
  final int sequence;

  Part({
    this.partID,
    this.name,
    this.type = "S",
    this.stockLevel = 0.0,
    this.unit,
    this.status = "1",
    this.sequence = 0,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      partID: json['partID'] as int?,
      name: json['name'] as String?,
      type: json['type'] as String? ?? 'S',
      stockLevel: (json['stockLevel'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String?,
      status: json['status'] as String? ?? '1',
      sequence: json['sequence'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (partID != null) 'partID': partID,
      'name': name,
      'type': type,
      'stockLevel': stockLevel,
      'unit': unit,
      'status': status,
      'sequence': sequence,
    };
  }

  String get typeName {
    switch (type) {
      case 'S':
        return 'Stock';
      case 'N':
        return 'Empty';
      default:
        return type;
    }
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
