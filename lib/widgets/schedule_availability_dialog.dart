// lib/widgets/schedule_availability_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
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
/// - ส้ม     = ช่วงเวลาที่ผู้ใช้เลือกไว้ (เฉพาะโหมดกำหนดห้องกิจกรรม)
class ScheduleAvailabilityDialog extends StatefulWidget {
  final ApiService apiService;
  final int bookId;
  final int roomTypeId;

  /// ชื่อห้องกิจกรรม มาจาก field name ของรายการที่กดตรวจสอบ
  final String roomName;

  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd

  /// โหมดกำหนดห้องกิจกรรม — เปิดจากแท็บกำหนดห้องเท่านั้น
  ///
  /// เปิดอยู่: คลิกเลือกช่วงเวลาที่ว่างได้ มีตัวนับและปุ่มบันทึก
  /// ปิดอยู่ (ค่าเริ่มต้น): เป็นหน้าดูอย่างเดียว คลิกไม่ได้ ไม่มีปุ่มบันทึก
  /// เช่นตอนกดปุ่มตรวจสอบห้องว่างจากแท็บข้อมูลสำรองห้อง
  final bool selectionMode;

  const ScheduleAvailabilityDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.roomTypeId,
    required this.roomName,
    required this.startDate,
    required this.stopDate,
    this.selectionMode = false,
  });

  @override
  State<ScheduleAvailabilityDialog> createState() =>
      _ScheduleAvailabilityDialogState();
}

class _ScheduleAvailabilityDialogState
    extends State<ScheduleAvailabilityDialog> {
  static const Color _usedColor = Color(0xFF7A6FCB); // ม่วง = ใช้งานอยู่
  static const Color _freeColor = Color(0xFF34D3AE); // เขียว = ว่าง

  /// ส้ม = ช่วงเวลาที่ผู้ใช้เลือกไว้
  ///
  /// เลี่ยงเขียวและม่วงเพราะสองสีนั้นสื่อสถานะของช่วงเวลาอยู่แล้ว
  static const Color _selectedColor = Color(0xFFF57C00);

  static const TextStyle _cellLabel = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  /// ช่วงเวลาตามที่กำหนดในสเปก 08:00–22:00
  static const List<_Slot> _slots = [
    _Slot(800, 1600),
    _Slot(800, 1200),
    _Slot(1200, 1600),
    _Slot(1800, 2200),
  ];

  List<Schedule> _schedules = [];
  List<DateTime> _dates = [];

  /// ช่วงเวลาที่เลือกไว้ — เก็บเป็น yyyy-MM-dd|from|to เลือกได้เฉพาะช่องที่ว่าง
  final Set<String> _selected = {};

  /// กันกดบันทึกซ้ำระหว่างที่ยังยิง API ไม่ครบทุกช่วงเวลา
  bool _saving = false;
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
      // ช่วงเวลาที่เคยเลือกอาจถูกจองไปแล้วระหว่างนี้ จึงต้องเริ่มนับใหม่
      _selected.clear();
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

  /// คีย์ของช่องหนึ่งในตาราง — วันที่คู่กับช่วงเวลา
  static String _slotKey(DateTime date, _Slot slot) =>
      '${DateFormat('yyyy-MM-dd').format(date)}|${slot.from}|${slot.to}';

  /// สลับสถานะเลือก/ไม่เลือกของช่องหนึ่ง
  ///
  /// Set.remove คืน false เมื่อยังไม่มีอยู่ จึงใช้เป็นตัวตัดสินได้ในบรรทัดเดียว
  void _toggleSelect(DateTime date, _Slot slot) {
    if (_saving) return;
    final key = _slotKey(date, slot);
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  /// หา roomID ของห้องกิจกรรมนี้
  ///
  /// หน้าจอนี้รู้แค่ประเภทห้อง จึงใช้ชื่อที่แสดงอยู่ (roomName) เป็น roomNO
  /// ฝั่ง backend ค้น roomNO ด้วย LIKE %..% จึงได้ห้องอื่นติดมาด้วย
  /// ต้องคัดให้ตรงตัวเองอีกชั้น
  Future<int> _findRoomId(String roomNo) async {
    late final Map<String, dynamic> res;
    try {
      res = await widget.apiService.getRooms(roomNO: roomNo);
    } catch (e) {
      throw Exception(_describe(e, 'ค้นหารหัสห้อง $roomNo (rooms)'));
    }

    final rooms = (res['rooms'] as List? ?? const []);
    for (final j in rooms) {
      final m = j as Map;
      if (m['roomNO']?.toString() == roomNo) {
        final id = m['roomID'] as int?;
        if (id != null) return id;
      }
    }
    throw Exception('ไม่พบรหัสห้อง (roomID) ของห้อง $roomNo');
  }

  /// บันทึกช่วงเวลาที่เลือกลง t_schedule ทีละช่วง
  ///
  /// คีย์ของตารางคือ roomID + scheduleDate + fromTime + toTime ซึ่งได้ครบจาก
  /// ช่องที่เลือกกับ roomID ที่ค้นมา ฟิลด์อื่นปล่อยว่างไว้ก่อน
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final slots = _selected.toList()..sort();
    try {
      final roomId = await _findRoomId(widget.roomName);

      for (final key in slots) {
        final parts = key.split('|');
        await widget.apiService.createSchedule(
          Schedule(
            roomID: roomId,
            scheduleDate: parts[0],
            fromTime: int.parse(parts[1]),
            toTime: int.parse(parts[2]),
          ),
        );
      }

      if (!mounted) return;
      // ใช้ overlay เพราะ SnackBar ปกติจะถูก dialog นี้บัง
      context.showOverlayMessage(
        'บันทึกกำหนดห้องกิจกรรมแล้ว ${slots.length} ช่วงเวลา',
        icon: Icons.check_circle_outline,
        background: const Color(0xFF43A047),
      );

      // โหลดใหม่เพื่อให้ช่วงเวลาที่เพิ่งบันทึกกลายเป็นสีม่วง และล้างการเลือก
      setState(() => _saving = false);
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving schedules: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      context.showOverlayMessage(
        e.toString().replaceAll('Exception: ', ''),
        icon: Icons.error_outline,
        background: Colors.red,
        duration: const Duration(seconds: 5),
      );
      // อาจบันทึกสำเร็จไปแล้วบางช่วงก่อนจะพัง จึงต้องโหลดใหม่ให้ตรงของจริง
      await _load();
    }
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
          Expanded(
            child: Text(
              widget.selectionMode ? 'กำหนดห้องกิจกรรม' : 'ตรวจสอบห้องว่าง',
              style: const TextStyle(
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
          if (widget.selectionMode) ...[
            const SizedBox(height: 10),
            _selectedSummary(),
          ],
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
    final selected = _selected.contains(_slotKey(date, slot));
    final label = '${_hhmm(slot.from)} - ${_hhmm(slot.to)}';
    final day = Util.toBuddhistYearDisplay(date);

    final box = Container(
      width: 146,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: used ? _usedColor : (selected ? _selectedColor : _freeColor),
        borderRadius: BorderRadius.circular(6),
      ),
      // ติ๊กถูกกำกับไว้ด้วย เพื่อให้แยกออกแม้ผู้ใช้แยกสีไม่ได้
      child: selected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 15, color: Colors.white),
                const SizedBox(width: 4),
                Text(label, style: _cellLabel),
              ],
            )
          : Text(label, style: _cellLabel),
    );

    // นอกโหมดกำหนดห้องกิจกรรมเป็นหน้าดูอย่างเดียว จึงไม่ห่อ InkWell เลย
    if (!widget.selectionMode) {
      final state = used ? 'ใช้งานอยู่' : 'ว่าง';
      return _cellBox(Tooltip(message: '$day $label — $state', child: box));
    }

    // ช่วงเวลาที่ใช้งานอยู่กดไม่ได้ ไม่ห่อ InkWell เพื่อไม่ให้มี ripple ชวนให้กด
    if (used) {
      return _cellBox(
        Tooltip(message: '$day $label — ใช้งานอยู่ (เลือกไม่ได้)', child: box),
      );
    }

    return _cellBox(
      Tooltip(
        message: selected
            ? '$day $label — เลือกไว้ (คลิกอีกครั้งเพื่อยกเลิก)'
            : '$day $label — ว่าง (คลิกเพื่อเลือก)',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _toggleSelect(date, slot),
            child: box,
          ),
        ),
      ),
    );
  }

  Widget _cellBox(Widget child) => Padding(
    padding: const EdgeInsets.only(right: 4, bottom: 4),
    child: child,
  );

  /// จำนวนช่วงเวลาที่เลือกไว้ แสดงเฉพาะโหมดกำหนดห้องกิจกรรม
  Widget _selectedSummary() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'จำนวนช่วงเวลาที่เลือก ',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
        Text(
          '${_selected.length}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _selectedColor,
          ),
        ),
      ],
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
        if (widget.selectionMode)
          _legendItem(_selectedColor, 'ช่วงเวลาที่เลือก'),
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
    final canSave = _selected.isNotEmpty && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.selectionMode) ...[
            Tooltip(
              message: _saving
                  ? 'กำลังบันทึก...'
                  : (canSave
                        ? 'บันทึกช่วงเวลาที่เลือกไว้ ${_selected.length} ช่วง'
                        : 'เลือกช่วงเวลาที่ว่าง (สีเขียว) อย่างน้อย 1 ช่วงก่อนจึงจะบันทึกได้'),
              child: ElevatedButton.icon(
                onPressed: canSave ? _save : null,
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
                label: Text(
                  _saving
                      ? 'กำลังบันทึก...'
                      : (_selected.isEmpty
                            ? 'บันทึก'
                            : 'บันทึก (${_selected.length})'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF43A047,
                  ).withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          ElevatedButton.icon(
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
        ],
      ),
    );
  }
}
