import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';

class Util {
  Util();

  // ✅ Add BuildContext as parameter
  static Future<DateTime> dateFieldPicker(
    BuildContext context, // ✅ Add this
  //  String txt,
    DateTime iniDate,
  ) async {
    // Convert Christian year to Buddhist year for display
    int y = iniDate.year;// + 543
    int m = iniDate.month;
    int d = iniDate.day;
    DateTime selectedDate = DateTime(y, m, d);

    final DateTime? picked = await showDatePicker(
      context: context, // ✅ Now context is available
      initialDate: selectedDate,
      firstDate: DateTime(2017, 1, 1), // Buddhist year 2560 = 2017
      lastDate: DateTime(2037, 12, 31), // Buddhist year 2580 = 2037
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
      fieldLabelText: 'วันที่',
      fieldHintText: 'วัน/เดือน/ปี',
      errorFormatText: 'รูปแบบวันที่ไม่ถูกต้อง',
      errorInvalidText: 'วันที่ไม่ถูกต้อง',
      // locale: const Locale('th'),
      locale: const Locale('th', 'TH'), // Forces Buddhist Year display
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

    if (picked != null) {
      // Convert Buddhist year back to Christian year
     // int christianYear = picked.year ;//- 543;
      return DateTime(picked.year, picked.month, picked.day);
    }
    return iniDate; // Return original if not picked
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
 static  String toBuddhistYearDisplay(DateTime date) {
    final int buddhistYear = date.year + 543;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$buddhistYear';
  }

  // Output: "30/07/2569"
}
