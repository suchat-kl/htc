// lib/widgets/booking_summary_bar.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';

/// แถบสรุปข้อมูลใบจอง + สถานะการจอง + ปุ่มบันทึก/ลบ/กลับ
///
/// ใช้ได้ทั้งแท็บ "กำหนดห้อง" และ "Check in" ซึ่งไม่มีฟอร์มของตัวเอง
/// ต่างจากแท็บ "ข้อมูลสำรองห้อง" ที่แถบนี้ผูกอยู่กับฟอร์มทั้งหน้า
///
/// ตอนบันทึกจะยึดค่าเดิมจาก [bookingData] ทั้งหมดแล้วเปลี่ยนเฉพาะ statusId
/// เพราะแท็บนี้ไม่มีช่องกรอกอื่น ถ้าส่งเฉพาะ statusId ไป ฟิลด์ที่เหลือจะถูก
/// ล้างเป็น null ที่ฝั่งเซิร์ฟเวอร์
class BookingSummaryBar extends StatefulWidget {
  final ApiService apiService;
  final int bookId;
  final Map<String, dynamic>? bookingData;

  /// แจ้งหน้าแม่เมื่อบันทึกสำเร็จ เพื่อให้ปุ่มปิด (X) ส่งสัญญาณรีเฟรชได้
  final VoidCallback? onSaved;

  const BookingSummaryBar({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.bookingData,
    this.onSaved,
  });

  @override
  State<BookingSummaryBar> createState() => _BookingSummaryBarState();
}

class _BookingSummaryBarState extends State<BookingSummaryBar> {
  List<DocumentStatus> _statusList = [];
  int? _statusId;

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _hasSaved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statusId = _asInt(widget.bookingData?['statusId']);
    _loadStatusList();
  }

  @override
  void didUpdateWidget(covariant BookingSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ข้อมูลถูกโหลดแบบ async จากหน้าแม่ ถ้ามาถึงทีหลังต้องอัปเดตสถานะด้วย
    if (oldWidget.bookingData != widget.bookingData) {
      _statusId = _asInt(widget.bookingData?['statusId']);
    }
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _str(String key) {
    final v = widget.bookingData?[key];
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  int get _bookID => _asInt(widget.bookingData?['bookID']) ?? widget.bookId;

  Future<void> _loadStatusList() async {
    try {
      final statuses = await widget.apiService.getDocumentStatusList();
      if (mounted) setState(() => _statusList = statuses);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading status: $e');
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final b = widget.bookingData ?? const <String, dynamic>{};
      // คงค่าเดิมทุกฟิลด์ เปลี่ยนเฉพาะ statusId
      final d = Bookroom(
        bookID: _bookID,
        idcard: b['idcard']?.toString(),
        startdate: b['startdate']?.toString(),
        stopdate: b['stopdate']?.toString(),
        bookdate: b['bookdate']?.toString(),
        numbermember: _asInt(b['numbermember']),
        numberstaff: _asInt(b['numberstaff']),
        departmentname: b['departmentname']?.toString(),
        booktitle: b['booktitle']?.toString(),
        contractname1: b['contractname1']?.toString(),
        contractnumber1: b['contractnumber1']?.toString(),
        bookingtype: b['bookingtype']?.toString(),
        requestroom: b['requestroom']?.toString(),
        requestconference: b['requestconference']?.toString(),
        bookremark: b['bookremark']?.toString(),
        address: b['address']?.toString(),
        branchName: b['branchName']?.toString(),
        statusId: _statusId,
      );

      await widget.apiService.updateBooking(_bookID, d);

      _hasSaved = true;
      widget.onSaved?.call();

      if (mounted) {
        await AppDialog.showSuccess(
          context,
          'บันทึกข้อมูลเรียบร้อยแล้ว\nเลขที่ขออนุญาต: $_bookID',
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving booking: $e');
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() => _error = msg);
        context.showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบข้อมูลการจอง\nเลขที่ขออนุญาต $_bookID ใช่หรือไม่?',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await widget.apiService.deleteBooking(_bookID);
      if (mounted) {
        await AppDialog.showSuccess(context, 'ลบข้อมูลเรียบร้อยแล้ว');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting booking: $e');
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() => _error = msg);
        context.showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth > 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _errorBanner(_error!),
              const SizedBox(height: 12),
            ],
            _infoCard(),
            const SizedBox(height: 16),
            _actionCard(isWide),
          ],
        );
      },
    );
  }

  /// แถวข้อมูลผู้จอง — อ่านอย่างเดียว แก้ไขได้ที่แท็บข้อมูลสำรองห้อง
  Widget _infoCard() {
    return _card(
      child: Wrap(
        spacing: 40,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _infoItem('เลขที่ขออนุญาต', '$_bookID', emphasize: true),
          _infoItem('ชื่อ-สกุล ผู้จอง', _str('contractname1')),
          _infoItem('เบอร์ติดต่อ', _str('contractnumber1')),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: emphasize ? AppTheme.primaryColor : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _actionCard(bool isWide) {
    final busy = _isSaving || _isDeleting;

    final statusField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สถานะการจอง',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          // กันกรณี statusId ที่ได้มาไม่มีอยู่ในรายการ ไม่งั้น dropdown จะ assert
          initialValue: _statusList.any((s) => s.statusId == _statusId)
              ? _statusId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: _statusList.isEmpty
                ? 'กำลังโหลดสถานะ...'
                : 'เลือกสถานะการจอง',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.6,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
          items: _statusList
              .map(
                (s) => DropdownMenuItem<int>(
                  value: s.statusId,
                  child: Text(
                    s.statusName ?? '-',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: busy ? null : (v) => setState(() => _statusId = v),
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        ),
      ],
    );

    final buttons = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(
          label: 'บันทึก',
          icon: Icons.save_outlined,
          color: const Color(0xFF43A047),
          busy: _isSaving,
          onPressed: busy ? null : _save,
        ),
        _actionButton(
          label: 'ลบ',
          icon: Icons.delete_outline,
          color: const Color(0xFFE53935),
          busy: _isDeleting,
          onPressed: busy ? null : _delete,
        ),
        _actionButton(
          label: 'กลับ',
          icon: Icons.arrow_back,
          color: const Color(0xFF00ACC1),
          busy: false,
          // ส่ง _hasSaved กลับไป หน้ารายการจะรีเฟรชเฉพาะตอนที่ข้อมูลถูกแก้จริง
          onPressed: busy ? null : () => Navigator.pop(context, _hasSaved),
        ),
      ],
    );

    return _card(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 340, child: statusField),
                const Spacer(),
                buttons,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statusField,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white70,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
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
    child: child,
  );

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
}
