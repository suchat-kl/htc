// lib/screens/monthly_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../utils/snackbar_helper.dart';

/// ตัวเลือกเสริมหนึ่งค่าของรายงานประจำเดือน เช่น อาคารที่เรียกรายงาน
class MonthlyReportChoice {
  /// ค่าที่ส่งให้ API
  final String value;

  /// ข้อความที่แสดงในช่องเลือก
  final String label;

  /// คำที่ต่อท้ายชื่อไฟล์ ว่าง = ไม่ต่อ
  final String fileLabel;

  const MonthlyReportChoice(this.value, this.label, {this.fileLabel = ''});
}

/// หน้าจอกลางของรายงานประจำเดือน — เลือกปี พ.ศ. กับเดือน แล้วกดพิมพ์
///
/// เมนูรายงานหลายตัวใช้เงื่อนไขชุดเดียวกันหมด (ตารางการใช้ห้องพัก, สรุปการใช้
/// ห้องพัก, รายงานการใช้ห้องกิจกรรม ฯลฯ) จึงทำเป็นหน้าจอเดียวแล้วส่งชื่อเรื่อง
/// กับฟังก์ชันดาวน์โหลดเข้ามา ไม่ต้องคัดลอกหน้าจอเดิมซ้ำทุกเมนู
///
/// รายงานที่ต้องมีตัวเลือกเพิ่มหนึ่งช่อง (เช่น เลือกอาคาร) ส่ง [choices] กับ
/// [downloadWithChoice] แทน [download] รายงานที่ไม่ส่งจะหน้าตาเหมือนเดิมทุกอย่าง
class MonthlyReportScreen extends StatefulWidget {
  /// ชื่อที่แสดงบนแถบด้านบน
  final String title;

  /// ชื่อไฟล์ที่ดาวน์โหลด ระบบจะต่อท้ายด้วยเดือนและปีให้เอง
  final String fileBaseName;

  /// ฟังก์ชันเรียก API ออกรายงาน คืนค่าเป็นเนื้อไฟล์
  final Future<List<int>> Function(int year, int month)? download;

  /// ชื่อช่องตัวเลือกเสริม เช่น "อาคาร" ใช้คู่กับ [choices]
  final String choiceLabel;

  /// ค่าของช่องตัวเลือกเสริม ค่าแรกเป็นค่าตั้งต้น ว่าง = ไม่มีช่องนี้
  final List<MonthlyReportChoice> choices;

  /// ฟังก์ชันเรียก API ที่รับค่าตัวเลือกเสริมด้วย ใช้เมื่อมี [choices]
  final Future<List<int>> Function(int year, int month, String choice)?
  downloadWithChoice;

  /// นามสกุลไฟล์ ปัจจุบันรายงานกลุ่มนี้ออกเป็น Excel อย่างเดียว
  final String extension;

  const MonthlyReportScreen({
    super.key,
    required this.title,
    required this.fileBaseName,
    this.download,
    this.extension = 'xlsx',
    this.choiceLabel = '',
    this.choices = const [],
    this.downloadWithChoice,
  }) : assert(
         download != null || downloadWithChoice != null,
         'ต้องส่ง download หรือ downloadWithChoice อย่างน้อยหนึ่งตัว',
       );

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  static const List<String> _monthNames = [
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

  final TextEditingController _yearCtrl = TextEditingController();
  int _month = DateTime.now().month;
  MonthlyReportChoice? _choice;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _yearCtrl.text = '${DateTime.now().year + 543}';
    if (widget.choices.isNotEmpty) _choice = widget.choices.first;
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null || year < 2500 || year > 2700) {
      context.showErrorSnackBar('กรอกปี พ.ศ. ให้ถูกต้อง เช่น 2569');
      return;
    }

    setState(() => _printing = true);
    try {
      final choice = _choice;
      final withChoice = widget.downloadWithChoice;
      final bytes = (choice != null && withChoice != null)
          ? await withChoice(year, _month, choice.value)
          : await widget.download!(year, _month);
      final choicePart = (choice == null || choice.fileLabel.isEmpty)
          ? ''
          : '_${choice.fileLabel}';

      final isPdf = widget.extension == 'pdf';
      final mime = isPdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final blob = html.Blob([Uint8List.fromList(bytes)], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download =
            '${widget.fileBaseName}${choicePart}_${_monthNames[_month - 1]}_$year.${widget.extension}';
      html.document.body!.children.add(anchor);
      anchor.click();
      Future.delayed(const Duration(seconds: 1), () {
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });

      if (!mounted) return;
      setState(() => _printing = false);
      context.showSuccessSnackBar('ออกรายงานเรียบร้อย');
    } catch (e) {
      if (!mounted) return;
      setState(() => _printing = false);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _yearCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'ปี',
                              labelStyle: const TextStyle(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<int>(
                            initialValue: _month,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'เดือน',
                              labelStyle: const TextStyle(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                            items: [
                              for (int m = 1; m <= 12; m++)
                                DropdownMenuItem<int>(
                                  value: m,
                                  child: Text(_monthNames[m - 1]),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _month = v);
                            },
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (widget.choices.isNotEmpty)
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<MonthlyReportChoice>(
                              initialValue: _choice,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: widget.choiceLabel,
                                labelStyle: const TextStyle(fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              items: [
                                for (final c in widget.choices)
                                  DropdownMenuItem<MonthlyReportChoice>(
                                    value: c,
                                    child: Text(c.label),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _choice = v);
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _printing ? null : _print,
                        icon: _printing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print, size: 18),
                        label: const Text('พิมพ์'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.printColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.extension == 'xlsx'
                          ? 'รายงานนี้ออกเป็นไฟล์ Excel เท่านั้น'
                          : 'รายงานนี้ออกเป็นไฟล์ PDF',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
