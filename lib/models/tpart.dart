class Tpart {
  final int? tpartID;
  final int? partid;
  final String? partName;
  final String? type;
  final double? qty;
  final double? balance;
  final String? date;
  final String? place;
  final double? price;
  final int? employeeid;
  final String? employeeName;
  final String? po;
  final int? maintenanceid;
  final String? maintenanceInfo;
  final String? remark;
  final String? timestamp;

  Tpart({
    this.tpartID,
    this.partid,
    this.partName,
    this.type,
    this.qty,
    this.balance,
    this.date,
    this.place,
    this.price,
    this.employeeid,
    this.employeeName,
    this.po,
    this.maintenanceid,
    this.maintenanceInfo,
    this.remark,
    this.timestamp,
  });

  factory Tpart.fromJson(Map<String, dynamic> json) {
    return Tpart(
      tpartID: json['tpartID'] as int?,
      partid: json['partid'] as int?,
      partName: json['partName'] as String?,
      type: json['type'] as String? ?? 'D',
      qty: (json['qty'] as num?)?.toDouble(),
      balance: (json['balance'] as num?)?.toDouble(),
      date: json['date'] as String?,
      place: json['place'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      employeeid: json['employeeid'] as int?,
      employeeName: json['employeeName'] as String?,
      po: json['po'] as String?,
      maintenanceid: json['maintenanceid'] as int?,
      maintenanceInfo: json['maintenanceInfo'] as String?,
      remark: json['remark'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tpartID != null) 'tpartID': tpartID,
      'partid': partid,
      'type': type,
      'qty': qty,
      'date': date,
      'place': place,
      'price': price,
      'employeeid': employeeid,
      'po': po,
      'maintenanceid': maintenanceid,
      'remark': remark,
    };
  }

  String get typeName =>
      type == 'C' ? 'จ่าย' : (type == 'D' ? 'รับ' : (type ?? ''));
}
