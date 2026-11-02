class TickerMessage {
  final int? id;
  final String icon;
  final String message;
  final bool isActive;
  final int sortOrder;
  final String? createdBy;
  final double? fontSize; // ✅ Add this

  /// วันเวลาที่บันทึกข้อความ (created_at จาก backend) — null = ยังไม่ได้บันทึก
  /// ใช้แสดงว่าข้อความนี้ลงมาตั้งแต่วันไหน (คำขอปรับปรุงข้อ 5.4)
  final DateTime? createdAt;

  TickerMessage({
    this.id,
    required this.icon,
    required this.message,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdBy,
    this.fontSize = 14, // Default font size
    this.createdAt,
  });

  /// อ่านวันเวลาจาก JSON ได้ทั้งแบบข้อความ (2026-11-02T10:15:30 หรือ
  /// 2026-11-02 10:15:30) และแบบ array [ปี, เดือน, วัน, ชั่วโมง, นาที, วินาที]
  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is List && v.length >= 3) {
      int at(int i) => i < v.length ? (v[i] as num).toInt() : 0;
      return DateTime(at(0), at(1), at(2), at(3), at(4), at(5));
    }
    return null;
  }

  factory TickerMessage.fromJson(Map<String, dynamic> json) {
    return TickerMessage(
      id: json['id'] as int?,
      icon: json['icon'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdBy: json['createdBy'] as String?,
      fontSize:
          (json['fontSize'] as num?)?.toDouble() ?? 14, // ✅ Parse fontSize
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'icon': icon,
      'message': message,
      'isActive': isActive,
      'sortOrder': sortOrder,
      if (createdBy != null) 'createdBy': createdBy,
      'fontSize': fontSize, // ✅ Include fontSize
    };
  }

  TickerMessage copyWith({
    int? id,
    String? icon,
    String? message,
    bool? isActive,
    int? sortOrder,
    String? createdBy,
    double? fontSize, // ✅ Add this
    DateTime? createdAt,
  }) {
    return TickerMessage(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      fontSize: fontSize ?? this.fontSize, // ✅ Add this
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayText {
    if (icon.isNotEmpty) {
      return '$icon $message';
    }
    return message;
  }
}
