class Tfood {
  final int? id;
  final int? bookID;
  final int? foodtypeid;
  final String? foodtypeName;
  final int? price;
  final int? amount;
  final int? times;
  final int? sequence;
  final String? startdate;
  final String? stopdate;

  Tfood({
    this.id,
    this.bookID,
    this.foodtypeid,
    this.foodtypeName,
    this.price = 0,
    this.amount = 0,
    this.times = 0,
    this.sequence = 0,
    this.startdate,
    this.stopdate,
  });

  factory Tfood.fromJson(Map<String, dynamic> json) {
    return Tfood(
      id: json['id'] as int?,
      bookID: json['bookID'] as int?,
      foodtypeid: json['foodtypeid'] as int?,
      foodtypeName: json['foodtypeName'] as String?,
      price: json['price'] as int? ?? 0,
      amount: json['amount'] as int? ?? 0,
      times: json['times'] as int? ?? 0,
      sequence: json['sequence'] as int? ?? 0,
      startdate: json['startdate'] as String?,
      stopdate: json['stopdate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'bookID': bookID,
      'foodtypeid': foodtypeid,
      'price': price,
      'amount': amount,
      'times': times,
      'sequence': sequence,
      'startdate': startdate,
      'stopdate': stopdate,
    };
  }
}
