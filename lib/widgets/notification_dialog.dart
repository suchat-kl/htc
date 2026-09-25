// lib/widgets/notification_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/notification_item.dart';
import '../services/api_service.dart';
import '../utils/util.dart';

/// หน้าต่างเพิ่ม/แก้ไขประกาศประชาสัมพันธ์
class NotificationDialog extends StatefulWidget {
  final ApiService apiService;

  /// ไม่ส่งมา = เพิ่มรายการใหม่
  final NotificationItem? item;

  const NotificationDialog({super.key, required this.apiService, this.item});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _sequenceCtrl = TextEditingController(text: '0');

  DateTime? _startDate;
  DateTime? _stopDate;
  String _status = '1';

  bool _saving = false;
  String? _error;

  bool get isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _titleCtrl.text = i.title ?? '';
      _messageCtrl.text = i.message ?? '';
      _sequenceCtrl.text = '${i.sequence ?? 0}';
      _status = i.status ?? '1';
      _startDate = _parse(i.startDate);
      _stopDate = _parse(i.stopDate);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _sequenceCtrl.dispose();
    super.dispose();
  }

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  static String? _format(DateTime? d) {
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null && _stopDate != null && _stopDate!.isBefore(_startDate!)) {
      setState(() => _error = 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่มประกาศ');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = NotificationItem(
      id: widget.item?.id,
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      startDate: _format(_startDate),
      stopDate: _format(_stopDate),
      sequence: int.tryParse(_sequenceCtrl.text.trim()) ?? 0,
      status: _status,
    );

    try {
      if (isEdit) {
        await widget.apiService.updateNotification(widget.item!.id!, data);
      } else {
        await widget.apiService.createNotification(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'แก้ไขประกาศ' : 'เพิ่มประกาศ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.dangerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.dangerColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.dangerColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _label('หัวเรื่อง'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 200,
                  decoration: _input('เช่น งดให้บริการห้องพักช่วงปรับปรุง'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณากรอกหัวเรื่อง'
                      : null,
                ),
                const SizedBox(height: 8),

                _label('เนื้อความ'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: _input('รายละเอียดที่ต้องการประกาศ'),
                ),
                const SizedBox(height: 8),

                // ช่วงวันที่เว้นว่างได้ทั้งสองข้าง ไม่ได้บังคับเหมือนระบบเดิม
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        'วันที่เริ่มประกาศ',
                        _startDate,
                        'ว่าง = ประกาศทันที',
                        (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _dateField(
                        'วันที่สิ้นสุด',
                        _stopDate,
                        'ว่าง = ไม่หมดอายุ',
                        (d) => setState(() => _stopDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('ลำดับการแสดง'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _sequenceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: _input('น้อยมาก่อน'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('สถานะ'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: _input(''),
                            items: const [
                              DropdownMenuItem(
                                value: '1',
                                child: Text('ใช้งาน'),
                              ),
                              DropdownMenuItem(
                                value: '2',
                                child: Text('ไม่ใช้งาน'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v ?? '1'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(isEdit ? 'อัปเดต' : 'บันทึก'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.saveColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint.isEmpty ? null : hint,
        hintStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: AppTheme.fieldFillColor,
        isDense: true,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _dateField(
    String label,
    DateTime? value,
    String emptyHint,
    ValueChanged<DateTime?> onPicked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await Util.dateFieldPickerNullable(context, value);
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.fieldFillColor,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null ? emptyHint : Util.formatThaiDate(value),
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // ต้องล้างค่าได้ เพราะช่องวันที่เว้นว่างมีความหมาย
                if (value != null)
                  InkWell(
                    onTap: () => onPicked(null),
                    child: const Icon(Icons.clear,
                        size: 16, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
