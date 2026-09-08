// lib/widgets/schedule_availability_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/util.dart';

/// ช่วงเวลาที่แสดงในตาราง — ค่าเก็บแบบตัวเลขเหมือนในฐานข้อมูล (800 = 08:00)
class _Slot {
  final int from;
  final int to;
  const _Slot(this.from, this.to);
}

/// หน้าจอ "ตรวจสอบห้องว่าง" ของห้องกิจกรรม (displayRoom)
///
/// ต่างจากห้องพักตรงที่ตรวจเป็น *ช่วงเวลา* ไม่ใช่หมายเลขห้อง
/// - คอลัมน์ = วันที่ เรียงจากน้อยไปมาก
/// - แถว     = ช่วงเวลาคงที่ 4 ช่วง ตั้งแต่ 08:00 ถึง 22:00
/// - ม่วง    = มีรายการใน t_schedule ตรงกับวันและช่วงเวลานั้น
/// - เขียว   = ไม่มีรายการ ถือว่าว่าง
class ScheduleAvailabilityDialog extends StatefulWidget {
  final ApiService apiService;
  final int bookId;
  final int roomTypeId;

  /// ชื่อห้องกิจกรรม มาจาก field name ของรายการที่กดตรวจสอบ
  final String roomName;

  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd

  const ScheduleAvailabilityDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.roomTypeId,
    required this.roomName,
    required this.startDate,
    required this.stopDate,
  });

  @override
  State<ScheduleAvailabilityDialog> createState() =>
      _ScheduleAvailabilityDialogState();
}

class _ScheduleAvailabilityDialogState
    extends State<ScheduleAvailabilityDialog> {
  static const Color _usedColor = Color(0xFF7A6FCB); // ม่วง = ใช้งานอยู่
  static const Color _freeColor = Color(0xFF34D3AE); // เขียว = ว่าง

  /// ช่วงเวลาตามที่กำหนดในสเปก 08:00–22:00
  static const List<_Slot> _slots = [
    _Slot(800, 1600),
    _Slot(800, 1200),
    _Slot(1200, 1600),
    _Slot(1800, 2200),
  ];

  List<Schedule> _schedules = [];
  List<DateTime> _dates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final sd = _parse(widget.startDate);
    final ed = _parse(widget.stopDate);
    if (sd == null || ed == null) {
      setState(() {
        _error = 'รายการนี้ไม่มีวันที่เริ่มต้นหรือวันที่สิ้นสุด '
            'จึงตรวจสอบห้องว่างไม่ได้\nกรุณาแก้ไขรายการให้มีช่วงวันที่ก่อน';
        _isLoading = false;
      });
      return;
    }

    // สร้างคอลัมน์วันที่จากช่วงของรายการ ไม่ใช่จากผลลัพธ์ที่ได้
    // เพื่อให้วันที่ไม่มีการจองเลยยังขึ้นเป็นคอลัมน์สีเขียวทั้งแถว
    final dates = <DateTime>[];
    for (var d = sd; !d.isAfter(ed); d = d.add(const Duration(days: 1))) {
      dates.add(DateTime(d.year, d.month, d.day));
    }

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final result = await widget.apiService.getSchedulesByBook(
        bookId: widget.bookId,
        roomTypeId: widget.roomTypeId,
        startdate: fmt.format(sd),
        stopdate: fmt.format(ed),
      );
      if (!mounted) return;
      setState(() {
        _schedules = result;
        _dates = dates;
        _isLoading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading schedules: $e');
      if (!mounted) return;
      setState(() {
        _error = _describe(e, 'ดึงตารางการใช้ห้อง (schedules/by-book)');
        _dates = dates;
        _isLoading = false;
      });
    }
  }

  static DateTime? _parse(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// 800 -> "08:00" , 1600 -> "16:00"
  static String _hhmm(int v) {
    final h = v ~/ 100;
    final m = v % 100;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// ช่วงเวลานี้ของวันนี้ถูกใช้งานอยู่ไหม — เทียบตรงกับ time/totime ในฐานข้อมูล
  bool _isUsed(DateTime date, _Slot slot) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _schedules.any(
      (s) =>
          (s.scheduleDate ?? '').startsWith(key) &&
          s.fromTime == slot.from &&
          s.toTime == slot.to,
    );
  }

  String _describe(Object e, String what) {
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

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 900 ? 860 : sw,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_header(), Flexible(child: _body()), _footer()],
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
          const Icon(Icons.event_available_outlined, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ตรวจสอบห้องว่าง',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            widget.roomName,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_dates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Center(child: Text('ไม่พบช่วงวันที่ของรายการนี้')),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.roomName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _legend(),
            ],
          ),
          const SizedBox(height: 16),
          // ตารางกว้างกว่าจอได้เมื่อช่วงวันที่ยาว จึงให้เลื่อนแนวนอนในกล่องตัวเอง
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _grid(),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // หัวตาราง = วันที่
        Row(
          children: [
            for (final d in _dates)
              SizedBox(
                width: 150,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    Util.toBuddhistYearDisplay(d),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final slot in _slots)
          Row(
            children: [
              for (final d in _dates) _cell(d, slot),
            ],
          ),
      ],
    );
  }

  Widget _cell(DateTime date, _Slot slot) {
    final used = _isUsed(date, slot);
    final label = '${_hhmm(slot.from)} - ${_hhmm(slot.to)}';
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Tooltip(
        message: used
            ? '${Util.toBuddhistYearDisplay(date)} $label — ใช้งานอยู่'
            : '${Util.toBuddhistYearDisplay(date)} $label — ว่าง',
        child: Container(
          width: 146,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: used ? _usedColor : _freeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 20,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _legendItem(_usedColor, 'ช่วงเวลาที่ใช้งาน'),
        _legendItem(_freeColor, 'ช่วงเวลาที่ว่าง'),
      ],
    );
  }

  Widget _legendItem(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('ปิด'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
