class CommodityIn {
  final int? commodityInTransactionID;
  final int? commodityID;
  final String? commodityName;
  final String type;
  final double qty;
  final double? balance;
  final String? date;
  final String? timestamp;
  final double price;
  final int? employeeID;
  final String? employeeName;
  final String? po;

  CommodityIn({
    this.commodityInTransactionID,
    this.commodityID,
    this.commodityName,
    this.type = "D",
    this.qty = 0.0,
    this.balance,
    this.date,
    this.timestamp,
    this.price = 0.0,
    this.employeeID,
    this.employeeName,
    this.po,
  });

  factory CommodityIn.fromJson(Map<String, dynamic> json) {
    return CommodityIn(
      commodityInTransactionID: json['commodityInTransactionID'] as int?,
      commodityID: json['commodityID'] as int?,
      commodityName: json['commodityName'] as String?,
      type: json['type'] as String? ?? 'D',
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble(),
      date: json['date'] as String?,
      timestamp: json['timestamp'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      employeeID: json['employeeID'] as int?,
      employeeName: json['employeeName'] as String?,
      po: json['po'] as String?,
    );
  }

  // In lib/models/commodity_in.dart
  Map<String, dynamic> toJson() {
    return {
      if (commodityInTransactionID != null)
        'commodityInTransactionID': commodityInTransactionID,
      'commodityID': commodityID,
      'type': type,
      'qty': qty,
      'date': date,
      'price': price,
      'employeeID': employeeID, // ✅ Must be included
      'po': po,
    };
  }

  String get typeName {
    switch (type) {
      case 'C':
        return 'จ่าย';
      case 'D':
        return 'รับ';
      default:
        return type;
    }
  }
}
