// lib/screens/room_schedule_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/room_schedule_dialog.dart';

/// รายละเอียดการใช้ห้องพักหนึ่งห้อง — ตาราง t_schedule คืนละแถว
///
/// เปิดจากปุ่มรายละเอียดในตาราง "ห้องพักที่กำหนดแล้ว" ดึงตั้งแต่วันเริ่มต้น (B)
/// ถึงวันก่อนวันสิ้นสุด (C - 1) ของรายการนั้น แก้ไขราคาและหมายเหตุได้ และลบได้
///
/// ข้อมูลมีไม่กี่แถว (1 แถวต่อ 1 คืน) จึงดึงทั้งหมดครั้งเดียวแล้วแบ่งหน้าฝั่งนี้เอง
class RoomScheduleScreen extends StatefulWidget {
  final ApiService apiService;
  final int roomId;

  /// หมายเลขห้อง (A)
  final String roomNo;

  /// วันเริ่มต้น (B) ของรายการ — yyyy-MM-dd
  final String startDate;

  /// วันสิ้นสุด (C) ของรายการ — yyyy-MM-dd
  final String stopDate;

  const RoomScheduleScreen({
    super.key,
    required this.apiService,
    required this.roomId,
    required this.roomNo,
    required this.startDate,
    required this.stopDate,
  });

  @override
  State<RoomScheduleScreen> createState() => _RoomScheduleScreenState();
}

class _RoomScheduleScreenState extends State<RoomScheduleScreen> {
  static const int _size = 5; // ค่าเริ่มต้น row/page = 5
  static final _money = NumberFormat('#,##0.00');

  List<Schedule> _all = [];
  int _page = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _totalPages => _all.isEmpty ? 1 : (_all.length + _size - 1) ~/ _size;

  List<Schedule> get _pageItems =>
      _all.skip(_page * _size).take(_size).toList();

  /// จำนวนคืนตามช่วงวันที่ของรายการ (C - B)
  int? get _nights {
    final b = DateTime.tryParse(widget.startDate);
    final c = DateTime.tryParse(widget.stopDate);
    if (b == null || c == null) return null;
    return c.difference(b).inDays;
  }

  /// yyyy-MM-dd → 18 สิงหาคม 2569 ด้วย Util.formatThaiDate
  static String _date(String? s) {
    final d = s == null ? null : DateTime.tryParse(s);
    return d == null ? '-' : Util.formatThaiDate(d);
  }

  static String _orDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '-' : v;

  /// คีย์ทั้งสี่ของ t_schedule ต้องครบก่อนแก้ไขหรือลบ
  static bool _hasKey(Schedule s) =>
      s.roomID != null &&
      s.scheduleDate != null &&
      s.fromTime != null &&
      s.toTime != null;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getLodgingNights(
        roomId: widget.roomId,
        startDate: widget.startDate,
        stopDate: widget.stopDate,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        // ลบแถวสุดท้ายของหน้าท้ายแล้วหน้านั้นจะหายไป ถอยกลับให้อยู่ในช่วง
        if (_page > _totalPages - 1) _page = _totalPages - 1;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading lodging nights: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึงรายละเอียดการใช้ห้อง');
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

  Future<void> _edit(Schedule s) async {
    if (!_hasKey(s)) {
      context.showErrorSnackBar('ข้อมูลรายการไม่ครบ จึงแก้ไขไม่ได้');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomScheduleDialog(
        apiService: widget.apiService,
        roomNo: widget.roomNo,
        schedule: s,
      ),
    );
    if (ok != true || !mounted) return;
    context.showSuccessSnackBar('บันทึกการแก้ไขเรียบร้อยแล้ว');
    await _load();
  }

  Future<void> _delete(Schedule s) async {
    if (!_hasKey(s)) {
      context.showErrorSnackBar('ข้อมูลรายการไม่ครบ จึงลบไม่ได้');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบการใช้ห้องคืนนี้ใช่หรือไม่?\n'
      'ห้อง ${widget.roomNo} วันที่ ${_date(s.scheduleDate)}',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteSchedule(
        roomID: s.roomID!,
        scheduleDate: s.scheduleDate!,
        fromTime: s.fromTime!,
        toTime: s.toTime!,
      );
      if (!mounted) return;
      context.showSuccessSnackBar('ลบรายการเรียบร้อยแล้ว');
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting schedule: $e');
      if (mounted) {
        context.showErrorSnackBar(_describeApiError(e, 'ลบรายการ'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รายละเอียดการใช้ห้องพัก ห้อง ${widget.roomNo}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Container(
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
                  _summary(),
                  if (!_loading && _error == null) ..._missingNightsWarning(),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final n = _nights;
    return Wrap(
      spacing: 28,
      runSpacing: 8,
      children: [
        _info('หมายเลขห้อง', widget.roomNo),
        _info('วันที่เริ่มต้น', _date(widget.startDate)),
        _info('วันที่สิ้นสุด', _date(widget.stopDate)),
        _info('จำนวนคืน', n == null ? '-' : '$n'),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// จำนวนแถวไม่เท่าจำนวนคืน — มักเกิดจากบันทึกกำหนดห้องพังกลางทาง หรือลบไปบางคืน
  List<Widget> _missingNightsWarning() {
    final n = _nights;
    if (n == null || n <= 0 || _all.length == n) return const [];
    final color = Colors.orange.shade800;
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'ตารางการใช้ห้องมี ${_all.length} แถว แต่ช่วงวันที่มี $n คืน',
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    ];
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
            Icon(
              Icons.event_busy_outlined,
              size: 34,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'ไม่พบตารางการใช้ห้องในช่วงวันที่นี้',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _table() {
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
            columnSpacing: 28,
            horizontalMargin: 18,
            columns: const [
              DataColumn(label: _ColHead('หมายเลขห้อง')),
              DataColumn(label: _ColHead('วันที่')),
              DataColumn(label: _ColHead('ราคา'), numeric: true),
              DataColumn(label: _ColHead('หมายเหตุ')),
              DataColumn(label: _ColHead('')),
            ],
            rows: _pageItems.map((s) {
              return DataRow(
                cells: [
                  DataCell(_cellText(widget.roomNo)),
                  DataCell(_cellText(_date(s.scheduleDate))),
                  DataCell(
                    _cellText(s.price == null ? '-' : _money.format(s.price)),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        _orDash(s.remark),
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(_rowActions(s)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _rowActions(Schedule s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _edit(s),
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          tooltip: 'ลบข้อมูล',
          onTap: () => _delete(s),
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
          'ทั้งหมด ${_all.length} คืน',
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

/// หัวคอลัมน์ของตารางรายละเอียดการใช้ห้อง
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
