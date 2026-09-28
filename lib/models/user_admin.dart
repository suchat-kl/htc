/// ผู้ใช้หนึ่งบัญชีในหน้าแก้ไขผู้ใช้งาน (เมนูผู้ดูแลระบบ)
///
/// ในรายการ [idcard] เป็นแบบปิดบางส่วน (x-xxxx-xxxxx-34-0)
/// ได้ครบ 13 หลักเฉพาะตอนเปิดแก้ไขทีละบัญชี
class UserAdmin {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String? position;
  final String? department;
  final String? phone;
  final String? idcard;
  final List<String> roles;
  final bool active;
  final bool locked;
  final DateTime? lastLogin;

  const UserAdmin({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.position,
    this.department,
    this.phone,
    this.idcard,
    this.roles = const [],
    this.active = true,
    this.locked = false,
    this.lastLogin,
  });

  /// ผูกเลขบัตรไว้แล้ว สแกน ThaID เข้าสู่ระบบด้วยบัญชีนี้ได้
  bool get thaidLinked => idcard != null && idcard!.isNotEmpty;

  factory UserAdmin.fromJson(Map<String, dynamic> j) => UserAdmin(
    id: (j['id'] as num).toInt(),
    username: j['username'] as String? ?? '',
    fullName: j['fullName'] as String? ?? '',
    email: j['email'] as String? ?? '',
    position: j['position'] as String?,
    department: j['department'] as String?,
    phone: j['phone'] as String?,
    idcard: j['idcard'] as String?,
    roles: List<String>.from(j['roles'] as List? ?? const []),
    active: j['active'] == true,
    locked: j['locked'] == true,
    lastLogin: j['lastLogin'] is String
        ? DateTime.tryParse(j['lastLogin'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'position': position,
    'department': department,
    'phone': phone,
    'idcard': idcard,
    'roles': roles,
    'active': active,
    'locked': locked,
  };
}
