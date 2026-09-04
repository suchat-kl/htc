class TickerMessage {
  final int? id;
  final String icon;
  final String message;
  final bool isActive;
  final int sortOrder;
  final String? createdBy;
  final double? fontSize; // ✅ Add this

  TickerMessage({
    this.id,
    required this.icon,
    required this.message,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdBy,
    this.fontSize = 14, // Default font size
  });

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
  }) {
    return TickerMessage(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      fontSize: fontSize ?? this.fontSize, // ✅ Add this
    );
  }

  String get displayText {
    if (icon.isNotEmpty) {
      return '$icon $message';
    }
    return message;
  }
}
