// lib/widgets/bookroomdetail_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookroomdetail.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/util.dart';

/// dialog เพิ่ม/แก้ไขรายการห้องพักของการจอง (ตาราง bookroomdetail)
///
/// pop คืนค่า `true` เมื่อบันทึกสำเร็จ เพื่อให้หน้าเรียกโหลดรายการใหม่
class BookRoomDetailDialog extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// null = โหมดเพิ่มรายการใหม่
  final BookRoomDetail? detail;

  /// ประเภทห้องที่เลือกได้ (กรอง type == 'R' มาแล้ว)
  final List<Roomtype> roomTypes;

  /// ค่าเริ่มต้นของวันที่ ใช้ตอนเพิ่มรายการใหม่ — ปกติคือช่วงวันที่ของใบจอง
  final DateTime? defaultStartDate;
  final DateTime? defaultStopDate;

  const BookRoomDetailDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.roomTypes,
    this.detail,
    this.defaultStartDate,
    this.defaultStopDate,
  });

  @override
  State<BookRoomDetailDialog> createState() => _BookRoomDetailDialogState();
}

class _BookRoomDetailDialogState extends State<BookRoomDetailDialog> {
  final _formKey = GlobalKey<FormState>();

  final _sequenceCtrl = TextEditingController();
  final _numberMemberCtrl = TextEditingController();
  final _numberRoomCtrl = TextEditingController();

  int? _roomTypeId;
  late DateTime _startDate;
  late DateTime _stopDate;

  bool _isSaving = false;
  String? _error;

  bool get isEdit => widget.detail != null;

  @override
  void initState() {
    super.initState();

    final d = widget.detail;
    _startDate =
        _parse(d?.startDate) ?? widget.defaultStartDate ?? DateTime.now();
    _stopDate =
        _parse(d?.stopDate) ??
        widget.defaultStopDate ??
        DateTime.now().add(const Duration(days: 1));

    if (d != null) {
      _sequenceCtrl.text = '${d.sequence ?? ''}';
      _numberMemberCtrl.text = '${d.numberMember ?? ''}';
      _numberRoomCtrl.text = '${d.numberRoom ?? ''}';
      _roomTypeId = d.roomTypeId;
    }

    // ถ้า roomTypeId ที่ได้มาไม่มีในรายการ ปล่อยเป็น null ไม่งั้น dropdown จะ assert
    if (!widget.roomTypes.any((r) => r.roomtypeID == _roomTypeId)) {
      _roomTypeId = null;
    }
  }

  static DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  @override
  void dispose() {
    _sequenceCtrl.dispose();
    _numberMemberCtrl.dispose();
    _numberRoomCtrl.dispose();
    super.dispose();
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
      final selected = widget.roomTypes.firstWhere(
        (r) => r.roomtypeID == _roomTypeId,
        orElse: () => widget.roomTypes.first,
      );

      final payload = BookRoomDetail(
        bookRoomId: widget.detail?.bookRoomId,
        bookId: widget.bookId,
        roomTypeId: _roomTypeId,
        numberMember: int.tryParse(_numberMemberCtrl.text),
        numberRoom: int.tryParse(_numberRoomCtrl.text),
        sequence: int.tryParse(_sequenceCtrl.text),
        startDate: fmt.format(_startDate),
        stopDate: fmt.format(_stopDate),
        // ตอนแก้ไขคงค่าเดิมไว้ ตอนเพิ่มใหม่ใช้ราคาของประเภทห้องที่เลือก
        status: widget.detail?.status,
        price: widget.detail?.price ?? selected.price?.round(),
        name: selected.name,
      );

      if (isEdit) {
        await widget.apiService.updateBookRoomDetail(
          widget.detail!.bookRoomId!,
          payload,
        );
      } else {
        await widget.apiService.createBookRoomDetail(payload);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving bookroomdetail: $e');
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 20,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 18),
                      _numField('ลำดับ', _sequenceCtrl, required: false),
                      const SizedBox(height: 18),
                      _label('ประเภทห้อง'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _roomTypeId,
                        isExpanded: true,
                        decoration: _decoration(hint: 'เลือกประเภทห้อง'),
                        items: widget.roomTypes
                            .map(
                              (r) => DropdownMenuItem<int>(
                                value: r.roomtypeID,
                                child: Text(
                                  r.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => _roomTypeId = v),
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกประเภทห้อง' : null,
                      ),
                      const SizedBox(height: 18),
                      _numField(
                        'จำนวนผู้ใช้บริการ',
                        _numberMemberCtrl,
                        suffix: 'คน',
                      ),
                      const SizedBox(height: 18),
                      _numField('จำนวนห้อง', _numberRoomCtrl, suffix: 'ห้อง'),
                      const SizedBox(height: 18),
                      _dateField('วันที่เริ่มต้น', _startDate, () async {
                        final p = await Util.dateFieldPicker(
                          context,
                          _startDate,
                        );
                        if (p != _startDate) setState(() => _startDate = p);
                      }),
                      const SizedBox(height: 18),
                      _dateField('วันที่สิ้นสุด', _stopDate, () async {
                        final p = await Util.dateFieldPicker(
                          context,
                          _stopDate,
                        );
                        if (p != _stopDate) setState(() => _stopDate = p);
                      }),
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
            isEdit ? 'แก้ไขรายการห้องพัก' : 'เพิ่มรายการห้องพัก',
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
          validator: required
              ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอก$label' : null
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
