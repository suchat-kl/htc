class Foodtype {
  final int? id;
  final int? foodgroupID;
  final String? name;
  final int? price;
  final String? section;
  final int? sequence;

  Foodtype({
    this.id,
    this.foodgroupID = 1,
    this.name,
    this.price = 0,
    this.section,
    this.sequence = 0,
  });

  factory Foodtype.fromJson(Map<String, dynamic> json) {
    return Foodtype(
      id: json['id'] as int?,
      foodgroupID: json['foodgroupID'] as int? ?? 1,
      name: json['name'] as String?,
      price: json['price'] as int? ?? 0,
      section: json['section'] as String?,
      sequence: json['sequence'] as int? ?? 0,
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
