class RoomtypeCommodity {
  final int roomTypeID;
  final int commodityID;
  final String? commodityName;
  final int sequence;
  final double quantity;

  RoomtypeCommodity({
    required this.roomTypeID,
    required this.commodityID,
    this.commodityName,
    this.sequence = 0,
    this.quantity = 0.0,
  });

  factory RoomtypeCommodity.fromJson(Map<String, dynamic> json) {
    return RoomtypeCommodity(
      roomTypeID: json['roomTypeID'] as int? ?? 0,
      commodityID: json['commodityID'] as int? ?? 0,
      commodityName: json['commodityName'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomTypeID': roomTypeID,
      'commodityID': commodityID,
      'sequence': sequence,
      'quantity': quantity,
    };
  }
}
