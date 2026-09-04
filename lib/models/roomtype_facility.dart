class RoomtypeFacility {
  final int roomTypeID;
  final int facilityID;
  final String? facilityName;
  final int sequence;
  final double quantity;

  RoomtypeFacility({
    required this.roomTypeID,
    required this.facilityID,
    this.facilityName,
    this.sequence = 0,
    this.quantity = 0.0,
  });

  factory RoomtypeFacility.fromJson(Map<String, dynamic> json) {
    return RoomtypeFacility(
      roomTypeID: json['roomTypeID'] as int? ?? 0,
      facilityID: json['facilityID'] as int? ?? 0,
      facilityName: json['facilityName'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomTypeID': roomTypeID,
      'facilityID': facilityID,
      'sequence': sequence,
      'quantity': quantity,
    };
  }
}
