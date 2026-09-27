/// สลิปโอนเงินที่ผู้จองแนบมาหนึ่งใบ
///
/// ฝั่งผู้จอง (ไม่ต้องล็อกอิน) ได้แค่ยอดเงิน สถานะ และหมายเหตุ
/// ช่องธนาคาร เลขอ้างอิง และผู้ตรวจ มีค่าเฉพาะตอนเจ้าหน้าที่เรียกจากหน้ารับชำระเงิน
class PaymentSlip {
  final int id;
  final int bookId;
  final double amount;
  final String? note;

  /// VALID / INVALID / NO_QR — ผลการอ่าน QR บนสลิป
  final String qrStatus;

  /// PENDING / CONFIRMED / REJECTED — ผลตรวจของเจ้าหน้าที่
  final String reviewStatus;
  final String? reviewRemark;
  final DateTime? uploadedAt;

  final String? sendingBank;
  final String? transRef;
  final int? fileSize;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const PaymentSlip({
    required this.id,
    required this.bookId,
    required this.amount,
    this.note,
    required this.qrStatus,
    required this.reviewStatus,
    this.reviewRemark,
    this.uploadedAt,
    this.sendingBank,
    this.transRef,
    this.fileSize,
    this.reviewedBy,
    this.reviewedAt,
  });

  bool get isPending => reviewStatus == 'PENDING';
  bool get isConfirmed => reviewStatus == 'CONFIRMED';
  bool get isRejected => reviewStatus == 'REJECTED';

  /// สลิปที่ควรตรวจละเอียดกว่าปกติ เพราะอ่าน QR ไม่ได้หรือรูปแบบ QR ผิด
  bool get needsCloserLook => qrStatus != 'VALID';

  String get reviewLabel => switch (reviewStatus) {
    'CONFIRMED' => 'ยืนยันแล้ว',
    'REJECTED' => 'ไม่รับ',
    _ => 'รอตรวจ',
  };

  String get qrLabel => switch (qrStatus) {
    'VALID' => 'อ่าน QR ได้',
    'INVALID' => 'QR ไม่ใช่สลิปธนาคาร',
    _ => 'ไม่พบ QR',
  };

  /// ชื่อธนาคารจากรหัส 3 หลักที่อยู่ใน QR บนสลิป
  String? get sendingBankName {
    final code = sendingBank;
    if (code == null) return null;
    return _banks[code] ?? 'ธนาคารรหัส $code';
  }

  static const Map<String, String> _banks = {
    '002': 'กรุงเทพ',
    '004': 'กสิกรไทย',
    '006': 'กรุงไทย',
    '011': 'ทหารไทยธนชาต',
    '014': 'ไทยพาณิชย์',
    '025': 'กรุงศรีอยุธยา',
    '030': 'ออมสิน',
    '033': 'อาคารสงเคราะห์',
    '034': 'ธ.ก.ส.',
    '069': 'เกียรตินาคินภัทร',
    '022': 'ซีไอเอ็มบี ไทย',
    '024': 'ยูโอบี',
    '067': 'ทิสโก้',
    '073': 'แลนด์ แอนด์ เฮ้าส์',
  };

  factory PaymentSlip.fromJson(Map<String, dynamic> json) {
    return PaymentSlip(
      id: (json['id'] as num).toInt(),
      bookId: (json['bookId'] as num).toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      qrStatus: json['qrStatus'] as String? ?? 'NO_QR',
      reviewStatus: json['reviewStatus'] as String? ?? 'PENDING',
      reviewRemark: json['reviewRemark'] as String?,
      uploadedAt: _date(json['uploadedAt']),
      sendingBank: json['sendingBank'] as String?,
      transRef: json['transRef'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: _date(json['reviewedAt']),
    );
  }

  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;
}

/// QR พร้อมเพย์ของใบจอง พร้อมยอดที่ใช้คำนวณ
///
/// ถ้า [image] ว่าง แปลว่าไม่ต้องจ่าย (ครบแล้ว / ยังไม่มียอด / ยังไม่เปิดใช้) ดูเหตุผลที่ [message]
class PromptPayQrInfo {
  final bool enabled;
  final String? promptPayId;
  final double totalDue;
  final double confirmed;
  final double pending;
  final double remaining;
  final double? amount;
  final String? payload;

  /// รูป PNG แบบ base64
  final String? image;
  final String? message;

  const PromptPayQrInfo({
    required this.enabled,
    this.promptPayId,
    required this.totalDue,
    required this.confirmed,
    required this.pending,
    required this.remaining,
    this.amount,
    this.payload,
    this.image,
    this.message,
  });

  bool get hasQr => image != null && image!.isNotEmpty;

  factory PromptPayQrInfo.fromJson(Map<String, dynamic> json) {
    double n(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return PromptPayQrInfo(
      enabled: json['enabled'] == true,
      promptPayId: json['promptPayId'] as String?,
      totalDue: n('totalDue'),
      confirmed: n('confirmed'),
      pending: n('pending'),
      remaining: n('remaining'),
      amount: (json['amount'] as num?)?.toDouble(),
      payload: json['payload'] as String?,
      image: json['image'] as String?,
      message: json['message'] as String?,
    );
  }
}
