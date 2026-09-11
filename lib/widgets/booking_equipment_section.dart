// lib/widgets/booking_equipment_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/equipment.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'equipment_dialog.dart';

/// ตาราง "ขอใช้โสตทัศนูปกรณ์นอกเหนือพื้นที่กิจกรรม" ของใบจองหนึ่ง
///
/// ใช้ข้อมูลชุดเดียวกับหน้า equipment_screen.dart แต่กรองเฉพาะใบจองนี้
/// (bookingid) และตัดปุ่ม Refresh กับลบหลายรายการออกตามที่กำหนด
class BookingEquipmentSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  const BookingEquipmentSection({
    super.key,
    required this.apiService,
    required this.bookId,
  });

  @override
  State<BookingEquipmentSection> createState() =>
      _BookingEquipmentSectionState();
}

class _BookingEquipmentSectionState extends State<BookingEquipmentSection> {
  List<Equipment> _items = [];
  List<Roomtype> _roomtypes = [];
  List<Map<String, dynamic>> _booktitles = [];

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
    _loadDropdowns();
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
      final r = await widget.apiService.getEquipment(
        page: _page,
        size: _size,
        bookingid: widget.bookId,
      );
      if (!mounted) return;
      final list = r['equipment'] as List?;
      setState(() {
        _items = list?.map((j) => Equipment.fromJson(j)).toList() ?? [];
        _totalItems = _asInt(r['totalItems']) ?? (list?.length ?? 0);
        _totalPages = _asInt(r['totalPages']) ?? 0;
        _page = _asInt(r['currentPage']) ?? _page;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading equipment: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึงรายการโสตทัศนูปกรณ์ (equipment)');
        _loading = false;
      });
    }
  }

  /// ประเภทห้องและรายชื่อกิจกรรม ใช้เป็นตัวเลือกใน dialog และแปลงรหัสเป็นชื่อ
  ///
  /// แยก try ของแต่ละตัว เพราะถ้ารวมไว้ก้อนเดียวแล้วตัวใดตัวหนึ่งพลาด
  /// อีกตัวที่โหลดสำเร็จแล้วก็จะไม่ถูกนำไปใช้ไปด้วย
  Future<void> _loadDropdowns() async {
    try {
      final types = await widget.apiService.getRoomtypeList();
      if (mounted) setState(() => _roomtypes = types);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading roomtypes: $e');
    }

    try {
      final titles = await widget.apiService.getBooktitles();
      if (mounted) setState(() => _booktitles = titles);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading booktitles: $e');
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

  /// ชื่อประเภทห้อง — ใช้ค่าที่ API ส่งมาก่อน ถ้าไม่มีค่อยเทียบจากรายการ
  String _roomtypeName(Equipment e) {
    if (e.roomtypeName != null && e.roomtypeName!.isNotEmpty) {
      return e.roomtypeName!;
    }
    if (e.roomtypeid == null) return '-';
    return _roomtypes
        .firstWhere(
          (r) => r.roomtypeID == e.roomtypeid,
          orElse: () => Roomtype(name: '-'),
        )
        .name;
  }

  Future<void> _openDialog({Equipment? equipment}) async {
    if (_roomtypes.isEmpty) {
      context.showInfoSnackBar('ยังโหลดข้อมูลประเภทห้องไม่สำเร็จ');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EquipmentDialog(
        equipment: equipment,
        apiService: widget.apiService,
        booktitles: _booktitles,
        roomtypes: _roomtypes,
        // ผูกกับใบจองนี้เสมอ ไม่ให้เลือกใบจองอื่น
        fixedBookingId: widget.bookId,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _delete(Equipment e) async {
    if (e.equipmentID == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการลบ');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบรายการนี้ใช่หรือไม่?\n'
      'เลขที่ขออนุญาต ${widget.bookId}\n'
      'สถานที่ ${e.place ?? '-'}',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteEquipment(e.equipmentID!);
      if (!mounted) return;
      context.showSuccessSnackBar('ลบรายการเรียบร้อยแล้ว');

      // ถ้าลบรายการสุดท้ายของหน้านี้ ให้ถอยกลับไปหน้าก่อนหน้า
      if (_items.length <= 1 && _page > 0) _page--;
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting equipment: $e');
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
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
          Row(
            children: [
              Expanded(child: _sectionHeader()),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _openDialog(),
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
          if (_error != null) ...[
            _errorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
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
          child: const Icon(
            Icons.videocam_outlined,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'ขอใช้โสตทัศนูปกรณ์นอกเหนือพื้นที่กิจกรรม',
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
              Icons.videocam_off_outlined,
              size: 34,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มีรายการขอใช้โสตทัศนูปกรณ์',
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
              DataColumn(label: _ColHead('สถานที่')),
              DataColumn(label: _ColHead('ประเภทห้อง')),
              DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(label: _ColHead('จำนวนผู้เข้าร่วม'), numeric: true),
              DataColumn(label: _ColHead('')),
            ],
            rows: _items.map((e) {
              return DataRow(
                cells: [
                  DataCell(_cellText('${e.sequence}')),
                  DataCell(_cellText(e.place ?? '-')),
                  DataCell(_cellText(_roomtypeName(e))),
                  DataCell(_cellText(Util.formatThaiDateStr(e.startdate))),
                  DataCell(_cellText(Util.formatThaiDateStr(e.stopdate))),
                  DataCell(_cellText('${e.numberperson ?? '-'}')),
                  DataCell(_rowActions(e)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _rowActions(Equipment e) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _openDialog(equipment: e),
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          tooltip: 'ลบข้อมูล',
          onTap: () => _delete(e),
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
                  setState(() => _page = 0);
                  _load();
                }
              : null,
          icon: const Icon(Icons.first_page),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
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
        IconButton(
          onPressed: _page < totalPages - 1
              ? () {
                  setState(() => _page = totalPages - 1);
                  _load();
                }
              : null,
          icon: const Icon(Icons.last_page),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

/// หัวคอลัมน์ของตารางโสตทัศนูปกรณ์
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
