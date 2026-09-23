// lib/screens/center_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

/// เมนูรายงาน 3 > แผนการใช้ศูนย์
///
/// หน้านี้ไม่มีตารางผลลัพธ์ มีแต่เงื่อนไขปีและช่วงเดือน แล้วกดพิมพ์
/// ออกเป็นไฟล์ Excel อย่างเดียวตามที่ผู้ใช้กำหนด (ปฏิทินแถบสีของการใช้ห้องกิจกรรม)
class CenterPlanScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService apiService;
  const CenterPlanScreen({
    super.key,
    required this.authProvider,
    required this.apiService,
  });

  @override
  State<CenterPlanScreen> createState() => _CenterPlanScreenState();
}

class _CenterPlanScreenState extends State<CenterPlanScreen> {
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
  int _fromMonth = DateTime.now().month;
  int _toMonth = DateTime.now().month;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    // ตั้งต้นเป็นปี พ.ศ. ปัจจุบัน และเดือนปัจจุบันถึงสิ้นปี
    _yearCtrl.text = '${DateTime.now().year + 543}';
    _toMonth = 12;
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
    if (_toMonth < _fromMonth) {
      context.showErrorSnackBar('เดือนสิ้นสุดต้องไม่น้อยกว่าเดือนเริ่มต้น');
      return;
    }

    setState(() => _printing = true);
    try {
      final bytes = await widget.apiService.downloadCenterPlanReport(
        year: year,
        fromMonth: _fromMonth,
        toMonth: _toMonth,
      );

      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'แผนการใช้ศูนย์_$year.xlsx';
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
        title: const Text(
          'แผนการใช้ศูนย์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        _monthDropdown(
                          label: 'เดือน',
                          value: _fromMonth,
                          onChanged: (v) => setState(() {
                            _fromMonth = v;
                            if (_toMonth < v) _toMonth = v;
                          }),
                        ),
                        _monthDropdown(
                          label: 'ถึง เดือน',
                          value: _toMonth,
                          onChanged: (v) => setState(() => _toMonth = v),
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
                    const Text(
                      'รายงานนี้ออกเป็นไฟล์ Excel เท่านั้น',
                      style: TextStyle(
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

  Widget _monthDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            DropdownMenuItem<int>(value: m, child: Text(_monthNames[m - 1])),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
