import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// import 'package:flutter_localizations/flutter_localizations.dart';

class Util {
  Util();

  /// เลือกวันที่ด้วยปฏิทินภาษาไทย (พ.ศ.) — คืนค่าเดิมเมื่อกดยกเลิก
  ///
  /// เหมาะกับช่องที่ต้องมีวันที่เสมอ ช่องที่ว่างได้ (เช่นช่องค้นหา) ให้ใช้
  /// [dateFieldPickerNullable] แทน ไม่งั้นกดยกเลิกแล้วจะได้วันที่เริ่มต้นกลับมา
  static Future<DateTime> dateFieldPicker(
    BuildContext context,
    DateTime iniDate,
  ) async {
    final picked = await dateFieldPickerNullable(context, iniDate);
    return picked ?? iniDate;
  }

  /// ปฏิทินเดียวกับ [dateFieldPicker] แต่คืน null เมื่อกดยกเลิก
  ///
  /// [iniDate] เป็น null ได้ ปฏิทินจะเปิดที่วันนี้ ใช้กับช่องที่ยังไม่ได้เลือก
  /// ทำให้แยกได้ว่าผู้ใช้ยกเลิก หรือตั้งใจเลือกวันเดียวกับวันเริ่มต้น
  static Future<DateTime?> dateFieldPickerNullable(
    BuildContext context,
    DateTime? iniDate,
  ) async {
    final first = DateTime(2017, 1, 1); // พ.ศ. 2560
    final last = DateTime(2037, 12, 31); // พ.ศ. 2580
    var initial = iniDate ?? DateTime.now();
    // initialDate ต้องอยู่ในช่วง first-last ไม่งั้น showDatePicker จะ assert
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: first,
      lastDate: last,
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
      fieldLabelText: 'วันที่',
      fieldHintText: 'วัน/เดือน/ปี',
      errorFormatText: 'รูปแบบวันที่ไม่ถูกต้อง',
      errorInvalidText: 'วันที่ไม่ถูกต้อง',
      locale: const Locale('th', 'TH'), // แสดงปีเป็น พ.ศ.
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('th', 'TH'),
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day);
  }

  // ✅ Thai date display
  static String formatThaiDate(DateTime date) {
    // Format using Thai locale - automatically displays year as 2569
    // return DateFormat.yMMMd('th').format(date);
    // Example output: "30 ก.ค. 2569"
    final thaiYear = date.year + 543;
    final thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  }

  static String formatThaiDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return formatThaiDate(date);
    } catch (e) {
      return dateStr;
    }
  }

  static String formatChristianDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String toBuddhistYearDisplay(DateTime date) {
    final int buddhistYear = date.year + 543;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$buddhistYear';
  }

  // Output: "30/07/2569"
}
