// lib/screens/annual_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../utils/snackbar_helper.dart';

/// หน้าจอกลางของรายงานรายปี — เลือกปีอย่างเดียวแล้วกดพิมพ์
///
/// โครงเดียวกับ [MonthlyReportScreen] แต่ไม่มีช่องเดือน ใช้กับรายงานที่คิด
/// ทั้งปีงบประมาณ ส่งชื่อเรื่องกับฟังก์ชันดาวน์โหลดเข้ามา ไม่ต้องทำหน้าจอใหม่ทุกเมนู
class AnnualReportScreen extends StatefulWidget {
  /// ชื่อที่แสดงบนแถบด้านบน
  final String title;

  /// ชื่อไฟล์ที่ดาวน์โหลด ระบบจะต่อท้ายด้วยเดือนและปีให้เอง
  final String fileBaseName;

  /// ฟังก์ชันเรียก API ออกรายงาน คืนค่าเป็นเนื้อไฟล์
  final Future<List<int>> Function(int year) download;

  /// คำอธิบายใต้ปุ่มพิมพ์ เช่น ความหมายของปีงบประมาณ
  final String? note;

  /// นามสกุลไฟล์ ปัจจุบันรายงานกลุ่มนี้ออกเป็น Excel อย่างเดียว
  final String extension;

  const AnnualReportScreen({
    super.key,
    required this.title,
    required this.fileBaseName,
    required this.download,
    this.note,
    this.extension = 'xlsx',
  });

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  final TextEditingController _yearCtrl = TextEditingController();
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _yearCtrl.text = '${DateTime.now().year + 543}';
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
      final bytes = await widget.download(year);

      final isPdf = widget.extension == 'pdf';
      final mime = isPdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final blob = html.Blob([Uint8List.fromList(bytes)], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = '${widget.fileBaseName}_$year.${widget.extension}';
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
          icon: const Icon(Icons.arrow_back),
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
                      widget.note ??
                          (widget.extension == 'xlsx'
                              ? 'รายงานนี้ออกเป็นไฟล์ Excel เท่านั้น'
                              : 'รายงานนี้ออกเป็นไฟล์ PDF'),
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
