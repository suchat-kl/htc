// lib/widgets/room_availability_dialog.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookdetail.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';

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

  /// รหัสรายการขอจอง (bookroomdetail) ของแถวที่กดปุ่มกำหนดห้องพัก
  ///
  /// bookdetail.bookroomid เป็น NOT NULL และไม่มีความสัมพันธ์ JPA ให้ Hibernate
  /// เติมให้ จึงต้องส่งค่านี้ไปเองตอนบันทึก ไม่มีค่านี้ = บันทึกไม่ได้
  final int? bookRoomId;
  /// ช่วงวันที่ของ "ใบจอง" — ใช้ตรวจสอบห้องว่างเท่านั้น
  ///
  /// ห้องว่างต้องดูจากช่วงของทั้งใบจองเสมอ ไม่ใช่ช่วงของแถวใดแถวหนึ่ง
  /// ไม่งั้นห้องที่ถูกใช้อยู่ในช่วงอื่นของใบจองเดียวกันจะโผล่มาเป็นว่าง
  final String? startDate; // yyyy-MM-dd
  final String? stopDate; // yyyy-MM-dd

  /// ช่วงวันที่ของ "แถวที่กำลังกำหนดห้อง" — ใช้ตอนบันทึกลง bookdetail เท่านั้น
  ///
  /// เป็น null ได้ คอลัมน์ปลายทางเป็น nullable จึงบันทึกเป็น null ไปตามจริง
  final String? rowStartDate; // yyyy-MM-dd
  final String? rowStopDate; // yyyy-MM-dd

  final String roomTypeName;

  /// โหมดเลือกห้อง — เปิดจากแท็บกำหนดห้องเท่านั้น
  ///
  /// เปิดอยู่: คลิกเลือกห้องว่างได้ มีตัวนับ "จำนวนที่เลือก" และปุ่มบันทึก
  /// ปิดอยู่ (ค่าเริ่มต้น): เป็นหน้าดูอย่างเดียว คลิกห้องไม่ได้ ไม่มีปุ่มบันทึก
  /// เช่นตอนเปิดจากแท็บข้อมูลสำรองห้อง
  ///
  /// ตัวการบันทึกลงตารางยังไม่ผูก รอขั้นตอนการบันทึกที่จะกำหนดต่อไป
  final bool selectionMode;

  const RoomAvailabilityDialog({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.roomTypeId,
    required this.startDate,
    required this.stopDate,
    required this.roomTypeName,
    this.rowStartDate,
    this.rowStopDate,
    this.bookRoomId,
    this.selectionMode = false,
  });

  @override
  State<RoomAvailabilityDialog> createState() => _RoomAvailabilityDialogState();
}

class _RoomAvailabilityDialogState extends State<RoomAvailabilityDialog> {
  static const Color _usedColor = Color(0xFF7A6FCB); // ม่วง = ใช้งานอยู่
  static const Color _freeColor = Color(0xFF34D3AE); // เขียว = ว่าง

  /// ส้ม = ห้องว่างที่ผู้ใช้เลือกไว้
  ///
  /// เลี่ยงเขียวและม่วงเพราะสองสีนั้นสื่อสถานะของห้องอยู่แล้ว
  /// การเลือกจึงต้องเป็นสีที่สามที่แยกออกจากกันได้ชัด
  static const Color _selectedColor = Color(0xFFF57C00);

  List<String> _totalRoom = [];
  List<String> _useRoom = [];

  /// หมายเลขห้องที่ถูกเลือก — เลือกได้เฉพาะห้องว่างเท่านั้น
  final Set<String> _selected = {};

  /// สถานะเริ่มต้นของ bookdetail ที่สร้างจากการกำหนดห้องพัก
  ///
  /// ต้องส่งไปกับ payload เอง ตั้งค่า default ไว้ที่ entity ฝั่ง Spring ไม่ได้ผล
  /// เพราะ mapDtoToEntity เรียก setStatus(dto.getStatus()) ทับทุกครั้ง
  /// ไม่ส่งมาก็จะกลายเป็น null
  static const int _defaultStatus = 2;

  /// กันกดบันทึกซ้ำระหว่างที่ยังยิง API ไม่ครบทุกห้อง
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
      // ห้องที่เคยเลือกอาจถูกคนอื่นจองไปแล้วระหว่างนี้ จึงต้องเริ่มนับใหม่
      _selected.clear();
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

  /// สลับสถานะเลือก/ไม่เลือกของห้องหนึ่ง
  ///
  /// Set.remove คืน false เมื่อยังไม่มีอยู่ จึงใช้เป็นตัวตัดสินได้ในบรรทัดเดียว
  void _toggleSelect(String roomNo) {
    if (_saving) return;
    setState(() {
      if (!_selected.remove(roomNo)) _selected.add(roomNo);
    });
  }

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
          // สรุปจำนวนชิดซ้าย คำอธิบายสีชิดขวา อยู่บรรทัดเดียวกันด้านบน
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Expanded ฝั่งซ้ายกินพื้นที่ที่เหลือทั้งหมด จึงดัน _legend()
              // ไปชิดขอบขวาสุด
              //
              // _legend() ต้องไม่ห่อด้วย Flexible/Expanded เพราะค่า flex เริ่มต้น
              // เป็น 1 เท่ากัน จะกลายเป็นแบ่งพื้นที่คนละครึ่งแล้วไม่ชิดขวา
              Expanded(child: _summary()),
              const SizedBox(width: 16),
              _legend(),
            ],
          ),
          const SizedBox(height: 18),
          for (final entry in _grouped.entries) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final r in entry.value) _roomChip(r)],
            ),
            const SizedBox(height: 6),
          ],
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
        if (widget.selectionMode)
          _summaryItem('จำนวนที่เลือก', '${_selected.length}', _selectedColor),
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
    final isSelected = _selected.contains(roomNo);
    final color = isUsed
        ? _usedColor
        : (isSelected ? _selectedColor : _freeColor);

    const label = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final chip = Container(
      width: 78,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      // ติ๊กถูกกำกับไว้ด้วย เพื่อให้แยกออกแม้ผู้ใช้แยกสีไม่ได้
      child: isSelected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 15, color: Colors.white),
                const SizedBox(width: 3),
                Text(roomNo, style: label),
              ],
            )
          : Text(roomNo, style: label),
    );

    // นอกแท็บกำหนดห้องเป็นหน้าดูอย่างเดียว จึงไม่ห่อ InkWell เลย
    if (!widget.selectionMode) {
      return Tooltip(
        message: isUsed ? 'ห้อง $roomNo — ใช้งานอยู่' : 'ห้อง $roomNo — ว่าง',
        child: chip,
      );
    }

    // ห้องที่ใช้งานอยู่กดไม่ได้ ไม่ห่อ InkWell เพื่อไม่ให้มี ripple ชวนให้กด
    if (isUsed) {
      return Tooltip(
        message: 'ห้อง $roomNo — ใช้งานอยู่ (เลือกไม่ได้)',
        child: chip,
      );
    }

    return Tooltip(
      message: isSelected
          ? 'ห้อง $roomNo — เลือกไว้ (คลิกอีกครั้งเพื่อยกเลิก)'
          : 'ห้อง $roomNo — ว่าง (คลิกเพื่อเลือก)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _toggleSelect(roomNo),
          child: chip,
        ),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      // Wrap แทน Row เพื่อไม่ให้ล้นบนจอแคบ และต้องไม่กินความกว้างเกินเนื้อหา
      // เพราะถูกวางเป็นลูกแบบไม่ยืดหยุ่นอยู่ใน Row ของหัวตาราง
      spacing: 20,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _legendItem(_usedColor, 'ห้องที่ใช้งาน'),
        _legendItem(_freeColor, 'ห้องที่ว่าง'),
        if (widget.selectionMode) _legendItem(_selectedColor, 'ห้องที่เลือก'),
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

  /// เรียงหมายเลขห้องจากน้อยไปมาก
  ///
  /// เทียบเป็นตัวเลขเมื่อแปลงได้ทั้งคู่ ไม่งั้น '1001' จะมาก่อน '201'
  static int _byRoomNo(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  /// หา roomID จากหมายเลขห้อง
  ///
  /// ฝั่ง backend ค้น roomNO ด้วย LIKE %..% จึงได้ห้องอื่นติดมาด้วย
  /// (ค้น '201' ได้ '1201' ด้วย) ต้องคัดให้ตรงตัวเองอีกชั้น
  Future<int> _findRoomId(String roomNo) async {
    late final Map<String, dynamic> res;
    try {
      res = await widget.apiService.getRooms(roomNO: roomNo);
    } catch (e) {
      throw _ApiFailure(_describe(e, 'ค้นหารหัสห้อง $roomNo (rooms)'));
    }

    final rooms = (res['rooms'] as List? ?? const []);
    for (final j in rooms) {
      final m = j as Map;
      if (m['roomNO']?.toString() == roomNo) {
        final id = m['roomID'] as int?;
        if (id != null) return id;
      }
    }
    throw _ApiFailure('ไม่พบรหัสห้อง (roomID) ของหมายเลขห้อง $roomNo');
  }

  /// บันทึกห้องที่เลือกลง bookdetail ทีละห้อง
  ///
  /// sequence เริ่มจาก nextSequence ที่ backend คำนวณให้ แล้วไล่ +1 ตามลำดับ
  /// ห้องที่เรียงจากน้อยไปมาก เช่น 201->10, 202->11, 203->12
  Future<void> _save() async {
    if (_saving) return;

    final bookRoomId = widget.bookRoomId;
    if (bookRoomId == null) {
      context.showOverlayMessage(
        'รายการนี้ไม่มีรหัสรายการขอจอง (bookRoomId) จึงบันทึกไม่ได้',
        icon: Icons.error_outline,
        background: Colors.red,
      );
      return;
    }

    // บันทึกด้วยช่วงวันที่ของแถว ไม่ใช่ของใบจองที่ใช้ตรวจห้องว่าง
    //
    // bookdetail.startdate/stopdate เป็น nullable แถวที่ไม่มีวันที่จึงบันทึก
    // เป็น null ไปตามจริง ไม่ถอยไปใช้วันที่ของใบจองซึ่งจะได้ค่าที่ผิด
    final sd = _isoDate(widget.rowStartDate);
    final ed = _isoDate(widget.rowStopDate);

    final rooms = _selected.toList()..sort(_byRoomNo);
    setState(() => _saving = true);

    try {
      final nextSequence = await widget.apiService.getNextRoomSequence(
        bookId: widget.bookId,
        roomTypeId: widget.roomTypeId,
      );

      for (var i = 0; i < rooms.length; i++) {
        final roomNo = rooms[i];
        final roomId = await _findRoomId(roomNo);

        await widget.apiService.createBookDetail(
          BookDetail(
            bookRoomId: bookRoomId,
            bookId: widget.bookId,
            roomTypeId: widget.roomTypeId,
            roomId: roomId,
            roomNo: roomNo,
            sequence: nextSequence + i,
            startDate: sd,
            stopDate: ed,
            status: _defaultStatus,
          ),
        );
      }

      if (!mounted) return;
      // ใช้ overlay ไม่ใช่ SnackBar ปกติ เพราะ dialog นี้บัง SnackBar จนอ่านไม่ออก
      context.showOverlayMessage(
        'บันทึกกำหนดห้องพักแล้ว ${rooms.length} ห้อง '
        '(ลำดับ $nextSequence-${nextSequence + rooms.length - 1})',
        icon: Icons.check_circle_outline,
        background: const Color(0xFF43A047),
      );

      // โหลดใหม่เพื่อให้ห้องที่เพิ่งบันทึกกลายเป็นสีม่วง และล้างการเลือก
      setState(() => _saving = false);
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving room assignment: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      context.showOverlayMessage(
        e is _ApiFailure
            ? e.message
            : 'บันทึกไม่สำเร็จ — '
                  '${e.toString().replaceAll('Exception: ', '')}',
        icon: Icons.error_outline,
        background: Colors.red,
        duration: const Duration(seconds: 5),
      );
      // อาจบันทึกสำเร็จไปแล้วบางห้องก่อนจะพัง จึงต้องโหลดใหม่ให้ตรงของจริง
      await _load();
    }
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
                        ? 'บันทึกห้องที่เลือกไว้ ${_selected.length} ห้อง'
                        : 'เลือกห้องว่าง (สีเขียว) อย่างน้อย 1 ห้องก่อนจึงจะบันทึกได้'),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 26,
                vertical: 14,
              ),
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
