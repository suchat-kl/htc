import 'package:flutter/foundation.dart';
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
  bool get isDirector => hasRole('DIRECTOR');

  AuthProvider() {
    // Listen to login state changes
    _apiService.onLoginStateChanged = (loggedIn) {
      notifyListeners();
    };
  }

  Future<void> login(String username, String password) async {
    await _apiService.login(username, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await _apiService.logout();
    notifyListeners();
  }

  Future<bool> loadSession() async {
    final result = await _apiService.loadSession();
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
    final name = displayName;
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Get role display names in Thai
  List<String> get roleDisplayNames {
    return roles.map((role) {
      switch (role) {
        case 'ADMIN':
          return 'ผู้ดูแลระบบ';
        case 'DIRECTOR':
          return 'ผู้อำนวยการ';
        case 'USER':
          return 'ผู้ใช้งาน';
        default:
          return role;
      }
    }).toList();
  }

  // Get highest role for display
  String get highestRole {
    if (isDirector) return 'ผู้อำนวยการ';
    if (isAdmin) return 'ผู้ดูแลระบบ';
    return 'ผู้ใช้งาน';
  }
}
