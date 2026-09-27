import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';

// import 'package:flutter_localizations/flutter_localizations.dart';

class Util {
  Util();

  /// เลขบัตรประชาชน / เลขประจำตัวผู้เสียภาษี 13 หลัก ถูกต้องตามหลักตรวจสอบหรือไม่
  ///
  /// หลักที่ 13 = (11 - (ผลรวมของหลักที่ 1-12 คูณ 13 ลงไปถึง 2) mod 11) mod 10
  /// ใช้จับเลขที่พิมพ์ผิด เพราะใบจองรายย่อยใช้เลขนี้เป็น Ref.1 ของใบ Pay-in
  /// ต้องตรงกับ BookroomService.isValidThaiId ฝั่ง backend
  static bool isValidThaiId(String? value) {
    final d = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 13) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(d[i]) * (13 - i);
    }
    return (11 - sum % 11) % 10 == int.parse(d[12]);
  }

  /// เลือกวันที่ด้วยปฏิทินภาษาไทย (พ.ศ.) — คืน null เมื่อกดยกเลิก
  ///
  /// ทั้งระบบใช้ตัวนี้ตัวเดียว ผู้เรียกต้องเช็ค null เองก่อนนำค่าไปใช้
  /// เพื่อให้แยกออกว่าผู้ใช้กดยกเลิก หรือตั้งใจเลือกวันเดิม
  /// [iniDate] เป็น null ได้ ปฏิทินจะเปิดที่วันนี้ ใช้กับช่องที่ยังไม่ได้เลือก
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
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
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
