// lib/widgets/room_assignment_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/bookdetail.dart';
import '../models/documentstatus.dart';
import '../models/room_assignment.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// แก้ไขห้องพักที่กำหนดแล้วหนึ่งแถว
///
/// แสดงครบทั้ง 7 ค่า แต่แก้ได้เฉพาะ ลำดับ ชื่อ-สกุล เบอร์ติดต่อ และสถานะ
/// หมายเลขห้องกับช่วงวันที่เป็นข้อมูลการจอง จึงแสดงอย่างเดียว
///
/// ปิดด้วย true เมื่อบันทึกสำเร็จ
class RoomAssignmentDialog extends StatefulWidget {
  final ApiService apiService;
  final RoomAssignment assignment;

  /// แถวอื่นในใบจองเดียวกัน — ใช้เตือนเมื่อลำดับซ้ำ
  final List<RoomAssignment> others;

  const RoomAssignmentDialog({
    super.key,
    required this.apiService,
    required this.assignment,
    this.others = const [],
  });

  @override
  State<RoomAssignmentDialog> createState() => _RoomAssignmentDialogState();
}

class _RoomAssignmentDialogState extends State<RoomAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _seqCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _telCtrl;

  List<DocumentStatus> _statuses = [];
  bool _loadingStatuses = true;
  int? _statusId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _seqCtrl = TextEditingController(text: a.sequence?.toString() ?? '');
    _nameCtrl = TextEditingController(text: a.contractName ?? '');
    _telCtrl = TextEditingController(text: a.contractTel ?? '');
    _statusId = a.status;
    _loadStatuses();
  }

  @override
  void dispose() {
    _seqCtrl.dispose();
    _nameCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    // page/size ใช้ค่าเริ่มต้นของเมธอด และไม่ส่ง keyword
    final list = await widget.apiService.getDocumentStatusList();
    if (!mounted) return;
    setState(() {
      _statuses = list;
      _loadingStatuses = false;
    });
  }

  /// ห้องอื่นที่ใช้ลำดับเดียวกับค่าที่กรอกอยู่ตอนนี้
  List<RoomAssignment> get _duplicates {
    final seq = int.tryParse(_seqCtrl.text.trim());
    if (seq == null) return const [];
    return widget.others.where((o) => o.sequence == seq).toList();
  }

  static String _roomsOf(List<RoomAssignment> list) =>
      list.map((r) => r.roomNo ?? '-').join(', ');

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

    final seq = int.parse(_seqCtrl.text.trim());
    final dups = _duplicates;
    if (dups.isNotEmpty) {
      // เตือนแต่ไม่บังคับ — ตารางไม่มีข้อบังคับห้ามซ้ำ และผู้ใช้อาจกำลังสลับ
      // ลำดับของสองห้องทีละแถว ซึ่งระหว่างทางต้องซ้ำกันชั่วคราว
      final go = await AppDialog.showConfirm(
        context,
        'ลำดับ $seq ซ้ำกับห้อง ${_roomsOf(dups)}\n'
        'ต้องการบันทึกต่อหรือไม่?',
        confirmText: 'บันทึกต่อ',
      );
      if (go != true || !mounted) return;
    }

    final a = widget.assignment;
    setState(() => _saving = true);
    try {
      await widget.apiService.updateBookDetail(
        a.bookIdDetail!,
        BookDetail(
          bookIdDetail: a.bookIdDetail,
          // คอลัมน์ NOT NULL ส่งกลับไปครบ ไม่พึ่ง null-guard ฝั่ง backend อย่างเดียว
          bookRoomId: a.bookRoomId,
          bookId: a.bookId,
          roomId: a.roomId,
          roomNo: a.roomNo,
          startDate: a.startDate,
          stopDate: a.stopDate,
          // ค่าที่แก้ไขได้
          sequence: seq,
          contractName: _nameCtrl.text.trim(),
          contractTel: _telCtrl.text.trim(),
          status: _statusId,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error updating bookdetail: $e');
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
    final a = widget.assignment;
    final dups = _duplicates;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(a),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _seqCtrl,
                              enabled: !_saving,
                              decoration: _input('ลำดับ'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              // สร้างใหม่ทุกครั้งที่พิมพ์ เพื่ออัปเดตข้อความเตือนเลขซ้ำ
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 1) {
                                  return 'กรอกเป็นตัวเลขตั้งแต่ 1 ขึ้นไป';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _readOnly('หมายเลขห้อง', a.roomNo ?? '-'),
                          ),
                        ],
                      ),
                      if (dups.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _dupWarning(dups),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        enabled: !_saving,
                        decoration: _input('ชื่อ-สกุล'),
                        maxLength: 50,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telCtrl,
                        enabled: !_saving,
                        decoration: _input('เบอร์ติดต่อ'),
                        keyboardType: TextInputType.phone,
                        maxLength: 50,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _readOnly(
                              'วันที่เริ่มต้น',
                              Util.formatThaiDateStr(a.startDate),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _readOnly(
                              'วันที่สิ้นสุด',
                              Util.formatThaiDateStr(a.stopDate),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _statusField(a),
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
      // ซ่อนตัวนับ maxLength ให้ช่องสูงเท่ากันทุกช่อง
      counterText: '',
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

  Widget _dupWarning(List<RoomAssignment> dups) {
    final color = Colors.orange.shade800;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'ลำดับนี้ซ้ำกับห้อง ${_roomsOf(dups)}',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }

  Widget _statusField(RoomAssignment a) {
    if (_loadingStatuses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('กำลังโหลดรายการสถานะ...'),
          ],
        ),
      );
    }

    // getDocumentStatusList คืนรายการว่างเมื่อเรียก API ไม่สำเร็จ แทนที่จะโยน
    // error จึงต้องบอกผู้ใช้เอง ไม่งั้นจะเห็นแค่ช่องเลือกที่ว่างเปล่า
    if (_statuses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'โหลดรายการสถานะไม่สำเร็จ '
                'สถานะจะคงค่าเดิมไว้ (${a.statusName ?? '-'})',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _loadingStatuses = true);
                _loadStatuses();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    // ค่าเดิมต้องมีอยู่ในรายการ ไม่งั้น DropdownButton จะ assert
    final current = _statuses.any((s) => s.statusId == _statusId)
        ? _statusId
        : null;

    return DropdownButtonFormField<int>(
      initialValue: current,
      decoration: _input('สถานะ'),
      items: [
        for (final s in _statuses)
          if (s.statusId != null)
            DropdownMenuItem(
              value: s.statusId,
              child: Text(s.statusName ?? '-'),
            ),
      ],
      onChanged: _saving ? null : (v) => setState(() => _statusId = v),
    );
  }

  Widget _header(RoomAssignment a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'แก้ไขข้อมูลห้องพัก',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            'ห้อง ${a.roomNo ?? '-'}',
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
