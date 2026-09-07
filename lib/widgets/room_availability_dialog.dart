// lib/widgets/room_availability_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// ข้อผิดพลาดที่รู้แล้วว่ามาจาก API ตัวไหน — ใช้ส่งข้อความที่อ่านรู้เรื่อง
/// ขึ้นไปให้ผู้ใช้แทน DioException ดิบ
class _ApiFailure implements Exception {
  final String message;
  _ApiFailure(this.message);
  @override
  String toString() => message;
}

/// หน้าจอ "ตรวจสอบห้องว่าง" (displayRoom)
///
/// ห้องว่าง = หมายเลขห้องที่อยู่ใน totalRoom แต่ไม่อยู่ใน useRoom
/// - totalRoom มาจาก getRooms(roomTypeID) — ห้องทั้งหมดของประเภทห้องนี้
/// - useRoom  มาจาก getBookDetailsR(...) — ห้องที่ถูกใช้งานตามเงื่อนไขของแถวนั้น
class RoomAvailabilityDialog extends StatefulWidget {
  final ApiService apiService;
  final int bookId;
  final int roomTypeId;
  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd
  final String roomTypeName;

  const RoomAvailabilityDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.roomTypeId,
    required this.startDate,
    required this.stopDate,
    required this.roomTypeName,
  });

  @override
  State<RoomAvailabilityDialog> createState() => _RoomAvailabilityDialogState();
}

class _RoomAvailabilityDialogState extends State<RoomAvailabilityDialog> {
  static const Color _usedColor = Color(0xFF7A6FCB); // ม่วง = ใช้งานอยู่
  static const Color _freeColor = Color(0xFF34D3AE); // เขียว = ว่าง

  List<String> _totalRoom = [];
  List<String> _useRoom = [];
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

    // controller ประกาศ startdate/stopdate เป็น @RequestParam ที่ไม่มี
    // required=false และไม่มีค่า default → ถ้าไม่ส่งไป Spring ตอบ 400 ทันที
    final sd = _isoDate(widget.startDate);
    final ed = _isoDate(widget.stopDate);
    if (sd == null || ed == null) {
      setState(() {
        _error = 'รายการนี้ไม่มีวันที่เริ่มต้นหรือวันที่สิ้นสุด '
            'จึงตรวจสอบห้องว่างไม่ได้\nกรุณาแก้ไขรายการให้มีช่วงวันที่ก่อน';
        _isLoading = false;
      });
      return;
    }

    try {
      // ห้องทั้งหมดของประเภทห้องนี้ — ส่งแค่ page/size/roomTypeID ตามที่กำหนด
      late final Map<String, dynamic> roomsRes;
      try {
        roomsRes = await widget.apiService.getRooms(
          page: 0,
          size: 500,
          roomTypeID: widget.roomTypeId,
        );
      } catch (e) {
        throw _ApiFailure(_describe(e, 'ดึงรายการห้องทั้งหมด (rooms)'));
      }
      final total = (roomsRes['rooms'] as List? ?? const [])
          .map((j) => (j as Map)['roomNO']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // ห้องที่ถูกใช้งานตามเงื่อนไขของแถวนี้
      late final Map<String, dynamic> usedRes;
      try {
        usedRes = await widget.apiService.getBookDetailsR(
          bookID: widget.bookId,
          roomTypeId: widget.roomTypeId,
          startdate: sd,
          stopdate: ed,
          page: 0,
          size: 500,
        );
      } catch (e) {
        throw _ApiFailure(_describe(e, 'ดึงห้องที่ใช้งาน (by-bookR)'));
      }
      final used = (usedRes['bookdetails'] as List? ?? const [])
          .map((j) => (j as Map)['roomNo']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _totalRoom = total;
        _useRoom = used;
        _isLoading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading room availability: $e');
      if (!mounted) return;
      setState(() {
        _error = e is _ApiFailure
            ? e.message
            : e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// บังคับรูปแบบเป็น yyyy-MM-dd ให้ตรงกับ @RequestParam LocalDate ฝั่ง Spring
  /// เผื่อ backend ส่งกลับมาเป็น '2026-08-23T00:00:00.000' หรือรูปแบบอื่น
  static String? _isoDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d != null) return DateFormat('yyyy-MM-dd').format(d);
    return RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(s)?.group(0);
  }

  /// ดึงข้อความจริงจากเซิร์ฟเวอร์ออกมาแสดง แทนข้อความ DioException ยาวๆ
  /// ที่ไม่บอกว่าพังตรงไหน
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

  /// จัดห้องเป็นแถวตามตัวเลขตัวแรกของหมายเลขห้อง เช่น 201–210 อยู่แถวเดียวกัน
  Map<String, List<String>> get _grouped {
    final map = <String, List<String>>{};
    for (final r in _totalRoom) {
      final key = r.isEmpty ? '?' : r.substring(0, 1);
      map.putIfAbsent(key, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort();
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  int get _freeCount =>
      _totalRoom.where((r) => !_useRoom.contains(r)).length;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 1100 ? 1040 : sw,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(child: _body()),
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
          const Icon(Icons.meeting_room_outlined, color: Colors.white),
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
            widget.roomTypeName,
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

    if (_totalRoom.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'ไม่พบห้องพักของประเภทห้องนี้',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(),
          const SizedBox(height: 18),
          for (final entry in _grouped.entries) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final r in entry.value) _roomChip(r)],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          _legend(),
        ],
      ),
    );
  }

  Widget _summary() {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        _summaryItem('ห้องทั้งหมด', '${_totalRoom.length}', AppTheme.primaryColor),
        _summaryItem('ห้องที่ใช้งาน', '${_useRoom.length}', _usedColor),
        _summaryItem('จำนวนห้องที่ว่าง', '$_freeCount', _freeColor),
      ],
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3),
        )),
        const SizedBox(width: 8),
        Text(
          '$label ',
          style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _roomChip(String roomNo) {
    final isUsed = _useRoom.contains(roomNo);
    final color = isUsed ? _usedColor : _freeColor;
    return Tooltip(
      message: isUsed ? 'ห้อง $roomNo — ใช้งานอยู่' : 'ห้อง $roomNo — ว่าง',
      child: Container(
        width: 78,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          roomNo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        _legendItem(_usedColor, 'ห้องที่ใช้งาน'),
        const SizedBox(width: 20),
        _legendItem(_freeColor, 'ห้องที่ว่าง'),
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
