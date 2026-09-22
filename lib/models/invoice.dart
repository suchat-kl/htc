/// ค่าบริการอื่นๆ ของใบจอง (ตาราง t_invoice)
///
/// รายการนอกเหนือจากค่าห้องพัก ค่าห้องกิจกรรม และค่าอาหาร เช่น ค่าคาราโอเกะ
/// ค่าห้องจัดเลี้ยง ใช้ในตารางค่าบริการอื่นๆ ของหน้ารับชำระเงิน
class Invoice {
  final int? id;
  final int? bookid;

  /// ประเภทบริการ
  final String? servicetype;

  /// รายละเอียดเพิ่มเติม
  final String? description;

  /// จำนวนเงิน (บาท)
  final double price;

  final int sequence;

  Invoice({
    this.id,
    this.bookid,
    this.servicetype,
    this.description,
    this.price = 0,
    this.sequence = 0,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: (json['id'] as num?)?.toInt(),
      bookid: (json['bookid'] as num?)?.toInt(),
      servicetype: json['servicetype'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'bookid': bookid,
      'servicetype': servicetype,
      'description': description,
      'price': price,
      'sequence': sequence,
    };
  }
}
