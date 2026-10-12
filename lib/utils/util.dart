import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/thai_date_picker.dart';

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
  /// เปิด [showThaiDatePicker] ด้วยช่วงวันที่ตั้งต้น (พ.ศ. 2560-2580) จุดที่ต้องกำหนดช่วงเอง
  /// ให้เรียก [showThaiDatePicker] ตรง ห้ามเรียก showDatePicker ของ Flutter (ปีเป็น ค.ศ.)
  /// ผู้เรียกต้องเช็ค null เองก่อนนำค่าไปใช้
  /// เพื่อให้แยกออกว่าผู้ใช้กดยกเลิก หรือตั้งใจเลือกวันเดิม
  /// [iniDate] เป็น null ได้ ปฏิทินจะเปิดที่วันนี้ ใช้กับช่องที่ยังไม่ได้เลือก
  static Future<DateTime?> dateFieldPickerNullable(
    BuildContext context,
    DateTime? iniDate,
  ) {
    // ช่วงวันที่ตั้งต้นของ showThaiDatePicker คือ พ.ศ. 2560-2580 (1 ม.ค. 2017 - 31 ธ.ค. 2037)
    // วันตั้งต้นที่อยู่นอกช่วงถูกปรับเข้าช่วงให้ ค่าที่คืนไม่มีเวลา
    return showThaiDatePicker(context, iniDate);
  }

  /// ชื่อเดือนภาษาไทยแบบเต็ม เรียงมกราคม-ธันวาคม
  static const List<String> thaiMonths = [
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

  /// ชื่อวันในสัปดาห์ เรียงจันทร์-อาทิตย์ ตาม [DateTime.weekday] (1 = จันทร์)
  static const List<String> thaiWeekdays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  /// ชื่อเดือนภาษาไทยของเดือน 1-12 นอกช่วงคืนตัวเลขเดิม (ข้อมูลเดิมที่ผิดรูป)
  static String thaiMonthName(int month) =>
      month >= 1 && month <= 12 ? thaiMonths[month - 1] : '$month';

  /// ปี พ.ศ. ของวันที่ (ค.ศ. + 543)
  static int buddhistYear(DateTime date) => date.year + 543;

  /// วันที่ไทยพร้อมวันในสัปดาห์ เช่น "ศุกร์ 16 มกราคม 2569"
  static String formatThaiDateWithWeekday(DateTime date) =>
      '${thaiWeekdays[date.weekday - 1]} ${formatThaiDate(date)}';

  // ✅ Thai date display
  static String formatThaiDate(DateTime date) {
    // Format using Thai locale - automatically displays year as 2569
    // return DateFormat.yMMMd('th').format(date);
    // Example output: "30 ก.ค. 2569"
    final thaiYear = date.year + 543;
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
