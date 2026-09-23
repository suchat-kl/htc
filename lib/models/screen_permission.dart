// lib/models/screen_permission.dart

/// สิทธิ์ของผู้ใช้ที่ล็อกอินอยู่ ต่อหน้าจอหนึ่ง
///
/// backend รวมสิทธิ์จากทุก role ที่ผู้ใช้ถือมาให้แล้ว ฝั่งนี้จึงใช้ค่าตรง ๆ
/// หน้าจอที่ผู้ใช้ไม่มีสิทธิ์ดู จะไม่ถูกส่งมาเลย
class ScreenPermission {
  final String screenCode;
  final String screenName;

  /// MAIN, ROOM, OPER, MSTR, RPT, USER
  final String menuGroup;

  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final bool canPrint;

  const ScreenPermission({
    required this.screenCode,
    required this.screenName,
    required this.menuGroup,
    required this.canView,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
    required this.canPrint,
  });

  factory ScreenPermission.fromJson(Map<String, dynamic> json) {
    return ScreenPermission(
      screenCode: json['screenCode']?.toString() ?? '',
      screenName: json['screenName']?.toString() ?? '',
      menuGroup: json['menuGroup']?.toString() ?? '',
      canView: json['canView'] == true,
      canAdd: json['canAdd'] == true,
      canEdit: json['canEdit'] == true,
      canDelete: json['canDelete'] == true,
      canPrint: json['canPrint'] == true,
    );
  }

  /// สิทธิ์ตามชื่อการกระทำ ใช้กับเมธอด can() ที่รับชื่อเป็นข้อความ
  bool allows(String action) {
    switch (action) {
      case 'view':
        return canView;
      case 'add':
        return canAdd;
      case 'edit':
        return canEdit;
      case 'delete':
        return canDelete;
      case 'print':
        return canPrint;
      default:
        return false;
    }
  }
}
