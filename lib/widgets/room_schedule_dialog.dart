// lib/widgets/room_schedule_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// แก้ไขตารางการใช้ห้องหนึ่งคืน — แก้ได้เฉพาะราคาและหมายเหตุ
///
/// หมายเลขห้องกับวันที่เป็นคีย์ของ t_schedule จึงแสดงอย่างเดียว
/// ตอนบันทึกส่งทุกฟิลด์เดิมกลับไปด้วย ฟิลด์ที่ไม่ได้แสดงจะได้ไม่ถูกล้างเป็น null
///
/// ปิดด้วย true เมื่อบันทึกสำเร็จ
class RoomScheduleDialog extends StatefulWidget {
  final ApiService apiService;
  final String roomNo;
  final Schedule schedule;

  const RoomScheduleDialog({
    super.key,
    required this.apiService,
    required this.roomNo,
    required this.schedule,
  });

  @override
  State<RoomScheduleDialog> createState() => _RoomScheduleDialogState();
}

class _RoomScheduleDialogState extends State<RoomScheduleDialog> {
  /// decimal(10,2) ในฐานข้อมูล
  static const double _maxPrice = 99999999.99;

  /// remark varchar(45) ในฐานข้อมูล
  static const int _maxRemark = 45;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _remarkCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: _priceText(widget.schedule.price));
    _remarkCtrl = TextEditingController(text: widget.schedule.remark ?? '');
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  /// 800.0 → "800", 800.5 → "800.50"
  static String _priceText(double? p) {
    if (p == null) return '';
    return p == p.truncateToDouble() ? p.toInt().toString() : p.toStringAsFixed(2);
  }

  static double? _parsePrice(String v) =>
      double.tryParse(v.trim().replaceAll(',', ''));

  String get _dateText {
    final d = DateTime.tryParse(widget.schedule.scheduleDate ?? '');
    return d == null ? '-' : Util.toBuddhistYearDisplay(d);
  }

  static String _describe(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      String detail = '';
      if (data is Map) {
        detail = (data['message'] ?? data['error'] ?? '').toString();
      } else if (data is String && data.trim().isNotEmpty) {
        detail = data.trim();
      }
      if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
      return 'บันทึกไม่สำเร็จ (HTTP ${code ?? '-'})'
          '${detail.isEmpty ? '' : '\n$detail'}';
    }
    return 'บันทึกไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}';
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final s = widget.schedule;
    setState(() => _saving = true);
    try {
      await widget.apiService.updateSchedule(
        // คีย์เดิมทั้งสี่ — ไม่เปลี่ยน จึงเป็นการแก้แถวเดิม ไม่ใช่ย้ายรายการ
        roomID: s.roomID!,
        scheduleDate: s.scheduleDate!,
        fromTime: s.fromTime!,
        toTime: s.toTime!,
        // ส่งทุกฟิลด์เดิมกลับไป เปลี่ยนเฉพาะราคาและหมายเหตุ
        d: s.copyWith(
          price: _parsePrice(_priceCtrl.text),
          remark: _remarkCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error updating schedule: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      // ใช้ overlay เพราะ SnackBar ปกติจะถูก dialog นี้บัง
      context.showOverlayMessage(
        _describe(e),
        icon: Icons.error_outline,
        background: Colors.red,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _readOnly('หมายเลขห้อง', widget.roomNo),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: _readOnly('วันที่', _dateText)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceCtrl,
                        enabled: !_saving,
                        decoration: _input('ราคา'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: (v) {
                          final p = _parsePrice(v ?? '');
                          if (p == null) return 'กรอกราคาเป็นตัวเลข';
                          if (p < 0) return 'ราคาต้องไม่ติดลบ';
                          if (p > _maxPrice) return 'ราคาเกินที่ระบบรองรับ';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkCtrl,
                        enabled: !_saving,
                        decoration: _input('หมายเหตุ'),
                        maxLength: _maxRemark,
                      ),
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  /// ค่าที่แสดงอย่างเดียว — ใช้กรอบเดียวกับช่องกรอกแต่พื้นเทา ให้รู้ว่าแก้ไม่ได้
  Widget _readOnly(String label, String value) {
    return InputDecorator(
      decoration: _input(
        label,
      ).copyWith(filled: true, fillColor: Colors.grey.shade100),
      child: Text(value, style: const TextStyle(fontSize: 15)),
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
          const Icon(Icons.edit_calendar_outlined, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'แก้ไขการใช้ห้องพัก',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            'ห้อง ${widget.roomNo}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF43A047,
              ).withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('ยกเลิก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
