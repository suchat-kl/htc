import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:highway_training/models/bookroom.dart';
import 'package:highway_training/models/commodity.dart';
import 'package:highway_training/models/commodity_in.dart';
import 'package:highway_training/models/documentstatus.dart';
import 'package:highway_training/models/employee.dart';
import 'package:highway_training/models/equipment.dart';
import 'package:highway_training/models/facility.dart';
import 'package:highway_training/models/foodtype.dart';
import 'package:highway_training/models/maintenance.dart';
import 'package:highway_training/models/organization.dart';
import 'package:highway_training/models/part.dart';
import 'package:highway_training/models/room.dart';
import 'package:highway_training/models/roomtype.dart';
import 'package:highway_training/models/roomtype_commodity.dart';
import 'package:highway_training/models/roomtype_facility.dart';
import 'package:highway_training/models/section.dart';
import 'package:highway_training/models/statuscheck.dart';
import 'package:highway_training/models/tfood.dart';
import 'package:highway_training/models/ticker_message.dart';
import 'package:highway_training/models/tpart.dart';
import 'package:highway_training/services/auth_interceptor.dart';
import 'package:highway_training/utils/logger.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio; // Main Dio with auth interceptor
  late final Dio publicDio; // Public Dio WITHOUT auth interceptor
  late final FlutterSecureStorage storage;

  static const String baseUrl = 'https://backupdoh.doh.go.th/htcapi';
  static const String empKey = "empID";
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  String? _username;
  String? _email;
  String? _fullName;
  int? _empID;
  List<String> _roles = [];
  bool _isLoggedIn = false;

  Function(bool isLoggedIn)? onLoginStateChanged;

  ApiService._internal() {
    storage = const FlutterSecureStorage();
    // ============ PUBLIC DIO (No Auth) ============
    publicDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30), // Increased from 10
        receiveTimeout: const Duration(seconds: 30), // Increased from 10
        sendTimeout: const Duration(seconds: 30), // Added send timeout
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add these headers for web
          'Access-Control-Allow-Origin': '*',

          // 'User-Agent' : 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
        },
        // Add retry options
        receiveDataWhenStatusError: true,
        followRedirects: true,
        maxRedirects: 3,
      ),
    );

    // Add logging to public Dio
    // requestHeader/responseBody ปิดไว้: กันไม่ให้ token และ PII โผล่ใน console
    // เปิดชั่วคราวได้ตอน debug แต่อย่า commit กลับมาเป็น true
    if (kDebugMode) {
      publicDio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
    // Configure Dio with logging interceptor
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Increase timeouts globally
        connectTimeout: const Duration(seconds: 30), // Increased from 10
        receiveTimeout: const Duration(seconds: 30), // Increased from 10
        sendTimeout: const Duration(seconds: 30), // Added send timeout
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add these headers for web
          // 'Access-Control-Allow-Origin': '*',

          // 'User-Agent' : 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
        },
        // Add retry options
        receiveDataWhenStatusError: true,
        followRedirects: true,
        maxRedirects: 3,
      ),
    );

    // Add logging interceptor for debugging
    // requestHeader ปิดไว้: header มี 'Authorization: Bearer <token>' ทุก request
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }

    // Add auth interceptor
    dio.interceptors.add(AuthInterceptor(this));
  }

  String? get username => _username;
  String? get email => _email;
  String? get fullName => _fullName;
  int? get empID {
    return _empID!;
  }

  List<String> get roles => _roles;
  bool get isLoggedIn => _isLoggedIn;

  bool hasRole(String role) => _roles.contains(role);

  // Login with detailed error handling
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      AppLogger.d('🔵 Login Attempt:');
      AppLogger.d('   URL: $baseUrl/api/auth/login');
      AppLogger.d('   Username: $username');
      AppLogger.d('   Password: ${password.replaceAll(RegExp(r'.'), '*')}');

      final response = await publicDio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );

      AppLogger.i('🟢 Login Response:');
      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response Data: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200) {
        final data = response.data;

        // Validate response data
        if (data['access_token'] == null) {
          throw Exception('ไม่พบ access_token ในการตอบกลับ');
        }

        await storage.write(key: accessTokenKey, value: data['access_token']);
        await storage.write(key: refreshTokenKey, value: data['refresh_token']);
        // await storage.write(key: empKey, value: data['empID']);
        _username = data['username'];
        _email = data['email'];
        _fullName = data['full_name'];
        _roles = List<String>.from(data['roles'] ?? []);
        _isLoggedIn = true;
        // _empID = data['empID'];
        // In login method:
        _empID = data['empID']; // ✅ empID is int, so this works
        await storage.write(
          key: empKey,
          value: _empID?.toString(),
        ); // Convert to String for storage

        await storage.write(
          key: userDataKey,
          value:
              '$_username|$_email|$_fullName|${_roles.join(',')}', //|$_empID',
        );

        onLoginStateChanged?.call(true);

        AppLogger.i('🟢 Login Successful:');
        AppLogger.d('   Username: $_username');
        AppLogger.d('   Full Name: $_fullName');
        AppLogger.d('   Roles: $_roles');

        return data;
      } else {
        throw Exception('Login failed with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.e('🔴 DioException:');
      AppLogger.d('   Type: ${e.type}');
      AppLogger.d('   Message: ${e.message}');
      AppLogger.d('   Error: ${e.error}');

      if (e.response != null) {
        AppLogger.d('   Response Status: ${e.response?.statusCode}');
        AppLogger.lazy(() => '   Response Data: ${AppLogger.redact(e.response?.data)}', tag: 'AUTH');
        AppLogger.d('   Response Headers: ${e.response?.headers}');
      }

      String message = _getErrorMessage(e);
      throw Exception(message);
    } catch (e) {
      AppLogger.e('🔴 Unexpected Error: $e');
      throw Exception('เกิดข้อผิดพลาดที่ไม่คาดคิด: ${e.toString()}');
    }
  }

  // Get user-friendly error message
  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'หมดเวลาในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.sendTimeout:
        return 'หมดเวลาในการส่งข้อมูล กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.receiveTimeout:
        return 'หมดเวลาในการรับข้อมูล กรุณาลองใหม่อีกครั้ง';
      case DioExceptionType.connectionError:
        return 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (responseData is Map && responseData.containsKey('message')) {
          return responseData['message'];
        }

        switch (statusCode) {
          case 400:
            return 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
          case 401:
            return 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
          case 403:
            return 'คุณไม่มีสิทธิ์เข้าถึงระบบ';
          case 404:
            return 'ไม่พบเซิร์ฟเวอร์ (404 Not Found)\nกรุณาตรวจสอบ URL: $baseUrl/api/auth/login';
          case 500:
            return 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์ กรุณาลองใหม่อีกครั้ง';
          case 502:
            return 'เซิร์ฟเวอร์ไม่พร้อมให้บริการ (Bad Gateway)';
          case 503:
            return 'เซิร์ฟเวอร์กำลังอยู่ในระหว่างการบำรุงรักษา';
          default:
            return 'เกิดข้อผิดพลาด (${statusCode ?? 'unknown'})';
        }
      case DioExceptionType.cancel:
        return 'คำขอถูกยกเลิก';
      case DioExceptionType.badCertificate:
        return 'ใบรับรองความปลอดภัยไม่ถูกต้อง\nอาจเกิดจาก HTTPS certificate issue';
      default:
        return 'เกิดข้อผิดพลาดในการเชื่อมต่อ\n${e.message ?? ''}';
    }
  }

  // Test connectivity
  Future<Map<String, dynamic>> testConnection() async {
    try {
      AppLogger.d('🔵 Testing connection to: $baseUrl/api/auth/login');

      // ignore: unused_local_variable
      final response = dio.options.baseUrl.contains('https')
          ? dio.get('/api/auth/login')
          : dio.get('/api/auth/login');

      AppLogger.i('🟢 Connection test successful');
      return {'success': true, 'message': 'เชื่อมต่อสำเร็จ'};
    } on DioException catch (e) {
      AppLogger.e('🔴 Connection test failed: ${e.message}');
      return {
        'success': false,
        'message': _getErrorMessage(e),
        'error': e.toString(),
      };
    }
  }

  // Refresh token
  // In AuthInterceptor or your API service:
  bool _isRefreshing = false;
  // ignore: unused_field
  final _pendingRequests =
      <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  Future<void> refreshToken() async {
    // ✅ Check if already refreshing
    if (_isRefreshing) {
      AppLogger.w('⚠️ Refresh already in progress, waiting...');
      // Wait for current refresh to complete
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return _isRefreshing;
      });
      return;
    }

    _isRefreshing = true;

    try {
      final oldRefreshToken = await storage.read(key: refreshTokenKey);
      if (oldRefreshToken == null) {
        throw Exception('No refresh token available');
      }

      AppLogger.d('🔄 Refreshing token...');
      AppLogger.d(
        '   Using refresh_token: ${oldRefreshToken.substring(0, 8)}...',
      );

      final response = await publicDio.post(
        '/api/auth/refresh-token',
        data: {'refresh_token': oldRefreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // ✅ Save new tokens immediately
        await storage.write(key: accessTokenKey, value: data['access_token']);
        await storage.write(key: refreshTokenKey, value: data['refresh_token']);
        AppLogger.i('🟢 Token refreshed successfully');
        AppLogger.d(
          '   New refresh_token: ${data['refresh_token']?.toString().substring(0, 8)}...',
        );
      } else {
        throw Exception('Refresh failed with status: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('🔴 Token refresh failed: $e');
      await logout();
      throw Exception('Session expired. Please login again.');
    } finally {
      _isRefreshing = false; // ✅ Always reset the flag
    }
  }

  // Simple logout - interceptor handles the token
  Future<void> logout() async {
    try {
      AppLogger.d('👋 Logging out...');

      final refreshToken = await storage.read(key: refreshTokenKey);

      if (refreshToken != null) {
        try {
          // No need to manually add Authorization header
          // The interceptor will add it automatically
          final response = await publicDio.post(
            '/api/auth/logout',
            data: {'refresh_token': refreshToken},
          );

          AppLogger.i('🟢 Logout API Response: ${response.statusCode}');
        } catch (e) {
          AppLogger.w('⚠️ Logout API call failed: $e');
        }
      }

      // Clear local data
      _username = null;
      _email = null;
      _fullName = null;
      _roles = [];
      _isLoggedIn = false;

      await storage.deleteAll();
      onLoginStateChanged?.call(false);

      AppLogger.i('✅ Logged out successfully');
    } catch (e) {
      AppLogger.e('🔴 Error during logout: $e');
      await storage.deleteAll();
      _isLoggedIn = false;
      onLoginStateChanged?.call(false);
    }
  }

  Future<bool> loadSession() async {
    try {
      final accessToken = await storage.read(key: accessTokenKey);
      final userData = await storage.read(key: userDataKey);
      final empIdStr = await storage.read(key: empKey); // Read as String
      _empID = empIdStr != null ? int.tryParse(empIdStr) : null; // Parse to int

      if (accessToken != null && userData != null) {
        final parts = userData.split('|');
        if (parts.length >= 4) {
          _username = parts[0];
          _email = parts[1];
          _fullName = parts[2];
          _roles = parts[3].split(',').where((r) => r.isNotEmpty).toList();
          _isLoggedIn = true;
          onLoginStateChanged?.call(true);
          AppLogger.i('🟢 Session loaded: $_username');
          return true;
        }
      }
    } catch (e) {
      AppLogger.w('⚠️ Error loading session: $e');
    }
    return false;
  }

  Future<String?> getAccessToken() async {
    return await storage.read(key: accessTokenKey);
  }

  // Change password
  Future<void> changePassword(
    String username,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }

      AppLogger.d('🔵 Change Password Request:');
      AppLogger.d('   Username: $username');
      AppLogger.d('   URL: $baseUrl/api/auth/changepassword');

      final response = await dio.post(
        '/api/auth/changepassword',
        data: {
          'username': username,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      AppLogger.i('🟢 Change Password Response:');
      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == false || data['success'] == 'false') {
          throw Exception(data['message'] ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
        }
      } else {
        throw Exception('เปลี่ยนรหัสผ่านไม่สำเร็จ (${response.statusCode})');
      }
    } on DioException catch (e) {
      AppLogger.e('🔴 Change Password Error:');
      AppLogger.d('   Type: ${e.type}');
      AppLogger.d('   Message: ${e.message}');

      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }

      String message = _getErrorMessage(e);
      throw Exception(message);
    } catch (e) {
      AppLogger.e('🔴 Unexpected Error in changePassword: $e');
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(
    String username,
    // String oldPassword,
    String newPassword,
  ) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }

      AppLogger.d('🔵 Reset Password Request:');
      AppLogger.d('   Username: $username');
      AppLogger.d('   URL: $baseUrl/api/auth/resetpassword');

      final response = await dio.post(
        '/api/auth/resetpassword',
        data: {
          'username': username,
          'oldPassword': "oldPassword",
          'newPassword': newPassword,
        },
      );

      AppLogger.i('🟢 Reset Password Response:');
      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == false || data['success'] == 'false') {
          throw Exception(data['message'] ?? 'กำหนดรหัสผ่านใหม่ไม่สำเร็จ');
        }
      } else {
        throw Exception('กำหนดรหัสผ่านใหม่ไม่สำเร็จ (${response.statusCode})');
      }
    } on DioException catch (e) {
      AppLogger.e('🔴 ResetPassword Error:');
      AppLogger.d('   Type: ${e.type}');
      AppLogger.d('   Message: ${e.message}');

      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }

      String message = _getErrorMessage(e);
      throw Exception(message);
    } catch (e) {
      AppLogger.e('🔴 Unexpected Error in resetPassword: $e');
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  // Get all available roles
  Future<List<Map<String, String>>> getRoles() async {
    try {
      AppLogger.d('🔵 Get Roles Request:');
      AppLogger.d('   URL: $baseUrl/api/auth/roles');
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final response = await dio.get(
        '/api/auth/roles',
        // options: Options(
        //   connectTimeout: const Duration(seconds: 30),
        //   receiveTimeout: const Duration(seconds: 30),
        // ),
      );

      AppLogger.i('🟢 Get Roles Response:');
      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['roles'] != null) {
          List<Map<String, String>> roles = [];
          for (var role in data['roles']) {
            roles.add({
              'code': role['code']?.toString() ?? '',
              'name': role['name']?.toString() ?? '',
            });
          }
          return roles;
        }
      }

      throw Exception('ไม่สามารถดึงข้อมูลบทบาทได้');
    } on DioException catch (e) {
      AppLogger.e('🔴 Get Roles Error: ${e.message}');

      // Return default roles if API fails
      return _getDefaultRoles();
    } catch (e) {
      AppLogger.e('🔴 Unexpected Error in getRoles: $e');
      return _getDefaultRoles();
    }
  }

  // In api_service.dart
  Future<bool> isTokenExpired() async {
    try {
      final token = await getAccessToken();
      if (token == null) return true;

      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final Map<String, dynamic> map = json.decode(decoded);

      final exp = map['exp'] as int?;
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      // ✅ Consider token expired if less than 60 seconds remaining
      return now.add(const Duration(seconds: 60)).isAfter(expiryDate);
    } catch (e) {
      AppLogger.d('Error checking token expiry: $e');
      return true;
    }
  }

  // Register new user
  Future<Map<String, dynamic>> registerUser({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String position,
    required String department,
    required String phone,
    required List<String> roles,
  }) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }

      AppLogger.d('🔵 Register User Request:');
      AppLogger.d('   URL: $baseUrl/api/auth/register');
      AppLogger.d('   Username: $username');
      AppLogger.d('   Full Name: $fullName');
      AppLogger.d('   Roles: $roles');

      final response = await dio.post(
        '/api/auth/register',
        data: {
          'fullName': fullName,
          'username': username,
          'email': email,
          'password': password,
          'position': position,
          'department': department,
          'phone': phone,
          'roles': roles,
        },
        options: Options(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      AppLogger.i('🟢 Register User Response:');
      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception('สร้างผู้ใช้งานไม่สำเร็จ (${response.statusCode})');
      }
    } on DioException catch (e) {
      AppLogger.e('🔴 Register User Error:');
      AppLogger.d('   Type: ${e.type}');
      AppLogger.d('   Message: ${e.message}');

      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }

      String message = _getErrorMessage(e);
      throw Exception(message);
    } catch (e) {
      AppLogger.e('🔴 Unexpected Error in registerUser: $e');
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  // ============ PUBLIC API METHODS ============

  /// Get active ticker messages (PUBLIC - no auth required)
  Future<List<TickerMessage>> getActiveTickerMessages() async {
    try {
      AppLogger.d('🔵 [PUBLIC] Getting active ticker messages...');
      AppLogger.d('   URL: $baseUrl/api/auth/ticker-msg');

      // Use publicDio (no auth interceptor)
      final response = await publicDio.get('/api/auth/ticker-msg');

      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.lazy(() => '   Response: ${AppLogger.redact(response.data)}', tag: 'AUTH');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['messages'] != null) {
          List<TickerMessage> messages = [];
          for (var msg in data['messages']) {
            messages.add(TickerMessage.fromJson(msg));
          }
          AppLogger.i('✅ Loaded ${messages.length} ticker messages');
          return messages;
        }
      }
      return [];
    } catch (e) {
      AppLogger.e('❌ Error getting ticker messages: $e');
      return [];
    }
  }

  // Get all ticker messages (for management)
  Future<List<TickerMessage>> getAllTickerMessages() async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final response = await publicDio.get(
        '/api/auth/ticker-msg/all',
        // options: Options(
        //   connectTimeout: const Duration(seconds: 30),
        //   receiveTimeout: const Duration(seconds: 30),
        // ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['messages'] != null) {
          List<TickerMessage> messages = [];
          for (var msg in data['messages']) {
            messages.add(TickerMessage.fromJson(msg));
          }
          return messages;
        }
      }
      return [];
    } catch (e) {
      AppLogger.d('Error getting all ticker messages: $e');
      throw Exception('ไม่สามารถดึงข้อมูลข้อความวิ่งได้');
    }
  }

  // Save all ticker messages
  Future<void> saveAllTickerMessages(List<TickerMessage> messages) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final data = messages.map((m) => m.toJson()).toList();

      final response = await dio.post(
        '/api/auth/ticker-msg/batch',
        data: data,
        // options: Options(
        //   connectTimeout: const Duration(seconds: 30),
        //   receiveTimeout: const Duration(seconds: 30),
        // ),
      );

      if (response.statusCode != 200) {
        throw Exception('บันทึกข้อความไม่สำเร็จ');
      }
    } catch (e) {
      AppLogger.d('Error saving ticker messages: $e');
      throw Exception('เกิดข้อผิดพลาดในการบันทึกข้อความ');
    }
  }

  // Default roles as fallback
  List<Map<String, String>> _getDefaultRoles() {
    return [
      {'code': 'USER', 'name': 'USER'},
      {'code': 'ADMIN', 'name': 'ADMIN'},
      {'code': 'DIRECTOR', 'name': 'DIRECTOR'},
      {'code': 'MANAGER', 'name': 'MANAGER'},
      // {'code': 'SUPERVISOR', 'name': 'หัวหน้างาน'},
      // {'code': 'TRAINER', 'name': 'วิทยากร'},
      // {'code': 'STAFF', 'name': 'เจ้าหน้าที่'},
    ];
  }

  // Get commodities with pagination
  Future<Map<String, dynamic>> getCommodities({
    int page = 0,
    int size = 10,
    String? name,
    String? type,
    String? status,
  }) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final queryParams = <String, dynamic>{'page': page, 'size': size};
      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await dio.get(
        '/api/auth/commodities',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('ไม่สามารถดึงข้อมูลได้');
    } catch (e) {
      AppLogger.d('Error getting commodities: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // Create commodity
  Future<Commodity> createCommodity(Commodity commodity) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/commodities',
      data: commodity.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return Commodity.fromJson(response.data['commodity']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  // Update commodity
  Future<Commodity> updateCommodity(int id, Commodity commodity) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/commodities/$id',
      data: commodity.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return Commodity.fromJson(response.data['commodity']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  // Delete commodity
  Future<void> deleteCommodity(int id) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/commodities/$id');

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  //facility
  // Get  with pagination
  Future<Map<String, dynamic>> getFacilities({
    int page = 0,
    int size = 5,
    String? name,
    // String? type,
    String? status,
  }) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final queryParams = <String, dynamic>{'page': page, 'size': size};
      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      // if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await dio.get(
        '/api/auth/facilities',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('ไม่สามารถดึงข้อมูลได้');
    } catch (e) {
      AppLogger.d('Error getting commodities: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // Create commodity
  Future<Facility> createFacility(Facility facility) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/facilities',
      data: facility.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return Facility.fromJson(response.data['facility']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  // Update commodity
  Future<Facility> updateFacility(int id, Facility facility) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/facilities/$id',
      data: facility.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return Facility.fromJson(response.data['facility']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  // Delete commodity
  Future<void> deleteFacility(int id) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/facilities/$id');

    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  //facility
  //roomtype
  // Get roomtypes with pagination
  Future<Map<String, dynamic>> getRoomtypes({
    int page = 0,
    int size = 5,
    String? name,
    String? type,
    String? status,
  }) async {
    try {
      // Check if token is about to expire
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final queryParams = <String, dynamic>{'page': page, 'size': size};
      if (name != null && name.isNotEmpty) queryParams['name'] = name;
      if (type != null && type.isNotEmpty) queryParams['type'] = type;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await dio.get(
        '/api/auth/roomtype',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data;
      }
      throw Exception('ไม่สามารถดึงข้อมูลได้');
    } catch (e) {
      AppLogger.d('Error getting roomtypes: $e');
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // Create roomtype
  Future<Roomtype> createRoomtype(Roomtype roomtype) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/roomtype',
      data: roomtype.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Roomtype.fromJson(response.data['roomtype']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  // Update roomtype
  Future<Roomtype> updateRoomtype(int id, Roomtype roomtype) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/roomtype/$id',
      data: roomtype.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Roomtype.fromJson(response.data['roomtype']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  // Delete roomtype
  Future<void> deleteRoomtype(int id) async {
    // Check if token is about to expire
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/roomtype/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }
  //roomtype

  //roomtype commodity
  // Get roomtype commodities
  Future<Map<String, dynamic>> getRoomtypeCommodities(
    int roomTypeID, {
    int page = 0,
    int size = 5,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/roomtype-commodity/$roomTypeID',
      queryParameters: {'page': page, 'size': size},
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  // Create roomtype commodity
  Future<void> createRoomtypeCommodity(RoomtypeCommodity rc) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/roomtype-commodity',
      data: rc.toJson(),
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    }
  }

  // Update roomtype commodity
  Future<void> updateRoomtypeCommodity(
    int roomTypeID,
    int commodityID,
    RoomtypeCommodity rc,
  ) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/roomtype-commodity/$roomTypeID/$commodityID',
      data: rc.toJson(),
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    }
  }

  // Delete roomtype commodity
  Future<void> deleteRoomtypeCommodity(int roomTypeID, int commodityID) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete(
      '/api/auth/roomtype-commodity/$roomTypeID/$commodityID',
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  // Get commodities list for dropdown
  Future<List<Commodity>> getCommoditiesList({
    int roomTypeID = 0,
    String mode = "none",
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/commodities',
      queryParameters: {
        'page': 0,
        'size': 1000,
        'roomTypeID': roomTypeID,
        'mode': mode,
      },
    );
    if (response.statusCode == 200 && response.data['commodities'] != null) {
      return (response.data['commodities'] as List)
          .map((j) => Commodity.fromJson(j))
          .toList();
    }
    return [];
  }

  //roomtype commodity
  //
  //roomtype facility
  // Get roomtype commodities
  Future<Map<String, dynamic>> getRoomtypeFacilities(
    int roomTypeID, {
    int page = 0,
    int size = 5,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/roomtype-facility/$roomTypeID',
      queryParameters: {'page': page, 'size': size},
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  // Create roomtype commodity
  Future<void> createRoomtypeFacility(RoomtypeFacility rc) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/roomtype-facility',
      data: rc.toJson(),
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    }
  }

  // Update roomtype commodity
  Future<void> updateRoomtypeFacility(
    int roomTypeID,
    int facilityID,
    RoomtypeFacility rc,
  ) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/roomtype-facility/$roomTypeID/$facilityID',
      data: rc.toJson(),
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    }
  }

  // Delete roomtype commodity
  Future<void> deleteRoomtypeFacility(int roomTypeID, int facilityID) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete(
      '/api/auth/roomtype-facility/$roomTypeID/$facilityID',
    );
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  // Get commodities list for dropdown
  Future<List<Facility>> getFacilitiesList({
    int roomTypeID = 0,
    String mode = "none",
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/facilities',
      queryParameters: {
        'page': 0,
        'size': 1000,
        'roomTypeID': roomTypeID,
        'mode': mode,
      },
    );
    if (response.statusCode == 200 && response.data['facilities'] != null) {
      return (response.data['facilities'] as List)
          .map((j) => Facility.fromJson(j))
          .toList();
    }
    return [];
  }

  //roomtype facility

  //room
  // Get rooms with pagination
  Future<Map<String, dynamic>> getRooms({
    int page = 0,
    int size = 5,
    String? roomNO,
    int? roomTypeID,
    int? building,
    int? floor,
    String? status,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final queryParams = <String, dynamic>{'page': page, 'size': size};
    if (roomNO != null && roomNO.isNotEmpty) queryParams['roomNO'] = roomNO;
    if (roomTypeID != null) queryParams['roomTypeID'] = roomTypeID;
    if (building != null) queryParams['building'] = building;
    if (floor != null) queryParams['floor'] = floor;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final response = await dio.get(
      '/api/auth/rooms',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  // Create room
  Future<Room> createRoom(Room room) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post('/api/auth/rooms', data: room.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Room.fromJson(response.data['room']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  // Update room
  Future<Room> updateRoom(int id, Room room) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put('/api/auth/rooms/$id', data: room.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Room.fromJson(response.data['room']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  // Delete room
  Future<void> deleteRoom(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/rooms/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  // Get room types for dropdown
  Future<List<Roomtype>> getRoomtypeList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/roomtype',
      queryParameters: {'page': 0, 'size': 100},
    );
    if (response.statusCode == 200 && response.data['roomType'] != null) {
      return (response.data['roomType'] as List)
          .map((j) => Roomtype.fromJson(j))
          .toList();
    }
    return [];
  }
  //room

  //part
  // Get parts with pagination
  Future<Map<String, dynamic>> getParts({
    int page = 0,
    int size = 5,
    String? name,
    String? type,
    String? status,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    final queryParams = <String, dynamic>{'page': page, 'size': size};
    if (name != null && name.isNotEmpty) queryParams['name'] = name;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    final response = await dio.get(
      '/api/auth/parts',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Part> createPart(Part part) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    final response = await dio.post('/api/auth/parts', data: part.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Part.fromJson(response.data['part']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  Future<Part> updatePart(int id, Part part) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    final response = await dio.put('/api/auth/parts/$id', data: part.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Part.fromJson(response.data['part']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  Future<void> deletePart(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    final response = await dio.delete('/api/auth/parts/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  //part

  //commodity_report
  // ============ COMMODITY REPORT API ============

  /// Get commodities by type for report
  Future<List<Commodity>> getCommoditiesByType(String type) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    try {
      AppLogger.d('🔵 Getting commodities by type: $type');

      final token = await getAccessToken();
      if (token == null) throw Exception('กรุณาเข้าสู่ระบบใหม่');

      final response = await dio.get(
        '/api/auth/commodities',
        queryParameters: {'page': 0, 'size': 1000, 'type': type},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      AppLogger.d('   Status Code: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['commodities'] != null) {
        final List<dynamic> list = response.data['commodities'];
        AppLogger.d('   Loaded ${list.length} commodities');
        return list
            .map((j) => Commodity.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.e('❌ Error getting commodities by type: $e');
      throw Exception('ไม่สามารถโหลดข้อมูลได้: $e');
    }
  }

  /// Download commodity report as Excel file
  Future<List<int>> downloadCommodityReport({
    required String type,
    required String date,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }

    try {
      AppLogger.d('🔵 Downloading commodity report: type=$type, date=$date');

      final token = await getAccessToken();
      if (token == null) throw Exception('กรุณาเข้าสู่ระบบใหม่');

      final response = await dio.get(
        '/api/auth/report/commodity',
        queryParameters: {'type': type, 'date': date},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) => status! < 500,
        ),
      );

      AppLogger.d('   Status Code: ${response.statusCode}');
      AppLogger.d('   Content-Type: ${response.headers.value('content-type')}');

      if (response.statusCode == 200) {
        // ✅ Check if response is actually bytes or error JSON
        if (response.data is List<int>) {
          final bytes = response.data as List<int>;
          AppLogger.d('   File size: ${bytes.length} bytes');

          // ✅ Verify Excel signature (first 4 bytes of .xlsx are PK..)
          if (bytes.length > 4) {
            final signature = bytes
                .take(4)
                .map((b) => b.toRadixString(16))
                .join(' ');
            AppLogger.d('   File signature: $signature');
            // .xlsx files start with PK (0x50 0x4B)
            if (bytes[0] != 0x50 || bytes[1] != 0x4B) {
              throw Exception('ไฟล์ที่ได้ไม่ใช่ Excel file');
            }
          }

          return bytes;
        } else if (response.data is String) {
          // Error response in JSON format
          throw Exception('เซิร์ฟเวอร์ส่งข้อผิดพลาดกลับมา');
        }
      }
      throw Exception(
        'ไม่สามารถดาวน์โหลดรายงานได้ (Status: ${response.statusCode})',
      );
    } catch (e) {
      AppLogger.e('❌ Error downloading report: $e');
      throw Exception('ดาวน์โหลดรายงานไม่สำเร็จ: $e');
    }
  }

  //commodity_report

  //organization
  // Get organizations
  Future<Map<String, dynamic>> getOrganizations({
    int page = 0,
    int size = 5,
    String? orgCode,
    String? orgName,
    String? orgLevel,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final params = <String, dynamic>{'page': page, 'size': size};
    if (orgCode != null && orgCode.isNotEmpty) params['orgCode'] = orgCode;
    if (orgName != null && orgName.isNotEmpty) params['orgName'] = orgName;
    if (orgLevel != null && orgLevel.isNotEmpty) params['orgLevel'] = orgLevel;
    final response = await dio.get(
      '/api/auth/organizations',
      queryParameters: params,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Organization> createOrganization(Organization org) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/organizations',
      data: org.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Organization.fromJson(response.data['organization']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  Future<Organization> updateOrganization(int id, Organization org) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/organizations/$id',
      data: org.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Organization.fromJson(response.data['organization']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  Future<void> deleteOrganization(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/organizations/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  // Get organization list for parent dropdown
  Future<List<Organization>> getOrganizationList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/organizations',
      queryParameters: {'page': 0, 'size': 1000},
    );
    if (response.statusCode == 200 && response.data['organizations'] != null) {
      return (response.data['organizations'] as List)
          .map((j) => Organization.fromJson(j))
          .toList();
    }
    return [];
  }
  //org

  //section
  // Get sections
  Future<Map<String, dynamic>> getSections({
    int page = 0,
    int size = 5,
    String? name,
    int? orgID,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final params = <String, dynamic>{'page': page, 'size': size};
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (orgID != null) params['orgID'] = orgID;
    final response = await dio.get(
      '/api/auth/sections',
      queryParameters: params,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Section> createSection(Section section) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      '/api/auth/sections',
      data: section.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Section.fromJson(response.data['section']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  Future<Section> updateSection(int id, Section section) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/sections/$id',
      data: section.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Section.fromJson(response.data['section']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  Future<void> deleteSection(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/sections/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  //section
  //emp
  // Get employees
  Future<List<Employee>> getEmployeesList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get(
      '/api/auth/employees',
      queryParameters: {'page': 0, 'size': 1000},
    );
    if (response.statusCode == 200 && response.data['employees'] != null) {
      return (response.data['employees'] as List)
          .map((j) => Employee.fromJson(j))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getEmployees({
    int page = 0,
    int size = 5,
    String? name,
    String? lastname,
    int? orgID,
    int? userID,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final params = <String, dynamic>{'page': page, 'size': size};
    if (name != null && name.isNotEmpty) params['name'] = name;
    if (lastname != null && lastname.isNotEmpty) params['lastname'] = lastname;
    if (orgID != null) params['orgID'] = orgID;
    if (userID != null) params['userID'] = userID;
    final response = await dio.get(
      '/api/auth/employees',
      queryParameters: params,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Employee> createEmployee(Employee emp) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post('/api/auth/employees', data: emp.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Employee.fromJson(response.data['employee']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
  }

  Future<Employee> updateEmployee(int id, Employee emp) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      '/api/auth/employees/$id',
      data: emp.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      return Employee.fromJson(response.data['employee']);
    }
    throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
  }

  Future<void> deleteEmployee(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.delete('/api/auth/employees/$id');
    if (response.statusCode != 200 || response.data['success'] != true) {
      throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
    }
  }

  // Get user list for dropdown
  Future<List<Map<String, dynamic>>> getUserList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.get(
        '/api/auth/users',
        queryParameters: {'page': 0, 'size': 1000},
      );
      if (response.statusCode == 200 && response.data['users'] != null) {
        return List<Map<String, dynamic>>.from(response.data['users']);
      }
      return [];
    } catch (e) {
      AppLogger.d('Error loading users: $e');
      return [];
    }
  }

  // Future<List<Employee>> getEmployeesList(

  // ) async {
  //   if (await isTokenExpired()) {
  //     AppLogger.d('Token expired or about to expire, refreshing...');
  //     try {
  //       await refreshToken();
  //     } catch (e) {
  //       throw Exception('กรุณาเข้าสู่ระบบใหม่');
  //     }
  //   }
  //   final response = await dio.get(
  //     '/api/auth/employees',
  //     queryParameters: {
  //       'page': 0,
  //       'size': 1000,

  //     },
  //   );
  //   if (response.statusCode == 200 && response.data['employees'] != null) {
  //     return (response.data['employees'] as List)
  //         .map((j) => Employee.fromJson(j))
  //         .toList();
  //   }
  //   return [];
  // }
  //emp

  //commodity in
  // Get commodityin transactions
  Future<Map<String, dynamic>> getCommodityInTransactions({
    int page = 0,
    int size = 5,
    int? commodityID,
    String? type,
    int? employeeID,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final queryParams = <String, dynamic>{'page': page, 'size': size};
    if (commodityID != null) queryParams['commodityID'] = commodityID;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (employeeID != null) queryParams['employeeID'] = employeeID;
    final response = await dio.get(
      '/api/auth/commodityin',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<CommodityIn> createCommodityIn(CommodityIn data) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.post(
        '/api/auth/commodityin',
        data: data.toJson(),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CommodityIn.fromJson(response.data['transaction']);
      }
      throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      // ✅ Catch the error response and extract the message
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message); // This will be caught by the dialog
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<CommodityIn> updateCommodityIn(int id, CommodityIn data) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.put(
        '/api/auth/commodityin/$id',
        data: data.toJson(),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CommodityIn.fromJson(response.data['transaction']);
      }
      throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteCommodityIn(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.delete('/api/auth/commodityin/$id');
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  //in
  //equipment
// ============ EQUIPMENT API ============

  Future<Map<String, dynamic>> getEquipment({
    int page = 0,
    int size = 5,
    int? bookingid,
    int? roomtypeid,
    String? place,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final params = <String, dynamic>{'page': page, 'size': size};
    if (bookingid != null) params['bookingid'] = bookingid;
    if (roomtypeid != null) params['roomtypeid'] = roomtypeid;
    if (place != null && place.isNotEmpty) params['place'] = place;
    final response = await dio.get(
      '/api/auth/equipment',
      queryParameters: params,
    );
    if (response.statusCode == 200) return response.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<List<Map<String, dynamic>>> getBooktitles() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.get('/api/auth/equipment/booktitlesList');
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(response.data['data']);//response.data
    }
    return [];
  }

  Future<Equipment> createEquipment(Equipment data) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.post(
        '/api/auth/equipment',
        data: data.toJson(),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Equipment.fromJson(response.data['equipment']);
      }
      throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<Equipment> updateEquipment(int id, Equipment data) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.put(
        '/api/auth/equipment/$id',
        data: data.toJson(),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Equipment.fromJson(response.data['equipment']);
      }
      throw Exception(response.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteEquipment(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final response = await dio.delete('/api/auth/equipment/$id');
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final message = e.response!.data['message'] ?? 'เกิดข้อผิดพลาด';
        throw Exception(message);
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }
  //equipment
  //tpart
// ============ TPART API ============
  Future<Map<String, dynamic>> getTparts({
   
    int page = 0,
    int size = 5,
    int? partid,
    String? type,
    int? employeeid,
    int? maintenanceid,
  }) async {
     if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final p = <String, dynamic>{'page': page, 'size': size};
    if (partid != null) p['partid'] = partid;
    if (type != null && type.isNotEmpty) p['type'] = type;
    if (employeeid != null) p['employeeid'] = employeeid;
    if (maintenanceid != null) p['maintenanceid'] = maintenanceid;
    final r = await dio.get('/api/auth/tparts', queryParameters: p);
    if (r.statusCode == 200) return r.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Tpart> createTpart(Tpart d) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.post('/api/auth/tparts', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Tpart.fromJson(r.data['transaction']);
      }
      throw Exception(r.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<Tpart> updateTpart(int id, Tpart d) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.put('/api/auth/tparts/$id', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Tpart.fromJson(r.data['transaction']);
      }
      throw Exception(r.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteTpart(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.delete('/api/auth/tparts/$id');
      if (r.statusCode != 200 || r.data['success'] != true) {
        throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // Get parts list for dropdown
  Future<List<Part>> getPartsList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final r = await dio.get(
      '/api/auth/partsList',
      queryParameters: {'page': 0, 'size': 1000},
    );
    if (r.statusCode == 200 && r.data['parts'] != null) {
      return (r.data['parts'] as List).map((j) => Part.fromJson(j)).toList();
    }
    return [];
  }

  // Get maintenance list for dropdown
  Future<List<Maintenance>> getMaintenanceList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final r = await dio.get(
      '/api/auth/maintenanceList',
      queryParameters: {'page': 0, 'size': 1000},
    );
    if (r.statusCode == 200 && r.data['maintenance'] != null) {
      return (r.data['maintenance'] as List)
          .map((j) => Maintenance.fromJson(j))
          .toList();
    }
    return [];
  }
  //tpart

  //maintainance
  // Get room list for dropdown
  Future<List<Map<String, dynamic>>> getRoomList() async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final r = await dio.get('/api/auth/rooms/list');
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(r.data);
    return [];
  }

  // Get Tparts by maintenance ID
  Future<List<Tpart>> getTpartsByMaintenanceId(int maintenanceid) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final r = await dio.get(
      '/api/auth/tparts',
      queryParameters: {'maintenanceid': maintenanceid, 'page': 0, 'size': 100},
    );
    if (r.statusCode == 200 && r.data['transactions'] != null) {
      return (r.data['transactions'] as List)
          .map((j) => Tpart.fromJson(j))
          .toList();
    }
    return [];
  }

  // Delete maintenance (cascades to tparts)
  Future<void> deleteMaintenance(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.delete('/api/auth/maintenance/$id');
      if (r.statusCode != 200 || r.data['success'] != true) {
        throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // ============ MAINTENANCE API ============

  Future<Map<String, dynamic>> getMaintenance({
    int page = 0,
    int size = 5,
    String? reportname,
    String? workstatus,
    String? worktype,
    String? placetype,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final p = <String, dynamic>{'page': page, 'size': size};
    if (reportname != null && reportname.isNotEmpty) {
      p['reportname'] = reportname;
    }
    if (workstatus != null && workstatus.isNotEmpty) {
      p['workstatus'] = workstatus;
    }
    if (worktype != null && worktype.isNotEmpty) p['worktype'] = worktype;
    if (placetype != null && placetype.isNotEmpty) p['placetype'] = placetype;
    final r = await dio.get('/api/auth/maintenance', queryParameters: p);
    if (r.statusCode == 200) return r.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Maintenance> createMaintenance(Maintenance d) async {
    try {
      if (await isTokenExpired()) {
        AppLogger.d('Token expired or about to expire, refreshing...');
        try {
          await refreshToken();
        } catch (e) {
          throw Exception('กรุณาเข้าสู่ระบบใหม่');
        }
      }
      final r = await dio.post('/api/auth/maintenance', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Maintenance.fromJson(r.data['maintenance']);
      }
      throw Exception(r.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // ✅ ADD THIS METHOD
  Future<Maintenance> updateMaintenance(int id, Maintenance d) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.put('/api/auth/maintenance/$id', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Maintenance.fromJson(r.data['maintenance']);
      }
      throw Exception(r.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  // Future<void> deleteMaintenance(int id) async {
  //   try {
  //     final r = await dio.delete('/api/auth/maintenance/$id');
  //     if (r.statusCode != 200 || r.data['success'] != true) {
  //       throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
  //     }
  //   } on DioException catch (e) {
  //     if (e.response?.data is Map) {
  //       throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
  //     }
  //     throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
  //   }
  // }

  // Get room list for dropdown
  // Future<List<Map<String, dynamic>>> getRoomList() async {
  //   try {
  //     final r = await dio.get('/api/auth/rooms/list');
  //     if (r.statusCode == 200) {
  //       return List<Map<String, dynamic>>.from(r.data);
  //     }
  //     return [];
  //   } catch (e) {
  //     AppLogger.d('Error loading rooms: $e');
  //     return [];
  //   }
  // }

  // Get Tparts by maintenance ID
  // Future<List<Tpart>> getTpartsByMaintenanceId(int maintenanceid) async {
  //   try {
  //     final r = await dio.get(
  //       '/api/auth/tparts',
  //       queryParameters: {
  //         'maintenanceid': maintenanceid,
  //         'page': 0,
  //         'size': 100,
  //       },
  //     );
  //     if (r.statusCode == 200 && r.data['transactions'] != null) {
  //       return (r.data['transactions'] as List)
  //           .map((j) => Tpart.fromJson(j))
  //           .toList();
  //     }
  //     return [];
  //   } catch (e) {
  //     AppLogger.d('Error loading tparts: $e');
  //     return [];
  //   }
  // }
  //maintainance

  // ============ FOODTYPE API ============
  Future<Map<String, dynamic>> getFoodtypes({
    int page = 0,
    int size = 5,
    String? name,
    int? foodgroupID,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final p = <String, dynamic>{'page': page, 'size': size};
    if (name != null && name.isNotEmpty) p['name'] = name;
    if (foodgroupID != null) p['foodgroupID'] = foodgroupID;
    final r = await publicDio.get('/api/auth/foodtypes', queryParameters: p);
    if (r.statusCode == 200) return r.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Foodtype> createFoodtype(Foodtype d) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.post('/api/auth/foodtypes', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Foodtype.fromJson(r.data['foodtype']);
      }
      throw Exception(r.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<Foodtype> updateFoodtype(int id, Foodtype d) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.put('/api/auth/foodtypes/$id', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Foodtype.fromJson(r.data['foodtype']);
      }
      throw Exception(r.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteFoodtype(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.delete('/api/auth/foodtypes/$id');
      if (r.statusCode != 200 || r.data['success'] != true) {
        throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

 // ============ BOOKING API ============
 /*
  Future<List<Bookroom>> getBookingID({
    int page = 0,
    int size = 5,
    int? bookingID
    
  }) async {
     if (bookingID == null) return []; // ✅ Return empty if nul
    final p = <String, dynamic>{'page': page, 'size': size,'bookID':bookingID};
    // if (booktitle != null && booktitle.isNotEmpty) p['booktitle'] = booktitle;
    // if (departmentname != null && departmentname.isNotEmpty) {
    //   p['departmentname'] = departmentname;
    // }
    final response = await publicDio.get('/api/auth/bookingID', queryParameters: p);
    // if (r.statusCode == 200) {
    //   //return r.data;
    //  return r.data['bookings'];
    // }
    // throw Exception('ไม่สามารถดึงข้อมูลได้');

    if (response.statusCode == 200 && response.data['Bookroom'] != null) {
      return (response.data['Bookroom'] as List)
          .map((j) => Bookroom.fromJson(j))
          .toList();
    }
    return [];
  }
*/


  Future<Map<String, dynamic>> getBookings({
    int page = 0,
    int size = 5,
    String? booktitle,
    String? departmentname,
  }) async {
    final p = <String, dynamic>{'page': page, 'size': size};
    if (booktitle != null && booktitle.isNotEmpty) p['booktitle'] = booktitle;
    if (departmentname != null && departmentname.isNotEmpty) {
      p['departmentname'] = departmentname;
    }
    final r = await publicDio.get('/api/auth/bookings', queryParameters: p);
    if (r.statusCode == 200) return r.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Bookroom> createBooking(Bookroom d) async {
    try {
      final r = await publicDio.post('/api/auth/bookings', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Bookroom.fromJson(r.data['booking']);
      }
      throw Exception(r.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<Bookroom> updateBooking(int id, Bookroom d) async {
    // if (await isTokenExpired()) {
    //   AppLogger.d('Token expired or about to expire, refreshing...');
    //   try {
    //     await refreshToken();
    //   } catch (e) {
    //     throw Exception('กรุณาเข้าสู่ระบบใหม่');
    //   }
    // }
    try {
      final r = await publicDio.put('/api/auth/bookings/$id', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Bookroom.fromJson(r.data['booking']);
      }
      throw Exception(r.data['message'] ?? 'อัปเดตไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteBooking(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    try {
      final r = await dio.delete('/api/auth/bookings/$id');
      if (r.statusCode != 200 || r.data['success'] != true) {
        throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }
/// ค้นหาการจองตามเงื่อนไขต่างๆ
  Future<Map<String, dynamic>> searchBookings({
    int? bookID,
    String? startdate,
    String? stopdate,
    String? departmentname,
    String? booktitle,
    int? status,
    int page = 0,
    int size = 10,
  }) async {
    final p = <String, dynamic>{'page': page, 'size': size};

    if (bookID != null) p['bookID'] = bookID;
    if (startdate != null && startdate.isNotEmpty) p['startdate'] = startdate;
    if (stopdate != null && stopdate.isNotEmpty) p['stopdate'] = stopdate;
    if (departmentname != null && departmentname.isNotEmpty) {
      p['departmentname'] = departmentname;
    }
    if (booktitle != null && booktitle.isNotEmpty) p['booktitle'] = booktitle;
    if (status != null) p['status'] = status;

    try {
      final r = await publicDio.get(
        '/api/auth/searchBookings',
        queryParameters: p,
      );
      if (r.statusCode == 200) {
        return r.data;
      }
      throw Exception('ไม่สามารถค้นหาข้อมูลได้');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  /// ดึงรายการสถานะการจองทั้งหมด
  Future<List<DocumentStatus>> getDocumentStatusList({
    int page = 0,
    int size = 100,
    String? keyword,
  }) async {
    final p = <String, dynamic>{'page': page, 'size': size};
    if (keyword != null && keyword.isNotEmpty) p['keyword'] = keyword;

    try {
      final r = await publicDio.get(
        '/api/auth/documentstatus',
        queryParameters: p,
      );
      if (r.statusCode == 200 && r.data['success'] == true) {
        final List data = r.data['documentstatus'] ?? [];
        return data.map((j) => DocumentStatus.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  // ============ TFOOD API ============
  Future<Map<String, dynamic>> getTfoods({
    int page = 0,
    int size = 100,
    int? bookID,
  }) async {
    final p = <String, dynamic>{'page': page, 'size': size};
    if (bookID != null) p['bookID'] = bookID;
    final r = await publicDio.get('/api/auth/tfoods', queryParameters: p);
    if (r.statusCode == 200) return r.data;
    throw Exception('ไม่สามารถดึงข้อมูลได้');
  }

  Future<Tfood> createTfood(Tfood d) async {
    try {
      final r = await publicDio.post('/api/auth/tfoods', data: d.toJson());
      if (r.statusCode == 200 && r.data['success'] == true) {
        return Tfood.fromJson(r.data['tfood']);
      }
      throw Exception(r.data['message'] ?? 'บันทึกไม่สำเร็จ');
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<void> deleteTfood(int id) async {
    try {
      final r = await publicDio.delete('/api/auth/tfoods/$id');
      if (r.statusCode != 200 || r.data['success'] != true) {
        throw Exception(r.data['message'] ?? 'ลบไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'เกิดข้อผิดพลาด');
      }
      throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ');
    }
  }

  Future<List<Foodtype>> getFoodtypeList() async {
    final r = await publicDio.get(
      '/api/auth/foodtypes',
      queryParameters: {'page': 0, 'size': 1000},
    );
    if (r.statusCode == 200 && r.data['foodtypes'] != null) {
      return (r.data['foodtypes'] as List)
          .map((j) => Foodtype.fromJson(j))
          .toList();
    }
    return [];
  }

  // lib/services/api_service.dart
  // เพิ่ม method เหล่านี้ในคลาส ApiService

  Future<Map<String, dynamic>> getDocumentStatus({
    int page = 0,
    int size = 5,
    String? keyword,
  }) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final queryParams = {
      'page': page.toString(),
      'size': size.toString(),
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    };

    final response = await dio.get(
      
      '/api/auth/documentstatus',
      queryParameters: queryParams,
    );

    return response.data;
  }

  Future<DocumentStatus> createDocumentStatus(
    DocumentStatus documentStatus,
  ) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      
      '/api/auth/documentstatus',
      data: documentStatus.toJson(),
    );
if (response.statusCode == 200 && response.data['success'] == true) {
      return DocumentStatus.fromJson(response.data['documentstatus']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
   
  }

  Future<DocumentStatus> updateDocumentStatus(
    int id,
    DocumentStatus documentStatus,
  ) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      
      '/api/auth/documentstatus/$id',
      data: documentStatus.toJson(),
    );

    // return DocumentStatus.fromJson(response['documentstatus']);
    if (response.statusCode == 200 && response.data['success'] == true) {
      return DocumentStatus.fromJson(response.data['documentstatus']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
   
  }

  Future<void> deleteDocumentStatus(int id) async {
    if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    await dio.delete( '/api/auth/documentstatus/$id');
  }
  // lib/services/api_service.dart
  // เพิ่ม method เหล่านี้ในคลาส ApiService

  Future<Map<String, dynamic>> getStatusChecks({
    int page = 0,
    int size = 5,
    String? keyword,
  }) async {
     if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final queryParams = {
      'page': page.toString(),
      'size': size.toString(),
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    };

    final response = await dio.get(
      
      '/api/auth/statuschecks',
      queryParameters: queryParams,
    );

    return response.data;
  }

  Future<StatusCheck> createStatusCheck(StatusCheck statusCheck) async {
     if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.post(
      
      '/api/auth/statuschecks',
      data: statusCheck.toJson(),
    );
if (response.statusCode == 200 && response.data['success'] == true) {
      return StatusCheck.fromJson(response.data['statuscheck']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    // return StatusCheck.fromJson(response['statuscheck']);
  }

  Future<StatusCheck> updateStatusCheck(int id, StatusCheck statusCheck) async {
     if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    final response = await dio.put(
      
      '/api/auth/statuschecks/$id',
      data: statusCheck.toJson(),
    );
if (response.statusCode == 200 && response.data['success'] == true) {
      return StatusCheck.fromJson(response.data['statuscheck']);
    }
    throw Exception(response.data['message'] ?? 'บันทึกไม่สำเร็จ');
    // return StatusCheck.fromJson(response['statuscheck']);
  }

  Future<void> deleteStatusCheck(int id) async {
     if (await isTokenExpired()) {
      AppLogger.d('Token expired or about to expire, refreshing...');
      try {
        await refreshToken();
      } catch (e) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }
    }
    await dio.delete( '/api/auth/statuschecks/$id');
  }
}
