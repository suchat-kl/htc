// lib/widgets/booking_room_assignment_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/bookdetail.dart';
import '../models/room_assignment.dart';
import '../models/statuscheck.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'app_pagination.dart';
import '../screens/room_schedule_screen.dart';
import 'room_assignment_dialog.dart';

/// ตาราง "ห้องพักที่กำหนดแล้ว" ของใบจองหนึ่ง
///
/// แสดง bookdetail ของห้องพัก (เรียก room-assignments ด้วย type 'R')
/// เรียงตามลำดับ (sequence) ทุกค่าในตาราง
/// แสดงอย่างเดียว การแก้ไขทำผ่าน [RoomAssignmentDialog]
///
/// API ส่งมาทุกแถวในครั้งเดียว (ใบจองหนึ่งมีห้องแค่หลักสิบ) จึงแบ่งหน้าฝั่งนี้เอง
class BookingRoomAssignmentSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// แจ้งให้โหลดใหม่ — ใช้หลังบันทึกกำหนดห้องพักจาก dialog ตรวจสอบห้องว่าง
  final Listenable? refreshSignal;

  /// โหมดแก้เฉพาะสถานะของแท็บ Check in
  ///
  /// ท้ายแถวเหลือแค่ปุ่มแก้ไข และ dialog แก้ได้เฉพาะสถานะ
  final bool statusOnly;

  const BookingRoomAssignmentSection({
    super.key,
    required this.apiService,
    required this.bookId,
    this.refreshSignal,
    this.statusOnly = false,
  });

  @override
  State<BookingRoomAssignmentSection> createState() =>
      _BookingRoomAssignmentSectionState();
}

class _BookingRoomAssignmentSectionState
    extends State<BookingRoomAssignmentSection> {
  /// แถวต่อหน้า เปลี่ยนได้จากตัวเลือกในแถบแบ่งหน้า
  int _size = 5;

  List<RoomAssignment> _all = [];

  /// รายการสถานะสำหรับ dropdown ที่หัวคอลัมน์ — โหลดเฉพาะโหมดแก้เฉพาะสถานะ
  List<StatusCheck> _statuses = [];

  /// สถานะที่เลือกไว้ที่หัวคอลัมน์ ยังไม่บันทึกจนกว่าจะกดปุ่มบันทึก
  int? _bulkStatus;

  bool _savingBulk = false;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onRefresh);
    _load();
    if (widget.statusOnly) _loadStatuses();
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

  Future<void> _loadStatuses() async {
    final list = await widget.apiService.getStatusCheckList(size: 100);
    if (!mounted) return;
    setState(() => _statuses = list);
  }

  /// บันทึกสถานะที่เลือกไว้ให้ทุกแถวในหน้านี้
  ///
  /// ยิงทีละแถวเพราะ backend ไม่มี endpoint อัปเดตหลายรายการ ข้ามแถวที่สถานะ
  /// ตรงอยู่แล้วเพื่อไม่ยิงเปล่า ส่งทุกฟิลด์เดิมกลับไปครบเหมือนตอนแก้ทีละแถว
  Future<void> _saveBulkStatus() async {
    final status = _bulkStatus;
    if (status == null || _savingBulk) return;

    final rows = _pageItems.where((r) => r.bookIdDetail != null).toList();
    setState(() => _savingBulk = true);
    var saved = 0;
    try {
      for (final r in rows) {
        if (r.status == status) continue;
        await widget.apiService.updateBookDetail(
          r.bookIdDetail!,
          BookDetail(
            bookIdDetail: r.bookIdDetail,
            bookRoomId: r.bookRoomId,
            bookId: r.bookId,
            roomId: r.roomId,
            roomNo: r.roomNo,
            startDate: r.startDate,
            stopDate: r.stopDate,
            sequence: r.sequence,
            contractName: r.contractName,
            contractTel: r.contractTel,
            status: status,
          ),
        );
        saved++;
      }
      if (!mounted) return;
      setState(() {
        _savingBulk = false;
        _bulkStatus = null;
      });
      context.showSuccessSnackBar(
        saved == 0
            ? 'ทุกแถวในหน้านี้เป็นสถานะนี้อยู่แล้ว'
            : 'บันทึกสถานะ $saved รายการเรียบร้อยแล้ว',
      );
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving bulk status: $e');
      if (!mounted) return;
      setState(() => _savingBulk = false);
      context.showErrorSnackBar(_describeApiError(e, 'บันทึกสถานะ'));
      // อาจบันทึกสำเร็จไปแล้วบางแถวก่อนจะพัง จึงโหลดใหม่ให้ตรงของจริง
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getRoomAssignments(
        bookId: widget.bookId,
        type: 'R',
      );
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

  /// เปิดรายละเอียดการใช้ห้อง (t_schedule) ของห้องนี้ ตามคืนที่พักของรายการ
  ///
  /// ส่งหมายเลขห้อง (A) วันเริ่มต้น (B) วันสิ้นสุด (C) และ roomId ไปให้หน้าจอ
  Future<void> _openSchedule(RoomAssignment r) async {
    final roomId = r.roomId;
    final start = r.startDate;
    final stop = r.stopDate;
    if (roomId == null || start == null || stop == null) {
      context.showErrorSnackBar(
        'รายการนี้ไม่มีรหัสห้องหรือช่วงวันที่ จึงดูรายละเอียดไม่ได้',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScheduleScreen(
          apiService: widget.apiService,
          roomId: roomId,
          roomNo: r.roomNo ?? '-',
          startDate: start,
          stopDate: stop,
        ),
      ),
    );
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
        statusOnly: widget.statusOnly,
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
          else ...[
            _table(),
            const SizedBox(height: 12),
            _footerRow(),
          ],
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
        color: AppTheme.fieldFillColor,
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
            headingRowHeight: widget.statusOnly ? 64 : 52,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            columnSpacing: 22,
            horizontalMargin: 18,
            columns: [
              const DataColumn(label: _ColHead('ลำดับ'), numeric: true),
              const DataColumn(label: _ColHead('หมายเลขห้อง')),
              const DataColumn(label: _ColHead('ชื่อ-สกุล')),
              const DataColumn(label: _ColHead('เบอร์ติดต่อ')),
              const DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              const DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(
                label: widget.statusOnly
                    ? _statusHeader()
                    : const _ColHead('สถานะ'),
              ),
              DataColumn(
                label: widget.statusOnly
                    ? _bulkSaveButton()
                    : const _ColHead(''),
              ),
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

                  DataCell(_statusCell(r)),
                  DataCell(_rowActions(r)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v;

  /// หัวคอลัมน์สถานะในโหมดแก้เฉพาะสถานะ — เลือกแล้วเปลี่ยนทุกแถวในหน้านี้
  ///
  /// ยังไม่บันทึกทันที รอกดปุ่มบันทึกที่หัวตาราง แถวที่รอบันทึกจะขึ้นเป็นสีส้ม
  Widget _statusHeader() {
    if (_statuses.isEmpty) return const _ColHead('สถานะ');
    return SizedBox(
      width: 190,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          isDense: true,
          value: _bulkStatus,
          hint: const _ColHead('สถานะ'),
          items: [
            for (final s in _statuses)
              if (s.status != null)
                DropdownMenuItem(
                  value: s.status,
                  child: Text(
                    s.name ?? '-',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
          onChanged: _savingBulk
              ? null
              : (v) => setState(() => _bulkStatus = v),
        ),
      ),
    );
  }

  /// ปุ่มบันทึกที่หัวตาราง — ใช้ได้เมื่อเลือกสถานะที่หัวคอลัมน์แล้ว
  Widget _bulkSaveButton() {
    final enabled = _bulkStatus != null && !_savingBulk;
    return ElevatedButton.icon(
      onPressed: enabled ? _saveBulkStatus : null,
      icon: _savingBulk
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 16),
      label: Text(_savingBulk ? 'กำลังบันทึก...' : 'บันทึก'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.successColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// สถานะของแถว — ค่าที่เลือกไว้ที่หัวคอลัมน์แต่ยังไม่บันทึกจะขึ้นสีส้ม
  Widget _statusCell(RoomAssignment r) {
    final pending = _bulkStatus;
    if (!widget.statusOnly || pending == null) {
      return _cellText(r.statusName ?? '${r.status ?? '-'}');
    }
    final name = _statuses
        .where((s) => s.status == pending)
        .map((s) => s.name)
        .firstOrNull;
    return Text(
      name ?? '$pending',
      style: TextStyle(
        fontSize: 14,
        color: AppTheme.warningColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

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
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$seq',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.warningColor,
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
        if (!widget.statusOnly) ...[
          _iconAction(
            icon: Icons.event_note_outlined,
            color: Colors.teal.shade700,
            tooltip: 'รายละเอียดการใช้ห้อง',
            onTap: () => _openSchedule(r),
          ),
          const SizedBox(width: 6),
        ],
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _edit(r),
        ),
        if (!widget.statusOnly) ...[
          const SizedBox(width: 6),
          _iconAction(
            icon: Icons.delete_outline,
            color: Colors.red.shade600,
            tooltip: 'ลบข้อมูล',
            onTap: () => _delete(r),
          ),
        ],
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

  /// แถบแบ่งหน้ามาตรฐาน — เลือกแถวต่อหน้าและกดเลขหน้าได้
  Widget _footerRow() {
    return AppPagination(
      currentPage: _page,
      totalPages: _totalPages,
      pageSize: _size,
      summary: 'ทั้งหมด ${_all.length} ห้อง',
      onPageChanged: (p) => setState(() => _page = p),
      onPageSizeChanged: (s) => setState(() {
        _size = s;
        _page = 0;
      }),
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
