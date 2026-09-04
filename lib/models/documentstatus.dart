// lib/models/documentstatus.dart
class DocumentStatus {
  final int? statusId;
  final String? statusName;

  DocumentStatus({this.statusId, this.statusName});

  factory DocumentStatus.fromJson(Map<String, dynamic> json) {
    return DocumentStatus(
      statusId: json['statusId'] as int?,
      statusName: json['statusName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'statusId': statusId, 'statusName': statusName};
  }

  DocumentStatus copyWith({int? statusId, String? statusName}) {
    return DocumentStatus(
      statusId: statusId ?? this.statusId,
      statusName: statusName ?? this.statusName,
    );
  }
}
