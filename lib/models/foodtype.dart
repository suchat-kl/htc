class Foodtype {
  final int? id;
  final int? foodgroupID;
  final String? name;
  final int? price;
  final String? section;
  final int? sequence;

  /// ข้อ 16 ของความต้องการปรับปรุง '1' = ให้บริการ, '2' = เลิกให้บริการ
  /// null คือข้อมูลเก่าก่อนมีคอลัมน์นี้ ถือว่ายังให้บริการ
  final String? status;

  Foodtype({
    this.id,
    this.foodgroupID = 1,
    this.name,
    this.price = 0,
    this.section,
    this.sequence = 0,
    this.status,
  });

  /// ยังให้บริการอยู่หรือไม่ ใช้ตัดสินว่าจะให้เลือกตอนจองไหม
  bool get isActive => status == null || status == '1';

  factory Foodtype.fromJson(Map<String, dynamic> json) {
    return Foodtype(
      id: json['id'] as int?,
      foodgroupID: json['foodgroupID'] as int? ?? 1,
      name: json['name'] as String?,
      price: json['price'] as int? ?? 0,
      section: json['section'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'foodgroupID': foodgroupID,
      'name': name,
      'price': price,
      'section': section,
      'sequence': sequence,
      if (status != null) 'status': status,
    };
  }

  String get foodgroupName {
    switch (foodgroupID) {
      case 1:
        return 'อาหารหลัก';
      case 2:
        return 'อาหารว่างและเครื่องดื่ม';
      default:
        return 'ไม่ระบุ';
    }
  }
}
