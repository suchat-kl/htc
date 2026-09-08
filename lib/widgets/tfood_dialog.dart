// lib/widgets/tfood_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/foodtype.dart';
import '../models/tfood.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/util.dart';

/// dialog เพิ่ม/แก้ไขรายการอาหารของใบจอง (ตาราง tfood)
///
/// pop คืนค่า `true` เมื่อบันทึกสำเร็จ เพื่อให้หน้าเรียกโหลดรายการใหม่
class TfoodDialog extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// null = โหมดเพิ่มรายการใหม่
  final Tfood? tfood;

  /// รายการอาหารที่เลือกได้ มาจาก getFoodtypeList()
  final List<Foodtype> foodtypes;

  /// ค่าเริ่มต้นของวันที่ตอนเพิ่มใหม่ ปกติคือช่วงวันที่ของใบจอง
  final DateTime? defaultStartDate;
  final DateTime? defaultStopDate;

  const TfoodDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.foodtypes,
    this.tfood,
    this.defaultStartDate,
    this.defaultStopDate,
  });

  @override
  State<TfoodDialog> createState() => _TfoodDialogState();
}

class _TfoodDialogState extends State<TfoodDialog> {
  final _formKey = GlobalKey<FormState>();

  final _sequenceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _timesCtrl = TextEditingController();

  int? _foodtypeId;
  late DateTime _startDate;
  late DateTime _stopDate;

  bool _isSaving = false;
  String? _error;

  bool get isEdit => widget.tfood != null;

  static final _money = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();

    final t = widget.tfood;
    _startDate = _parse(t?.startdate) ?? widget.defaultStartDate ?? DateTime.now();
    _stopDate = _parse(t?.stopdate) ??
        widget.defaultStopDate ??
        DateTime.now().add(const Duration(days: 1));

    if (t != null) {
      _sequenceCtrl.text = '${t.sequence ?? ''}';
      _priceCtrl.text = '${t.price ?? ''}';
      _amountCtrl.text = '${t.amount ?? ''}';
      _timesCtrl.text = '${t.times ?? ''}';
      _foodtypeId = t.foodtypeid;
    }

    // ถ้า foodtypeid ที่ได้มาไม่มีในรายการ ปล่อยเป็น null ไม่งั้น dropdown จะ assert
    if (!widget.foodtypes.any((f) => f.id == _foodtypeId)) {
      _foodtypeId = null;
    }
  }

  static DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  @override
  void dispose() {
    _sequenceCtrl.dispose();
    _priceCtrl.dispose();
    _amountCtrl.dispose();
    _timesCtrl.dispose();
    super.dispose();
  }

  /// จำนวนเงิน = ราคา/คน x คน x มื้อ — คำนวณให้ดูสดๆ ระหว่างกรอก
  int get _total {
    final p = int.tryParse(_priceCtrl.text) ?? 0;
    final a = int.tryParse(_amountCtrl.text) ?? 0;
    final t = int.tryParse(_timesCtrl.text) ?? 0;
    return p * a * t;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_stopDate.isBefore(_startDate)) {
      setState(() => _error = 'วันที่สิ้นสุดต้องไม่อยู่ก่อนวันที่เริ่มต้น');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final payload = Tfood(
        id: widget.tfood?.id,
        bookID: widget.bookId,
        foodtypeid: _foodtypeId,
        price: int.tryParse(_priceCtrl.text) ?? 0,
        amount: int.tryParse(_amountCtrl.text) ?? 0,
        times: int.tryParse(_timesCtrl.text) ?? 0,
        sequence: int.tryParse(_sequenceCtrl.text) ?? 0,
        startdate: fmt.format(_startDate),
        stopdate: fmt.format(_stopDate),
      );

      if (isEdit) {
        await widget.apiService.updateTfood(widget.tfood!.id!, payload);
      } else {
        await widget.apiService.createTfood(payload);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving tfood: $e');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 620 ? 560 : sw,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _errorBox(_error!),
                        const SizedBox(height: 16),
                      ],
                      _numField('ลำดับ', _sequenceCtrl, required: false),
                      const SizedBox(height: 18),
                      _label('รายการ'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _foodtypeId,
                        isExpanded: true,
                        decoration: _decoration(hint: 'เลือกรายการอาหาร'),
                        items: widget.foodtypes
                            .where((f) => f.id != null)
                            .map(
                              (f) => DropdownMenuItem<int>(
                                value: f.id,
                                child: Text(
                                  f.name ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (int? v) {
                                setState(() {
                                  _foodtypeId = v;
                                  // เติมราคาตั้งต้นจากรายการที่เลือก
                                  // ผู้ใช้ยังแก้เองได้
                                  final f = widget.foodtypes.firstWhere(
                                    (e) => e.id == v,
                                    orElse: () => Foodtype(),
                                  );
                                  if ((f.price ?? 0) > 0) {
                                    _priceCtrl.text = '${f.price}';
                                  }
                                });
                              },
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกรายการอาหาร' : null,
                      ),
                      const SizedBox(height: 18),
                      _numField('ราคา/คน', _priceCtrl, suffix: 'บาท'),
                      const SizedBox(height: 18),
                      _numField('คน', _amountCtrl, suffix: 'คน'),
                      const SizedBox(height: 18),
                      _numField('มื้อ', _timesCtrl, suffix: 'มื้อ'),
                      const SizedBox(height: 18),
                      _dateField('วันที่เริ่มต้น', _startDate, () async {
                        final p =
                            await Util.dateFieldPicker(context, _startDate);
                        if (p != _startDate) setState(() => _startDate = p);
                      }),
                      const SizedBox(height: 18),
                      _dateField('วันที่สิ้นสุด', _stopDate, () async {
                        final p = await Util.dateFieldPicker(context, _stopDate);
                        if (p != _stopDate) setState(() => _stopDate = p);
                      }),
                      const SizedBox(height: 18),
                      _totalPreview(),
                    ],
                  ),
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'แก้ไขรายการอาหาร' : 'เพิ่มรายการอาหาร',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// แสดงจำนวนเงินที่คำนวณได้ ให้เห็นก่อนกดบันทึก
  Widget _totalPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'จำนวนเงิน (ราคา/คน × คน × มื้อ)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            _money.format(_total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _label(String l) => Text(
    l,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  InputDecoration _decoration({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      suffixText: suffix,
      suffixStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
    );
  }

  Widget _numField(
    String label,
    TextEditingController ctrl, {
    String? suffix,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _decoration(suffix: suffix),
          style: const TextStyle(fontSize: 14),
          // อัปเดตยอดรวมทันทีที่พิมพ์
          onChanged: (_) => setState(() {}),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอก$label'
                    : null
              : null,
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime d, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isSaving ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Util.formatThaiDate(d),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
