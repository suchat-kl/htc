// lib/widgets/booking_room_assignment_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/bookdetail.dart';
import '../models/room_assignment.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'app_pagination.dart';
import '../screens/activity_schedule_screen.dart';
import '../screens/room_schedule_screen.dart';
import 'room_assignment_dialog.dart';

/// ตาราง "ห้องพักที่กำหนดแล้ว" / "ห้องกิจกรรมที่กำหนดแล้ว" ของใบจองหนึ่ง
///
/// แสดง bookdetail ตาม [type] ('R' ห้องพัก, 'C' ห้องกิจกรรม) เรียงตามลำดับ (sequence)
/// ทำงานในตารางได้เลยโดยไม่ต้องเปิดแก้ไขทีละห้อง (ตามคำขอของศูนย์ฯ ต.ค. 2569)
/// - ห้องพัก: พิมพ์ชื่อ-สกุลผู้เข้าพักได้ 2 ชื่อต่อห้อง แล้วกดบันทึกทั้งชุด
///   (เลิกแสดงเบอร์ติดต่อ)
/// - ห้องกิจกรรม: แสดงช่วงเวลาที่ใช้ห้องแทนชื่อและเบอร์ติดต่อ
/// - ทุกห้องมีปุ่มกดเปลี่ยนสถานะทีละขั้นแบบระบบเดิม check in → check out
///   และปุ่ม check in / check out ทุกห้องในครั้งเดียว
///   แท็บ Check in ที่เคยแยกไว้ถูกยุบมารวมที่นี่แล้ว
///
/// API ส่งมาทุกแถวในครั้งเดียว (ใบจองหนึ่งมีห้องแค่หลักสิบ) จึงแบ่งหน้าฝั่งนี้เอง
class BookingRoomAssignmentSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// 'R' = ห้องพัก (ค่าเริ่มต้น), 'C' = ห้องกิจกรรม
  final String type;

  /// แจ้งให้โหลดใหม่ — ใช้หลังบันทึกกำหนดห้องจาก dialog ตรวจสอบห้องว่าง
  final Listenable? refreshSignal;

  const BookingRoomAssignmentSection({
    super.key,
    required this.apiService,
    required this.bookId,
    this.type = 'R',
    this.refreshSignal,
  });

  @override
  State<BookingRoomAssignmentSection> createState() =>
      _BookingRoomAssignmentSectionState();
}

/// ช่องชื่อผู้เข้าพักสองช่องของห้องหนึ่ง พร้อมค่าที่บันทึกไว้ล่าสุดไว้เทียบว่าแก้แล้วหรือยัง
class _GuestFields {
  final TextEditingController name1;
  final TextEditingController name2;
  String saved1;
  String saved2;

  _GuestFields(String n1, String n2)
    : name1 = TextEditingController(text: n1),
      name2 = TextEditingController(text: n2),
      saved1 = n1,
      saved2 = n2;

  bool get isDirty =>
      name1.text.trim() != saved1.trim() || name2.text.trim() != saved2.trim();

  void dispose() {
    name1.dispose();
    name2.dispose();
  }
}

class _BookingRoomAssignmentSectionState
    extends State<BookingRoomAssignmentSection>
    with AutomaticKeepAliveClientMixin {
  /// ความยาวสูงสุดของชื่อหนึ่งช่อง ให้ไม่เกินคอลัมน์ contractname ในฐาน
  static const int _nameMaxLength = 50;

  /// แถวต่อหน้า เปลี่ยนได้จากตัวเลือกในแถบแบ่งหน้า
  int _size = 5;

  List<RoomAssignment> _all = [];

  /// ช่องชื่อผู้เข้าพักของแต่ละห้อง (คีย์ = bookIdDetail) — เฉพาะห้องพัก
  ///
  /// เก็บไว้ข้ามหน้าและข้ามการโหลดใหม่ ชื่อที่พิมพ์ค้างไว้จึงไม่หายตอนเปลี่ยนหน้า
  final Map<int, _GuestFields> _guests = {};

  /// รหัสสถานะ check in / check out ที่หาจากชื่อในตาราง statuscheck
  RoomCheckStatus _check = const RoomCheckStatus();
  bool _statusesLoaded = false;

  /// แถวที่กำลังเปลี่ยนสถานะอยู่ — กันกดซ้ำ
  final Set<int> _toggling = {};

  bool _savingNames = false;
  bool _savingBulk = false;
  int _page = 0;
  bool _loading = false;
  String? _error;

  bool get _isLodging => widget.type != 'C';

  String get _what => _isLodging ? 'ห้องพัก' : 'ห้องกิจกรรม';

  /// ไม่ให้ TabBarView ทิ้ง state ตอนสลับแท็บ ชื่อที่พิมพ์ค้างไว้จะได้ไม่หาย
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onRefresh);
    _load();
    _loadStatuses();
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
    for (final g in _guests.values) {
      g.dispose();
    }
    super.dispose();
  }

  void _onRefresh() => _load();

  int get _totalPages => _all.isEmpty ? 1 : (_all.length + _size - 1) ~/ _size;

  List<RoomAssignment> get _pageItems =>
      _all.skip(_page * _size).take(_size).toList();

  int get _dirtyCount => _guests.values.where((g) => g.isDirty).length;

  bool get _busy => _savingNames || _savingBulk;

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
    setState(() {
      _check = RoomCheckStatus.from(
        list.map((s) => (status: s.status, name: s.name)),
      );
      _statusesLoaded = true;
    });
  }

  /// โหลดรายการใหม่ — [silent] ไม่ขึ้นวงหมุนแทนตาราง ใช้หลังกดปุ่มสถานะ
  /// ช่องชื่อที่กำลังพิมพ์จะได้ไม่หลุด focus
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getRoomAssignments(
        bookId: widget.bookId,
        type: widget.type,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _syncGuestFields();
        // ลบแถวสุดท้ายของหน้าท้ายแล้วหน้านั้นจะหายไป ถอยกลับให้อยู่ในช่วง
        if (_page > _totalPages - 1) _page = _totalPages - 1;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading room assignments: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึงรายการ$_whatที่กำหนดแล้ว');
        _loading = false;
      });
    }
  }

  /// สร้าง/ปรับช่องชื่อให้ตรงกับรายการที่โหลดมา
  ///
  /// ห้องที่ยังพิมพ์ค้างไม่บันทึกคงข้อความเดิมไว้ ห้องอื่นรับค่าจากฐานใหม่
  /// ห้องที่ถูกลบไปแล้วทิ้งช่องชื่อ
  void _syncGuestFields() {
    if (!_isLodging) return;
    final ids = <int>{};
    for (final r in _all) {
      final id = r.bookIdDetail;
      if (id == null) continue;
      ids.add(id);
      final n1 = r.contractName ?? '';
      final n2 = r.contractName2 ?? '';
      final g = _guests[id];
      if (g == null) {
        _guests[id] = _GuestFields(n1, n2);
      } else if (!g.isDirty) {
        g
          ..saved1 = n1
          ..saved2 = n2
          ..name1.text = n1
          ..name2.text = n2;
      } else {
        g
          ..saved1 = n1
          ..saved2 = n2;
      }
    }
    final gone = _guests.keys.where((k) => !ids.contains(k)).toList();
    for (final k in gone) {
      _guests.remove(k)?.dispose();
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

  /// แถวสำหรับส่งไป PUT /bookdetails/batch — ส่งคอลัมน์ NOT NULL ไปด้วยเสมอ
  /// ฟิลด์อื่นที่เป็น null backend คงค่าเดิมไว้
  static BookDetail _keyOf(
    RoomAssignment r, {
    int? status,
    String? name1,
    String? name2,
  }) {
    return BookDetail(
      bookIdDetail: r.bookIdDetail,
      bookRoomId: r.bookRoomId,
      bookId: r.bookId,
      roomId: r.roomId,
      status: status,
      contractName: name1,
      contractName2: name2,
    );
  }

  // ───────────────────────── ชื่อผู้เข้าพัก ─────────────────────────

  /// บันทึกชื่อผู้เข้าพักทุกห้องที่แก้ไว้ (ทุกหน้า) ในครั้งเดียว
  Future<void> _saveNames() async {
    if (_busy) return;
    final rows = _all.where((r) {
      final g = r.bookIdDetail == null ? null : _guests[r.bookIdDetail];
      return g != null && g.isDirty;
    }).toList();
    if (rows.isEmpty) return;

    setState(() => _savingNames = true);
    try {
      await widget.apiService.updateBookDetailsBatch([
        for (final r in rows)
          _keyOf(
            r,
            // ส่ง "" เมื่อลบชื่อออก เพราะ null = คงค่าเดิม
            name1: _guests[r.bookIdDetail]!.name1.text.trim(),
            name2: _guests[r.bookIdDetail]!.name2.text.trim(),
          ),
      ]);
      // บันทึกแล้ว ถือค่าที่พิมพ์เป็นค่าล่าสุด จะได้ไม่ค้างเป็นแก้ไขอยู่
      for (final r in rows) {
        final g = _guests[r.bookIdDetail]!;
        g
          ..saved1 = g.name1.text.trim()
          ..saved2 = g.name2.text.trim();
      }
      if (!mounted) return;
      setState(() => _savingNames = false);
      context.showSuccessSnackBar(
        'บันทึกชื่อผู้เข้าพัก ${rows.length} ห้องเรียบร้อยแล้ว',
      );
      await _load(silent: true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving guest names: $e');
      if (!mounted) return;
      setState(() => _savingNames = false);
      context.showErrorSnackBar(_describeApiError(e, 'บันทึกชื่อผู้เข้าพัก'));
    }
  }

  // ───────────────────────── check in / check out ─────────────────────────

  /// สถานะถัดไปเมื่อกดปุ่มของแถวนี้ — check in → check out (หยุดที่ check out)
  int? _nextStatus(RoomAssignment r) {
    if (_check.isCheckedOut(r.status)) return null;
    if (_check.isCheckedIn(r.status)) return _check.checkOut;
    return _check.checkIn;
  }

  Future<void> _setStatus(List<RoomAssignment> rows, int status) async {
    await widget.apiService.updateBookDetailsBatch([
      for (final r in rows) _keyOf(r, status: status),
    ]);
  }

  /// กดปุ่มสถานะของแถว — เลื่อนไปขั้นถัดไปทันที ไม่ต้องเปิดแก้ไขทีละห้อง
  ///
  /// แถวที่ check out แล้ว กดอีกครั้งเพื่อย้อนกลับเป็น check in (ถามยืนยันก่อน)
  /// เผื่อกดผิดห้อง
  Future<void> _toggle(RoomAssignment r) async {
    final id = r.bookIdDetail;
    if (id == null || _toggling.contains(id) || _busy) return;

    var next = _nextStatus(r);
    if (next == null) {
      final ok = await AppDialog.showConfirm(
        context,
        'ห้อง ${r.roomNo ?? '-'} check out แล้ว\n'
        'ต้องการย้อนสถานะกลับเป็น check in ใช่หรือไม่?',
        confirmText: 'ย้อนเป็น check in',
      );
      if (ok != true || !mounted) return;
      next = _check.checkIn;
    }
    if (next == null) return;

    setState(() => _toggling.add(id));
    try {
      await _setStatus([r], next);
      if (!mounted) return;
      await _load(silent: true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error toggling room status: $e');
      if (mounted) {
        context.showErrorSnackBar(_describeApiError(e, 'เปลี่ยนสถานะ'));
      }
    } finally {
      if (mounted) setState(() => _toggling.remove(id));
    }
  }

  /// check in หรือ check out ทุกห้องของใบจองในครั้งเดียว (ทุกหน้า)
  ///
  /// check in: เฉพาะห้องที่ยังไม่ได้ check in และยังไม่ check out
  /// check out: ทุกห้องที่ยังไม่ check out
  Future<void> _bulk({required bool checkIn}) async {
    if (_busy) return;
    final status = checkIn ? _check.checkIn : _check.checkOut;
    if (status == null) return;

    final rows = _all.where((r) {
      if (r.bookIdDetail == null) return false;
      if (_check.isCheckedOut(r.status)) return false;
      return checkIn ? !_check.isCheckedIn(r.status) : true;
    }).toList();
    final action = checkIn ? 'check in' : 'check out';
    if (rows.isEmpty) {
      context.showSuccessSnackBar('ไม่มีห้องที่ต้อง $action แล้ว');
      return;
    }

    final ok = await AppDialog.showConfirm(
      context,
      'ต้องการ $action ${rows.length} ห้องใช่หรือไม่?\n'
      '${rows.map((r) => r.roomNo ?? '-').join(', ')}',
      confirmText: action,
    );
    if (ok != true || !mounted) return;

    setState(() => _savingBulk = true);
    try {
      await _setStatus(rows, status);
      if (!mounted) return;
      setState(() => _savingBulk = false);
      context.showSuccessSnackBar('$action ${rows.length} ห้องเรียบร้อยแล้ว');
      await _load(silent: true);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error bulk status: $e');
      if (!mounted) return;
      setState(() => _savingBulk = false);
      context.showErrorSnackBar(_describeApiError(e, action));
    }
  }

  // ───────────────────────── รายละเอียด / แก้ไข / ลบ ─────────────────────────

  /// เปิดรายละเอียดการใช้ห้อง (t_schedule) ของห้องนี้ ตามช่วงวันที่ของรายการ
  ///
  /// ห้องพักดูตามคืนที่พัก ห้องกิจกรรมดูทุกวันรวมวันสิ้นสุด
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
        builder: (_) => _isLodging
            ? RoomScheduleScreen(
                apiService: widget.apiService,
                roomId: roomId,
                roomNo: r.roomNo ?? '-',
                startDate: start,
                stopDate: stop,
              )
            : ActivityScheduleScreen(
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
        title: 'แก้ไขข้อมูล$_what',
        showGuestNames: _isLodging,
        // เทียบลำดับซ้ำกับทุกแถวของใบจอง ไม่ใช่แค่หน้าที่เปิดอยู่
        others: _all.where((x) => x.bookIdDetail != r.bookIdDetail).toList(),
      ),
    );
    if (ok != true || !mounted) return;
    // แก้ชื่อจาก dialog แล้ว ให้ช่องในตารางรับค่าใหม่แทนข้อความที่พิมพ์ค้าง
    _guests.remove(r.bookIdDetail)?.dispose();
    context.showSuccessSnackBar('บันทึกการแก้ไขเรียบร้อยแล้ว');
    await _load(silent: true);
  }

  Future<void> _delete(RoomAssignment r) async {
    if (r.bookIdDetail == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการลบ');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบห้องนี้ออกจากการกำหนด$_whatใช่หรือไม่?\n'
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

  // ───────────────────────── หน้าจอ ─────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          if (_statusesLoaded && !_check.ready && _all.isNotEmpty) ...[
            _statusWarning(),
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
    final hasRows = _all.isNotEmpty && !_loading;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isLodging ? Icons.king_bed_outlined : Icons.groups_outlined,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$_whatที่กำหนดแล้ว',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSansThai',
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        if (hasRows)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_isLodging) _saveNamesButton(),
              if (_check.ready) ...[
                _headerButton(
                  icon: Icons.login,
                  label: 'Check in ทุกห้อง',
                  color: AppTheme.successColor,
                  onPressed: _busy ? null : () => _bulk(checkIn: true),
                ),
                _headerButton(
                  icon: Icons.logout,
                  label: 'Check out ทุกห้อง',
                  color: AppTheme.warningColor,
                  onPressed: _busy ? null : () => _bulk(checkIn: false),
                ),
              ],
            ],
          ),
      ],
    );
  }

  /// ปุ่มบันทึกชื่อผู้เข้าพักทั้งชุด — กดได้เมื่อมีห้องที่แก้ชื่อแล้วยังไม่บันทึก
  Widget _saveNamesButton() {
    final n = _dirtyCount;
    return ElevatedButton.icon(
      onPressed: (n == 0 || _busy) ? null : _saveNames,
      icon: _savingNames
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 16),
      label: Text(
        _savingNames
            ? 'กำลังบันทึก...'
            : (n == 0 ? 'บันทึกชื่อผู้เข้าพัก' : 'บันทึกชื่อผู้เข้าพัก ($n ห้อง)'),
        style: const TextStyle(fontFamily: 'NotoSansThai'),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.saveColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontFamily: 'NotoSansThai')),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _statusWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ไม่พบสถานะ "check in" และ "check out แล้ว" ในตารางสถานะห้องพัก '
              'จึงยังกดเปลี่ยนสถานะในตารางไม่ได้ (ตรวจที่เมนูสถานะห้องพัก)',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontFamily: 'NotoSansThai',
              ),
            ),
          ),
        ],
      ),
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
          TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: const Text('ลองใหม่'),
          ),
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
            Icon(
              _isLodging ? Icons.bed_outlined : Icons.meeting_room_outlined,
              size: 34,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มี$_whatที่กำหนด',
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
            dataRowMinHeight: _isLodging ? 60 : 48,
            // ห้องกิจกรรมที่ใช้หลายวันต่างเวลากันมีหลายบรรทัด
            dataRowMaxHeight: _isLodging ? 64 : double.infinity,
            columnSpacing: 18,
            horizontalMargin: 18,
            columns: [
              const DataColumn(label: _ColHead('ลำดับ'), numeric: true),
              const DataColumn(label: _ColHead('หมายเลขห้อง')),
              if (_isLodging) ...const [
                DataColumn(label: _ColHead('ผู้เข้าพักคนที่ 1')),
                DataColumn(label: _ColHead('ผู้เข้าพักคนที่ 2')),
              ] else
                const DataColumn(label: _ColHead('เวลาที่ใช้')),
              const DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              const DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              const DataColumn(label: _ColHead('สถานะ')),
              const DataColumn(label: _ColHead('')),
            ],
            rows: _pageItems.map((r) {
              final g = r.bookIdDetail == null ? null : _guests[r.bookIdDetail];
              return DataRow(
                cells: [
                  DataCell(_sequenceCell(r, dupSeqs)),
                  DataCell(_cellText(r.roomNo ?? '-')),
                  if (_isLodging) ...[
                    DataCell(_nameField(g?.name1, g?.saved1 ?? '')),
                    DataCell(_nameField(g?.name2, g?.saved2 ?? '')),
                  ] else
                    DataCell(_timeCell(r)),
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

  /// ช่องพิมพ์ชื่อผู้เข้าพักในตาราง — แก้แล้วยังไม่บันทึกจะมีกรอบสีส้ม
  Widget _nameField(TextEditingController? c, String saved) {
    if (c == null) return _cellText('-');
    final dirty = c.text.trim() != saved.trim();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: dirty
          ? BorderSide(color: AppTheme.warningColor, width: 1.5)
          : BorderSide(color: Colors.grey.shade400),
    );
    return SizedBox(
      width: 190,
      child: TextField(
        controller: c,
        enabled: !_savingNames,
        maxLength: _nameMaxLength,
        // นับห้องที่แก้ใหม่ทุกครั้งที่พิมพ์ ให้ปุ่มบันทึกแสดงจำนวนตรง
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, fontFamily: 'NotoSansThai'),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: 'ชื่อ-สกุล',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: border,
          enabledBorder: border,
        ),
      ),
    );
  }

  /// เวลาที่ใช้ห้องกิจกรรม — ทุกวันใช้ช่วงเดียวกันแสดงบรรทัดเดียว
  /// ไม่เหมือนกันแสดงทีละวัน
  Widget _timeCell(RoomAssignment r) {
    if (r.timeSlots.isEmpty) return _cellText('-');

    final byDate = <String, List<String>>{};
    for (final s in r.timeSlots) {
      final from = s.fromTime;
      final to = s.toTime;
      if (from == null || to == null) continue;
      byDate
          .putIfAbsent(s.date ?? '', () => [])
          .add('${_hhmm(from)} - ${_hhmm(to)}');
    }
    if (byDate.isEmpty) return _cellText('-');

    final sets = byDate.values.map((v) => v.join(', ')).toSet();
    final lines = sets.length == 1
        ? [sets.first]
        : [
            for (final e in byDate.entries)
              '${Util.formatThaiDateStr(e.key)}  ${e.value.join(', ')}',
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in lines) _cellText(l)],
      ),
    );
  }

  /// 800 -> "08:00"
  static String _hhmm(int v) =>
      '${(v ~/ 100).toString().padLeft(2, '0')}:'
      '${(v % 100).toString().padLeft(2, '0')}';

  /// สถานะของแถว — ชื่อตามที่เก็บในฐาน (ข้อมูลเก่าที่เป็นสถานะอื่นยังแสดงได้)
  /// พร้อมปุ่มกดเลื่อนสถานะถัดไป
  Widget _statusCell(RoomAssignment r) {
    final name = r.statusName ?? (r.status == null ? '-' : '${r.status}');
    if (!_check.ready) return _cellText(name);

    final id = r.bookIdDetail;
    final busy = id != null && _toggling.contains(id);
    final done = _check.isCheckedOut(r.status);
    final inRoom = _check.isCheckedIn(r.status);

    final Color color;
    final String label;
    final String tip;
    if (done) {
      color = Colors.grey.shade600;
      label = 'Check out แล้ว';
      tip = 'สถานะ: $name — กดเพื่อย้อนกลับเป็น check in';
    } else if (inRoom) {
      color = AppTheme.warningColor;
      label = 'Check out';
      tip = 'สถานะ: $name — กดเพื่อ check out';
    } else {
      color = AppTheme.successColor;
      label = 'Check in';
      tip = 'สถานะ: $name — กดเพื่อ check in';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tip,
          child: SizedBox(
            width: 132,
            child: ElevatedButton(
              onPressed: (busy || _busy || id == null) ? null : () => _toggle(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NotoSansThai',
                      ),
                    ),
            ),
          ),
        ),
        // สถานะเก่าที่ไม่ใช่สองสถานะหลัก (เช่น รอ check out) บอกชื่อไว้ข้างปุ่ม
        if (!done && !inRoom && r.status != null) ...[
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: 'NotoSansThai',
            ),
          ),
        ],
      ],
    );
  }

  Widget _cellText(String v) =>
      Text(v, style: const TextStyle(fontSize: 14, fontFamily: 'NotoSansThai'));

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
        _iconAction(
          icon: Icons.event_note_outlined,
          color: Colors.teal.shade700,
          tooltip: 'รายละเอียดการใช้ห้อง',
          onTap: () => _openSchedule(r),
        ),
        const SizedBox(width: 6),
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

/// หัวคอลัมน์ของตารางห้องที่กำหนดแล้ว
class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'NotoSansThai',
        color: AppTheme.primaryColor,
      ),
    );
  }
}
