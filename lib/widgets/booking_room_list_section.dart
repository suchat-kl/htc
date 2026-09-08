// lib/widgets/booking_room_list_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/bookroomdetail.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'bookroomdetail_dialog.dart';

/// ตารางรายการห้องของใบจองหนึ่ง ใช้ได้ทั้งห้องพักและห้องกิจกรรม
///
/// ทั้งสองแบบใช้ตาราง bookroomdetail และ endpoint เดียวกัน ต่างกันแค่ค่า [type]
/// ('R' = ห้องพัก, 'C' = ห้องกิจกรรม) และหน้าจอตรวจสอบห้องว่างที่เปิดขึ้นมา
/// จึงทำเป็น widget เดียวแล้วส่งความต่างเข้ามาทาง parameter
class BookingRoomListSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// 'R' = ห้องพัก, 'C' = ห้องกิจกรรม — ส่งให้ getBookRoomDetailsRC
  final String type;

  final String title;
  final IconData icon;
  final String emptyText;

  /// ค่าเริ่มต้นของวันที่ตอนเพิ่มรายการใหม่ ปกติคือช่วงวันที่ของใบจอง
  final DateTime? defaultStartDate;
  final DateTime? defaultStopDate;

  /// สร้างหน้าจอ "ตรวจสอบห้องว่าง" ให้เหมาะกับชนิดห้อง
  /// ห้องพักดูเป็นหมายเลขห้อง ส่วนห้องกิจกรรมดูเป็นช่วงเวลา
  final Widget Function(BuildContext context, BookRoomDetail detail)
  availabilityDialogBuilder;

  const BookingRoomListSection({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.type,
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.availabilityDialogBuilder,
    this.defaultStartDate,
    this.defaultStopDate,
  });

  @override
  State<BookingRoomListSection> createState() => _BookingRoomListSectionState();
}

class _BookingRoomListSectionState extends State<BookingRoomListSection> {
  List<BookRoomDetail> _details = [];
  List<Roomtype> _roomTypes = [];

  int _page = 0;
  final int _size = 5; // ค่าเริ่มต้น row/page = 5
  int _totalItems = 0;
  int _totalPages = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRoomTypes();
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.apiService.getBookRoomDetailsRC(
        bookId: widget.bookId,
        type: widget.type,
        page: _page,
        size: _size,
      );
      if (!mounted) return;
      setState(() {
        _details = (r['items'] as List).cast<BookRoomDetail>();
        _totalItems = _asInt(r['totalItems']) ?? 0;
        _totalPages = _asInt(r['totalPages']) ?? 0;
        _page = _asInt(r['currentPage']) ?? _page;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading bookroomdetails: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึง${widget.title} (by-bookidtype)');
        _loading = false;
      });
    }
  }

  /// ประเภทห้องสำหรับ dropdown ใน dialog — กรองเฉพาะชนิดเดียวกับ section นี้
  Future<void> _loadRoomTypes() async {
    try {
      final all = await widget.apiService.getRoomtypeList();
      if (!mounted) return;
      setState(() {
        _roomTypes = all.where((r) => r.type == widget.type).toList();
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading roomtypes: $e');
    }
  }

  /// แสดงข้อความจริงจากเซิร์ฟเวอร์ พร้อมบอกว่าเรียก endpoint ไหนถึงพัง
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

  Future<void> _add() async {
    if (_roomTypes.isEmpty) {
      context.showInfoSnackBar('ยังโหลดข้อมูลประเภทห้องไม่สำเร็จ');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookRoomDetailDialog(
        apiService: widget.apiService,
        bookId: widget.bookId,
        roomTypes: _roomTypes,
        defaultStartDate: widget.defaultStartDate,
        defaultStopDate: widget.defaultStopDate,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _edit(BookRoomDetail d) async {
    if (_roomTypes.isEmpty) {
      context.showInfoSnackBar('ยังโหลดข้อมูลประเภทห้องไม่สำเร็จ');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookRoomDetailDialog(
        apiService: widget.apiService,
        bookId: widget.bookId,
        roomTypes: _roomTypes,
        detail: d,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _delete(BookRoomDetail d) async {
    if (d.bookRoomId == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการลบ');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบรายการนี้ใช่หรือไม่?\n'
      'เลขที่ขออนุญาต ${widget.bookId}\n'
      'ประเภทห้อง ${d.name ?? '-'}',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    try {
      // ลบเฉพาะแถวนี้ — deleteBookRoomDetailsByBookId จะลบทุกแถวของใบจอง
      await widget.apiService.deleteBookRoomDetail(d.bookRoomId!);
      if (!mounted) return;
      context.showSuccessSnackBar('ลบรายการเรียบร้อยแล้ว');

      // ถ้าลบรายการสุดท้ายของหน้านี้ ให้ถอยกลับไปหน้าก่อนหน้า
      if (_details.length <= 1 && _page > 0) _page--;
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting bookroomdetail: $e');
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _checkAvailability(BookRoomDetail d) async {
    if (d.roomTypeId == null) {
      context.showErrorSnackBar('ไม่พบประเภทห้องของรายการนี้');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => widget.availabilityDialogBuilder(ctx, d),
    );
  }

  /// ให้หน้าแม่สั่งโหลดใหม่ได้ เช่นหลังบันทึกข้อมูลใบจอง
  Future<void> reload() => _load();

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
          Row(
            children: [
              Expanded(child: _sectionHeader()),
              ElevatedButton.icon(
                onPressed: _loading ? null : _add,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มรายการ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[_errorBanner(_error!), const SizedBox(height: 12)],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_details.isEmpty)
            _empty()
          else ...[_table(), const SizedBox(height: 12), _pagination()],
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
          child: Icon(widget.icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
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
            Icon(widget.icon, size: 34, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              widget.emptyText,
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
            columnSpacing: 22,
            horizontalMargin: 18,
            columns: const [
              DataColumn(label: _ColHead('ลำดับ'), numeric: true),
              DataColumn(label: _ColHead('ประเภทห้อง')),
              DataColumn(label: _ColHead('จำนวนผู้ใช้บริการ'), numeric: true),
              DataColumn(label: _ColHead('จำนวนห้อง'), numeric: true),
              DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(label: _ColHead('')),
            ],
            rows: _details.map((d) {
              return DataRow(
                cells: [
                  DataCell(_cellText('${d.sequence ?? '-'}')),
                  DataCell(_cellText(d.name ?? '-')),
                  DataCell(_cellText('${d.numberMember ?? '-'}')),
                  DataCell(_cellText('${d.numberRoom ?? '-'}')),
                  DataCell(_cellText(Util.formatThaiDateStr(d.startDate))),
                  DataCell(_cellText(Util.formatThaiDateStr(d.stopDate))),
                  DataCell(_rowActions(d)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _rowActions(BookRoomDetail d) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _edit(d),
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          tooltip: 'ลบข้อมูล',
          onTap: () => _delete(d),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => _checkAvailability(d),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ACC1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'ตรวจสอบห้องว่าง',
            style: TextStyle(fontSize: 13),
          ),
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

  Widget _pagination() {
    final totalPages = _totalPages == 0 ? 1 : _totalPages;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'ทั้งหมด $_totalItems รายการ',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _page > 0
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${_page + 1} / $totalPages',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        IconButton(
          onPressed: _page < totalPages - 1
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

/// หัวคอลัมน์ของตารางรายการห้อง
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
