// lib/models/statuscheck.dart
class StatusCheck {
  final int? status;
  final String? name;

  StatusCheck({this.status, this.name});

  factory StatusCheck.fromJson(Map<String, dynamic> json) {
    return StatusCheck(
      status: json['status'] as int?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'name': name};
  }

  StatusCheck copyWith({int? status, String? name}) {
    return StatusCheck(status: status ?? this.status, name: name ?? this.name);
  }
}
