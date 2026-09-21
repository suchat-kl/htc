import 'package:flutter/material.dart';

/// ชุดสีและธีมกลางของทั้งระบบ — ธีม "ฟ้าใส"
///
/// ทุกหน้าจอต้องอ้างสีจากคลาสนี้เท่านั้น อย่าเขียนค่าสีตรงๆ ลงในหน้าจอ
/// (ยกเว้นสีกลางอย่าง `Colors.white` / `Colors.transparent`)
/// เวลาปรับธีมทั้งระบบจะได้แก้ที่ไฟล์นี้ไฟล์เดียว
class AppTheme {
  // ── สีหลัก ────────────────────────────────────────────────
  /// สีหลัก ใช้กับแถบบน ปุ่มหลัก และเส้นขอบตอนโฟกัส
  static const Color primaryColor = Color(0xFF1565C0);

  /// สีหลักเข้ม ใช้กับตัวอักษรบนพื้นสีหลักอ่อน
  static const Color primaryDark = Color(0xFF0D3C6E);

  /// สีหลักอ่อน ใช้กับไอคอน/เส้นคั่นที่ต้องการให้เบาลง
  static const Color primaryLight = Color(0xFF42A5F5);

  /// สีหลักจางมาก ใช้เป็นพื้นหัวตารางและแถวที่ถูกเลือก
  static const Color primaryPale = Color(0xFFE3F0FC);

  /// สีรอง (ทอง) ใช้กับปุ่มรายละเอียดและจุดที่ต้องการเน้น
  static const Color secondaryColor = Color(0xFFFFB300);

  /// สีตัวอักษรบนพื้นสีรอง — ใช้สีเข้มของตระกูลเดียวกัน ไม่ใช้สีดำล้วน
  static const Color onSecondaryColor = Color(0xFF4A3000);

  /// สีเสริม ใช้กับป้ายกำกับหรือกราฟที่ต้องการแยกจากสีหลัก
  static const Color accentColor = Color(0xFF00897B);

  // ── สีตามความหมาย ────────────────────────────────────────
  /// เขียว = สำเร็จ ใช้กับข้อความแจ้งผลและปุ่มเพิ่มรายการ
  static const Color successColor = Color(0xFF43A047);

  // ── สีปุ่มตามประเภทการทำงาน ──────────────────────────────
  // ปุ่มคนละหน้าที่ต้องคนละสี ผู้ใช้จะจำสีได้โดยไม่ต้องอ่านป้าย
  /// บันทึก — ฟ้า เข้าชุดกับแถบบน
  static const Color saveColor = primaryColor;

  /// เพิ่ม / เพิ่มรายการ — เขียว
  static const Color addColor = successColor;

  /// ลบ / ลบที่เลือก — แดง
  static const Color deleteColor = dangerColor;

  /// ค้นหา — เขียวน้ำทะเล
  static const Color searchColor = Color(0xFF00897B);

  /// แก้ไข / รายละเอียด — ทอง (ตัวอักษรใช้ onSecondaryColor)
  static const Color editColor = secondaryColor;

  /// พิมพ์ / ออกรายงาน — ม่วง
  static const Color printColor = Color(0xFF6A4FBF);

  /// ปุ่มกลาง เช่น เลือกทั้งหมด ล้าง ปิด กลับ — เทาน้ำเงิน
  static const Color neutralColor = Color(0xFF546E7A);

  /// แดง = อันตราย / ปุ่มลบ
  static const Color dangerColor = Color(0xFFE53935);

  /// ส้ม = คำเตือน เช่น ข้อความ "มีการแก้ไขที่ยังไม่ได้บันทึก"
  static const Color warningColor = Color(0xFFEF6C00);

  /// ฟ้าเขียว = ข้อมูลทั่วไป / ปุ่มกลับ
  static const Color infoColor = Color(0xFF00ACC1);

  // ── พื้นหลังและตัวอักษร ──────────────────────────────────
  /// พื้นหลังของหน้าจอ อมฟ้าอ่อนให้ดูสว่างแต่ไม่แสบตา
  static const Color backgroundColor = Color(0xFFF4F8FC);

  /// พื้นการ์ด/ตาราง
  static const Color cardColor = Colors.white;

  /// พื้นแถวสลับในตาราง
  static const Color surfaceAlt = Color(0xFFFAFCFE);

  /// พื้นช่องกรอกข้อมูลที่ต้องการให้ดูจมลงเล็กน้อย เช่น ช่องค้นหา
  static const Color fieldFillColor = Color(0xFFF7FAFD);

  static const Color textPrimary = Color(0xFF1B2430);
  static const Color textSecondary = Color(0xFF5F6B7A);

  /// เส้นคั่นและขอบช่องกรอก
  static const Color dividerColor = Color(0xFFD9E3EC);

  // ── สีผังห้อง (หน้าตรวจสอบห้องว่าง) ──────────────────────
  /// ม่วง = ห้องถูกใช้งานอยู่
  static const Color roomUsedColor = Color(0xFF7A6FCB);

  /// เขียวมิ้นต์ = ห้องว่าง
  static const Color roomFreeColor = Color(0xFF34D3AE);

  /// ส้ม = ห้องที่กำลังเลือก
  static const Color roomSelectedColor = Color(0xFFF57C00);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // IMPORTANT: Set font family and fallbacks
      fontFamily: 'NotoSansThai',
      fontFamilyFallback: const [
        'Sarabun',
        'NotoSansThai',
        'Kanit',
        'Tahoma',
        'sans-serif',
      ],

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        surface: cardColor,
        error: dangerColor,
        brightness: Brightness.light,
      ),

      // Define text theme with Sarabun
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // List tile theme
      // Fix ListTile ink splash visibility
      // ListTile theme - CORRECTED
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primaryColor.withValues(alpha: 0.1),
        selectedColor: primaryColor,
        iconColor: primaryColor,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enableFeedback: true,
        visualDensity: VisualDensity.standard,
      ),

      // Fix splash factory globally
      splashFactory: InkRipple.splashFactory,
      highlightColor: primaryColor.withValues(alpha: 0.1),
      splashColor: primaryColor.withValues(alpha: 0.15),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 12),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 12,
        ),
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 14,
        ),
      ),

      scaffoldBackgroundColor: backgroundColor,

      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 1),
    );
  }
}
