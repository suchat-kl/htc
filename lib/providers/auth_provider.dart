import 'package:flutter/foundation.dart';
import '../models/screen_permission.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool get isLoggedIn => _apiService.isLoggedIn;
  String? get username => _apiService.username;
  String? get email => _apiService.email;
  String? get fullName => _apiService.fullName;
  int? get empID => _apiService.empID;
  List<String> get roles => _apiService.roles;

  bool hasRole(String role) => _apiService.hasRole(role);
  bool get isAdmin => hasRole('ADMIN');

  // ── สิทธิ์รายหน้าจอ ────────────────────────────────────────────
  Map<String, ScreenPermission> get permissions => _apiService.permissions;
  List<int> get bookStatusIds => _apiService.bookStatusIds;
  bool get permissionsLoaded => _apiService.permissionsLoaded;

  /// ผู้ใช้ทำ [action] (view/add/edit/delete/print) กับหน้าจอนี้ได้หรือไม่
  bool can(String screenCode, String action) =>
      _apiService.can(screenCode, action);

  bool canView(String screenCode) => can(screenCode, 'view');
  bool canAdd(String screenCode) => can(screenCode, 'add');
  bool canEdit(String screenCode) => can(screenCode, 'edit');
  bool canDelete(String screenCode) => can(screenCode, 'delete');
  bool canPrint(String screenCode) => can(screenCode, 'print');

  /// เปลี่ยนสถานะการจองเป็นสถานะนี้ได้หรือไม่
  bool canChangeBookStatus(int statusId) =>
      _apiService.canChangeBookStatus(statusId);

  AuthProvider() {
    // Listen to login state changes
    _apiService.onLoginStateChanged = (loggedIn) {
      notifyListeners();
    };
  }

  Future<void> login(String username, String password) async {
    await _apiService.login(username, password);
    await _apiService.loadPermissions();
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout();
    notifyListeners();
  }

  Future<bool> loadSession() async {
    final result = await _apiService.loadSession();
    if (result) await _apiService.loadPermissions();
    notifyListeners();
    return result;
  }

  // Get user's display name
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    return username ?? 'ผู้ใช้';
  }

  // Get user's initials for avatar
  String get initials {
    // ตัดด้วยช่องว่างกี่ตัวก็ได้แล้วทิ้งชิ้นที่ว่าง เพราะ full_name ในฐานข้อมูล
    // บางระเบียนมีช่องว่างซ้อนหรือช่องว่างท้ายชื่อ ถ้าตัดด้วย ' ' เฉย ๆ
    // จะได้ชิ้นว่างมาแล้ว [0] ระเบิดเป็น RangeError ทั้งหน้าจอ
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  /// ชื่อ role ภาษาไทย ตามชุด role ที่ใช้จริงในระบบ
  static const Map<String, String> _roleNames = {
    'ADMIN': 'ผู้ดูแลระบบ',
    'MASTER': 'ผู้อำนวยการศูนย์ฯ',
    'MANAGER': 'หัวหน้างาน',
    'ACCOUNT': 'งานการเงิน',
    'RECEPTION': 'งานต้อนรับ',
    'RECEPTION2': 'งานต้อนรับ',
    'ROOM_SERVICE': 'บริการห้องพัก',
    'NUTRITION': 'งานโภชนาการ',
    'EQUIP_MASTER': 'หัวหน้างานโสตฯ',
    'SERVICE': 'งานซ่อมบำรุง',
    'EQUIP': 'งานโสตฯ',
    'USER': 'ผู้ใช้งาน',
  };

  List<String> get roleDisplayNames =>
      roles.map((role) => _roleNames[role] ?? role).toList();

  /// role ที่ใช้แสดงบนโปรไฟล์ เอาตัวที่สิทธิ์สูงสุดที่ผู้ใช้ถืออยู่
  ///
  /// USER เป็น role พื้นฐานที่ทุกคนถือ จึงเป็นตัวสุดท้ายเสมอ
  String get highestRole {
    const rank = [
      'ADMIN', 'MASTER', 'MANAGER', 'ACCOUNT', 'RECEPTION', 'RECEPTION2',
      'NUTRITION', 'EQUIP_MASTER', 'SERVICE', 'ROOM_SERVICE', 'EQUIP', 'USER',
    ];
    for (final r in rank) {
      if (hasRole(r)) return _roleNames[r] ?? r;
    }
    return 'ผู้ใช้งาน';
  }
}
