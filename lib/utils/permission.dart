// lib/utils/permission.dart
import '../services/api_service.dart';

/// ทางลัดเรียกสิทธิ์รายหน้าจอจากที่ไหนก็ได้
///
/// [ApiService] เป็นตัวเดียวทั้งแอป (singleton) จึงอ่านสิทธิ์ที่โหลดไว้ตอนล็อกอิน
/// ได้โดยไม่ต้องส่ง AuthProvider ผ่านเข้าไปทุกหน้าจอ
///
/// ระหว่างที่ยังโหลดสิทธิ์ไม่เสร็จ ทุกเมธอดคืนค่าจริง ปุ่มจะได้ไม่กะพริบเป็นสีเทา
/// ส่วนการกันจริงอยู่ที่ backend
class Perm {
  Perm._();

  static bool view(String screenCode) => ApiService().can(screenCode, 'view');
  static bool add(String screenCode) => ApiService().can(screenCode, 'add');
  static bool edit(String screenCode) => ApiService().can(screenCode, 'edit');
  static bool remove(String screenCode) => ApiService().can(screenCode, 'delete');
  static bool print(String screenCode) => ApiService().can(screenCode, 'print');

  /// เปลี่ยนสถานะการจองเป็นสถานะนี้ได้หรือไม่
  static bool bookStatus(int statusId) => ApiService().canChangeBookStatus(statusId);

  /// บัญชีผู้ดูแลระบบ ใช้กับงานที่สงวนไว้เฉพาะ admin เช่นการลบใบจองจริง
  static bool get isAdmin => ApiService().hasRole('ADMIN');

  /// รหัสหน้าจอที่ใช้บ่อย รวมไว้ที่เดียวกันพิมพ์ผิด
  static const String bookList = 'BOOK_LIST';
  static const String payment = 'RM_PAYMENT';
  static const String foodInvoice = 'RM_FOOD_INVOICE';
  static const String folio = 'RM_FOLIO';

  /// ประกาศประชาสัมพันธ์ (เมนูการดำเนินงาน)
  static const String notification = 'OP_NOTIFY';
}
