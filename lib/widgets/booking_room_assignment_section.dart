// lib/widgets/booking_room_assignment_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/room_assignment.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'room_assignment_dialog.dart';

/// ตาราง "ห้องพักที่กำหนดแล้ว" ของใบจองหนึ่ง
///
/// แสดง bookdetail เฉพาะประเภทห้องพัก เรียงตามลำดับ (sequence) ทุกค่าในตาราง
/// แสดงอย่างเดียว การแก้ไขทำผ่าน [RoomAssignmentDialog]
///
/// API ส่งมาทุกแถวในครั้งเดียว (ใบจองหนึ่งมีห้องแค่หลักสิบ) จึงแบ่งหน้าฝั่งนี้เอง
class BookingRoomAssignmentSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// แจ้งให้โหลดใหม่ — ใช้หลังบันทึกกำหนดห้องพักจาก dialog ตรวจสอบห้องว่าง
  final Listenable? refreshSignal;

  const BookingRoomAssignmentSection({
    super.key,
    required this.apiService,
    required this.bookId,
    this.refreshSignal,
  });

  @override
  State<BookingRoomAssignmentSection> createState() =>
      _BookingRoomAssignmentSectionState();
}

class _BookingRoomAssignmentSectionState
    extends State<BookingRoomAssignmentSection> {
  static const int _size = 5; // ค่าเริ่มต้น row/page = 5

  List<RoomAssignment> _all = [];
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant BookingRoomAssignmentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_onRefresh);
      widget.refreshSignal?.addListener(_onRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() => _load();

  int get _totalPages => _all.isEmpty ? 1 : (_all.length + _size - 1) ~/ _size;

  List<RoomAssignment> get _pageItems =>
      _all.skip(_page * _size).take(_size).toList();

  /// ลำดับที่มีมากกว่าหนึ่งห้อง — ใช้ขึ้นเครื่องหมายเตือนในตาราง
  ///
  /// ดูจากทุกแถว ไม่ใช่แค่หน้าที่เปิดอยู่ เพราะเลขที่ชนกันอาจอยู่คนละหน้า
  Set<int> get _duplicateSequences {
    final seen = <int>{};
    final dup = <int>{};
    for (final r in _all) {
      final s = r.sequence;
      if (s != null && !seen.add(s)) dup.add(s);
    }
    return dup;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getRoomAssignments(widget.bookId);
      if (!mounted) return;
      setState(() {
        _all = list;
        // ลบแถวสุดท้ายของหน้าท้ายแล้วหน้านั้นจะหายไป ถอยกลับให้อยู่ในช่วง
        if (_page > _totalPages - 1) _page = _totalPages - 1;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading room assignments: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึงรายการห้องพักที่กำหนดแล้ว');
        _loading = false;
      });
    }
  }

  static String _describeApiError(Object e, String what) {
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
      return '$what ไม่สำเร็จ (HTTP ${code ?? '-'})'
          '${detail.isEmpty ? '' : '\n$detail'}';
    }
    return '$what ไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}';
  }

  Future<void> _edit(RoomAssignment r) async {
    if (r.bookIdDetail == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการแก้ไข');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomAssignmentDialog(
        apiService: widget.apiService,
        assignment: r,
        // เทียบลำดับซ้ำกับทุกแถวของใบจอง ไม่ใช่แค่หน้าที่เปิดอยู่
        others: _all.where((x) => x.bookIdDetail != r.bookIdDetail).toList(),
      ),
    );
    if (ok != true || !mounted) return;
    context.showSuccessSnackBar('บันทึกการแก้ไขเรียบร้อยแล้ว');
    await _load();
  }

  Future<void> _delete(RoomAssignment r) async {
    if (r.bookIdDetail == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการลบ');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบห้องนี้ออกจากการกำหนดห้องพักใช่หรือไม่?\n'
      'ห้อง ${r.roomNo ?? '-'} ลำดับ ${r.sequence ?? '-'}',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteBookDetail(r.bookIdDetail!);
      if (!mounted) return;
      context.showSuccessSnackBar('ลบรายการเรียบร้อยแล้ว');
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting bookdetail: $e');
      if (mounted) {
        context.showErrorSnackBar(_describeApiError(e, 'ลบรายการ'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _errorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_all.isEmpty)
            _empty()
          else ...[_table(), const SizedBox(height: 12), _footerRow()],
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.king_bed_outlined,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'ห้องพักที่กำหนดแล้ว',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: Colors.red.shade700)),
          ),
          TextButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bed_outlined, size: 34, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มีห้องพักที่กำหนด',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
    final dupSeqs = _duplicateSequences;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        // ตารางกว้างกว่าจอบนมือถือ ให้เลื่อนแนวนอนในกล่องตัวเอง
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            headingRowHeight: 52,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            columnSpacing: 22,
            horizontalMargin: 18,
            columns: const [
              DataColumn(label: _ColHead('ลำดับ'), numeric: true),
              DataColumn(label: _ColHead('หมายเลขห้อง')),
              DataColumn(label: _ColHead('ชื่อ-สกุล')),
              DataColumn(label: _ColHead('เบอร์ติดต่อ')),
              DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(label: _ColHead('สถานะ')),
              DataColumn(label: _ColHead('')),
            ],
            rows: _pageItems.map((r) {
              return DataRow(
                cells: [
                  DataCell(_sequenceCell(r, dupSeqs)),
                  DataCell(_cellText(r.roomNo ?? '-')),
                  DataCell(_cellText(_orDash(r.contractName))),
                  DataCell(_cellText(_orDash(r.contractTel))),
                  DataCell(_cellText(Util.formatThaiDateStr(r.startDate))),
                  DataCell(_cellText(Util.formatThaiDateStr(r.stopDate))),
                  DataCell(_cellText(r.statusName ?? '${r.status ?? '-'}')),
                  DataCell(_rowActions(r)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '-' : v;

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  /// ลำดับที่ชนกับห้องอื่นขึ้นไอคอนเตือนสีส้ม ชี้เมาส์เพื่อดูว่าชนกับห้องไหน
  Widget _sequenceCell(RoomAssignment r, Set<int> dupSeqs) {
    final seq = r.sequence;
    if (seq == null || !dupSeqs.contains(seq)) {
      return _cellText('${seq ?? '-'}');
    }
    final others = _all
        .where((x) => x.sequence == seq && x.bookIdDetail != r.bookIdDetail)
        .map((x) => x.roomNo ?? '-')
        .join(', ');
    return Tooltip(
      message: 'ลำดับซ้ำกับห้อง $others',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            '$seq',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowActions(RoomAssignment r) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _edit(r),
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          tooltip: 'ลบข้อมูล',
          onTap: () => _delete(r),
        ),
      ],
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  /// จำนวนทั้งหมด + ตัวแบ่งหน้า (แบ่งฝั่ง Flutter จึงแค่เปลี่ยนหน้า ไม่ต้องยิง API)
  Widget _footerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'ทั้งหมด ${_all.length} ห้อง',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _page > 0 ? () => setState(() => _page = 0) : null,
          icon: const Icon(Icons.first_page),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          icon: const Icon(Icons.chevron_left),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${_page + 1} / $_totalPages',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        IconButton(
          onPressed: _page < _totalPages - 1
              ? () => setState(() => _page++)
              : null,
          icon: const Icon(Icons.chevron_right),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          onPressed: _page < _totalPages - 1
              ? () => setState(() => _page = _totalPages - 1)
              : null,
          icon: const Icon(Icons.last_page),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

/// หัวคอลัมน์ของตารางห้องพักที่กำหนดแล้ว
class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
