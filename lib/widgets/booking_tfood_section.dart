// lib/widgets/booking_tfood_section.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/foodtype.dart';
import '../models/tfood.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'tfood_dialog.dart';

/// ตาราง "รายการอาหาร" ของใบจองหนึ่ง (ตาราง tfood)
///
/// จำนวนเงินไม่ได้เก็บในฐานข้อมูล แต่คำนวณจาก ราคา/คน x คน x มื้อ
class BookingTfoodSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// ค่าเริ่มต้นของวันที่ตอนเพิ่มรายการใหม่ ปกติคือช่วงวันที่ของใบจอง
  final DateTime? defaultStartDate;
  final DateTime? defaultStopDate;

  const BookingTfoodSection({
    super.key,
    required this.apiService,
    required this.bookId,
    this.defaultStartDate,
    this.defaultStopDate,
  });

  @override
  State<BookingTfoodSection> createState() => _BookingTfoodSectionState();
}

class _BookingTfoodSectionState extends State<BookingTfoodSection> {
  static final _money = NumberFormat('#,##0.00');

  List<Tfood> _items = [];
  List<Foodtype> _foodtypes = [];

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
    _loadFoodtypes();
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
      final r = await widget.apiService.getTfoods(
        page: _page,
        size: _size,
        bookID: widget.bookId,
      );
      if (!mounted) return;
      final list = r['tfoods'] as List?;
      setState(() {
        _items = list?.map((j) => Tfood.fromJson(j)).toList() ?? [];
        _totalItems = _asInt(r['totalItems']) ?? (list?.length ?? 0);
        _totalPages = _asInt(r['totalPages']) ?? 0;
        _page = _asInt(r['currentPage']) ?? _page;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading tfoods: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ดึงรายการอาหาร (tfoods)');
        _loading = false;
      });
    }
  }

  Future<void> _loadFoodtypes() async {
    try {
      final list = await widget.apiService.getFoodtypeList();
      if (mounted) setState(() => _foodtypes = list);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading foodtypes: $e');
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

  /// ชื่อรายการอาหาร — ใช้ค่าที่ API ส่งมาก่อน ถ้าไม่มีค่อยเทียบจากรายการ
  String _foodName(Tfood t) {
    if (t.foodtypeName != null && t.foodtypeName!.isNotEmpty) {
      return t.foodtypeName!;
    }
    if (t.foodtypeid == null) return '-';
    return _foodtypes
            .firstWhere(
              (f) => f.id == t.foodtypeid,
              orElse: () => Foodtype(name: '-'),
            )
            .name ??
        '-';
  }

  /// จำนวนเงิน = ราคา/คน x คน x มื้อ
  int _total(Tfood t) => (t.price ?? 0) * (t.amount ?? 0) * (t.times ?? 0);

  int get _grandTotal => _items.fold(0, (sum, t) => sum + _total(t));

  Future<void> _openDialog({Tfood? tfood}) async {
    if (_foodtypes.isEmpty) {
      context.showInfoSnackBar('ยังโหลดข้อมูลรายการอาหารไม่สำเร็จ');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TfoodDialog(
        apiService: widget.apiService,
        bookId: widget.bookId,
        foodtypes: _foodtypes,
        tfood: tfood,
        defaultStartDate: widget.defaultStartDate,
        defaultStopDate: widget.defaultStopDate,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _delete(Tfood t) async {
    if (t.id == null) {
      context.showErrorSnackBar('ไม่พบรหัสรายการที่ต้องการลบ');
      return;
    }

    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบรายการนี้ใช่หรือไม่?\n'
      'เลขที่ขออนุญาต ${widget.bookId}\n'
      'รายการ ${_foodName(t)}',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    try {
      await widget.apiService.deleteTfood(t.id!);
      if (!mounted) return;
      context.showSuccessSnackBar('ลบรายการเรียบร้อยแล้ว');

      // ถ้าลบรายการสุดท้ายของหน้านี้ ให้ถอยกลับไปหน้าก่อนหน้า
      if (_items.length <= 1 && _page > 0) _page--;
      await _load();
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting tfood: $e');
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
            Icons.restaurant,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'รายการอาหาร',
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
              Icons.no_meals_outlined,
              size: 34,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มีรายการอาหาร',
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
              DataColumn(label: _ColHead('รายการ')),
              DataColumn(label: _ColHead('ราคา/คน'), numeric: true),
              DataColumn(label: _ColHead('คน'), numeric: true),
              DataColumn(label: _ColHead('มื้อ'), numeric: true),
              DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(label: _ColHead('จำนวนเงิน'), numeric: true),
              DataColumn(label: _ColHead('')),
            ],
            rows: _items.map((t) {
              return DataRow(
                cells: [
                  DataCell(_cellText('${t.sequence ?? '-'}')),
                  DataCell(_cellText(_foodName(t))),
                  DataCell(_cellText(_money.format(t.price ?? 0))),
                  DataCell(_cellText('${t.amount ?? 0}')),
                  DataCell(_cellText('${t.times ?? 0}')),
                  DataCell(_cellText(Util.formatThaiDateStr(t.startdate))),
                  DataCell(_cellText(Util.formatThaiDateStr(t.stopdate))),
                  DataCell(
                    Text(
                      _money.format(_total(t)),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(_rowActions(t)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _rowActions(Tfood t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(
          icon: Icons.edit_outlined,
          color: Colors.blue.shade700,
          tooltip: 'แก้ไขข้อมูล',
          onTap: () => _openDialog(tfood: t),
        ),
        const SizedBox(width: 6),
        _iconAction(
          icon: Icons.delete_outline,
          color: Colors.red.shade600,
          tooltip: 'ลบข้อมูล',
          onTap: () => _delete(t),
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

  /// รวมยอดของหน้านี้ + ตัวแบ่งหน้า
  Widget _footerRow() {
    final totalPages = _totalPages == 0 ? 1 : _totalPages;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          'รวมหน้านี้ ${_money.format(_grandTotal)} บาท',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ทั้งหมด $_totalItems รายการ',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
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
        ),
      ],
    );
  }
}

/// หัวคอลัมน์ของตารางรายการอาหาร
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
