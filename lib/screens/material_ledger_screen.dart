// lib/screens/material_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// เมนูรายงาน 14 > ใบรับจ่ายวัสดุ
///
/// เงื่อนไขค้นหาแยกช่วงวันที่ของฝั่งรับกับฝั่งจ่ายออกจากกัน ชื่อวัสดุค้นแบบ
/// มีคำนั้นอยู่ และคงเหลือเป็นเงื่อนไขไม่น้อยกว่าค่าที่กรอก (ค่าเริ่มต้น 0)
class MaterialLedgerScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService apiService;
  const MaterialLedgerScreen({
    super.key,
    required this.authProvider,
    required this.apiService,
  });

  @override
  State<MaterialLedgerScreen> createState() => _MaterialLedgerScreenState();
}

class _MaterialLedgerScreenState extends State<MaterialLedgerScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _balanceCtrl = TextEditingController(text: '0');

  DateTime? _receiveFrom;
  DateTime? _receiveTo;
  DateTime? _issueFrom;
  DateTime? _issueTo;

  bool _printing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  String? _iso(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  Future<void> _print() async {
    final balance = double.tryParse(_balanceCtrl.text.trim());
    if (_balanceCtrl.text.trim().isNotEmpty && balance == null) {
      context.showErrorSnackBar('คงเหลือต้องเป็นตัวเลข');
      return;
    }
    if (_receiveFrom != null &&
        _receiveTo != null &&
        _receiveTo!.isBefore(_receiveFrom!)) {
      context.showErrorSnackBar('ช่วงวันที่รับไม่ถูกต้อง');
      return;
    }
    if (_issueFrom != null &&
        _issueTo != null &&
        _issueTo!.isBefore(_issueFrom!)) {
      context.showErrorSnackBar('ช่วงวันที่จ่ายไม่ถูกต้อง');
      return;
    }

    setState(() => _printing = true);
    try {
      final bytes = await widget.apiService.downloadMaterialLedger(
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        minBalance: balance ?? 0,
        receiveFrom: _iso(_receiveFrom),
        receiveTo: _iso(_receiveTo),
        issueFrom: _iso(_issueFrom),
        issueTo: _iso(_issueTo),
      );

      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'ใบรับจ่ายวัสดุ.xlsx';
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

  void _clear() {
    setState(() {
      _nameCtrl.clear();
      _balanceCtrl.text = '0';
      _receiveFrom = null;
      _receiveTo = null;
      _issueFrom = null;
      _issueTo = null;
    });
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
          'ใบรับจ่ายวัสดุ',
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
            constraints: const BoxConstraints(maxWidth: 1000),
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
                    _section('วันที่รับวัสดุ'),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _dateField('ตั้งแต่วันที่', _receiveFrom, (d) {
                          setState(() => _receiveFrom = d);
                        }),
                        _dateField('ถึงวันที่', _receiveTo, (d) {
                          setState(() => _receiveTo = d);
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _section('วันที่จ่ายวัสดุ'),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _dateField('ตั้งแต่วันที่', _issueFrom, (d) {
                          setState(() => _issueFrom = d);
                        }),
                        _dateField('ถึงวันที่', _issueTo, (d) {
                          setState(() => _issueTo = d);
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _section('เงื่อนไขอื่น'),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: _decoration('ชื่อวัสดุ'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _balanceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            textAlign: TextAlign.right,
                            decoration: _decoration('คงเหลือ  >='),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _printing ? null : _clear,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('ล้าง'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.neutralColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เว้นช่วงวันที่ไว้ = ไม่จำกัดช่วง • รายงานนี้ออกเป็นไฟล์ Excel เท่านั้น',
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

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
  );

  /// ช่องวันที่แบบอ่านอย่างเดียว กดแล้วเปิดปฏิทินกลางของระบบ
  ///
  /// ใช้ [Util.dateFieldPickerNullable] เพราะช่องค้นหาว่างได้ กดยกเลิกแล้ว
  /// ต้องไม่กลายเป็นกรองวันนี้โดยไม่ตั้งใจ ปุ่มกากบาทล้างค่าในช่องนั้น
  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> set) {
    return SizedBox(
      width: 220,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: value == null ? '' : Util.formatThaiDate(value),
        ),
        decoration: _decoration(label).copyWith(
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => set(null),
                ),
        ),
        style: const TextStyle(fontSize: 14),
        onTap: () async {
          final picked = await Util.dateFieldPickerNullable(context, value);
          if (picked != null) set(picked);
        },
      ),
    );
  }
}
