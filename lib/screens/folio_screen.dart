// lib/screens/folio_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookdetail.dart';
import '../models/bookroom.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// หนึ่งแถวห้องพักในใบ Folio
///
/// แก้ได้เฉพาะหมายเหตุ ส่วนชื่อผู้เข้าพัก ห้อง วันที่ จำนวนวัน และจำนวนเงิน
/// มาจากการกำหนดห้องในใบจอง หน้านี้แสดงอย่างเดียว
class _FolioRow {
  final BookDetail source;
  final TextEditingController remarkCtrl;
  late String saved;

  _FolioRow(this.source)
    : remarkCtrl = TextEditingController(text: source.remarkFolio ?? '') {
    saved = signature;
  }

  String get signature => remarkCtrl.text;

  bool get isDirty => signature != saved;

  /// สำเนาแถวเดิมพร้อมค่าที่แก้ไข ส่งค่าเดิมกลับไปครบทุกช่องเพื่อไม่ให้ถูกล้าง
  BookDetail toBookDetail() => BookDetail(
    bookIdDetail: source.bookIdDetail,
    bookRoomId: source.bookRoomId,
    bookId: source.bookId,
    roomId: source.roomId,
    status: source.status,
    checkIn: source.checkIn,
    checkOut: source.checkOut,
    contractName: source.contractName,
    address: source.address,
    contractTel: source.contractTel,
    numberMember: source.numberMember,
    remark: source.remark,
    position: source.position,
    price: source.price,
    roomCategory: source.roomCategory,
    remarkFolio: remarkCtrl.text.trim(),
    numberDay: source.numberDay,
    roomNo: source.roomNo,
    roomTypeId: source.roomTypeId,
    sequence: source.sequence,
    startDate: source.startDate,
    stopDate: source.stopDate,
  );

  void dispose() {
    remarkCtrl.dispose();
  }
}

/// Folio — ใบแจ้งรายงานการใช้ห้องพัก
///
/// เปิดจากปุ่มแก้ไขในหน้ารายการ Folio แสดงห้องพักทุกห้องของใบจองหนึ่ง
/// พร้อมช่วงวันที่ จำนวนวัน และจำนวนเงินที่คิดไว้ตอนกำหนดห้อง
///
/// บันทึกเฉพาะ 3 ค่า — นามกับที่อยู่เก็บลง bookroom (folio_name, folio_address)
/// และหมายเหตุของแต่ละห้องเก็บลง bookdetail (remark_folio)
/// ส่วนวันที่ใช้แสดงบนเอกสารตอนพิมพ์เท่านั้น ไม่ได้บันทึก
/// ปุ่มพิมพ์รอสเปกแบบฟอร์ม
class FolioScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  final int bookId;

  const FolioScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
    required this.bookId,
  });

  @override
  State<FolioScreen> createState() => _FolioScreenState();
}

class _FolioScreenState extends State<FolioScreen> {
  static final _money = NumberFormat('#,##0.00');

  /// ตารางกว้างอย่างน้อยเท่านี้ จอแคบกว่าให้เลื่อนแนวนอน
  static const double _minTableWidth = 1150;

  static final Color _line = AppTheme.primaryColor.withValues(alpha: 0.45);

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Bookroom? _booking;
  List<_FolioRow> _rows = [];

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime? _folioDate;

  // ค่าตอนโหลดมา ใช้เทียบว่ามีการแก้ไขค้างหรือยัง
  String _originalName = '';
  String _originalAddress = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _total =>
      _rows.fold<double>(0, (sum, r) => sum + (r.source.price ?? 0));

  /// วันที่ไม่นับเป็นการแก้ไข เพราะไม่ได้บันทึกลงฐานข้อมูล
  bool get _dirty =>
      _nameCtrl.text != _originalName ||
      _addressCtrl.text != _originalAddress ||
      _rows.any((r) => r.isDirty);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.apiService.searchBookings(bookID: widget.bookId);
      final list = res['bookings'] as List? ?? const [];
      if (list.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'ไม่พบข้อมูลการจองเลขที่ ${widget.bookId}';
          _loading = false;
        });
        return;
      }
      final booking = Bookroom.fromJson(list.first as Map<String, dynamic>);
      final rows = await widget.apiService.getFolioRows(widget.bookId);

      // นามยังไม่เคยบันทึก ให้ตั้งต้นด้วยชื่อหน่วยงานของใบจอง
      final name = (booking.folioname == null || booking.folioname!.isEmpty)
          ? (booking.departmentname ?? '')
          : booking.folioname!;
      final date = booking.foliodate == null
          ? DateTime.now()
          : (DateTime.tryParse(booking.foliodate!) ?? DateTime.now());

      if (!mounted) return;
      setState(() {
        _booking = booking;
        for (final r in _rows) {
          r.dispose();
        }
        _rows = rows.map(_FolioRow.new).toList();
        _nameCtrl.text = name;
        _addressCtrl.text = booking.folioaddress ?? '';
        _folioDate = date;
        _originalName = _nameCtrl.text;
        _originalAddress = _addressCtrl.text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // บันทึก
  // ---------------------------------------------------------------------------

  /// บันทึกทั้งหน้า — หัวเอกสารลง bookroom ส่วนรายชื่อและหมายเหตุลง bookdetail
  Future<void> _save() async {
    final booking = _booking;
    if (booking == null) return;

    setState(() => _saving = true);
    try {
      for (final row in _rows) {
        if (!row.isDirty || row.source.bookIdDetail == null) continue;
        await widget.apiService.updateBookDetail(
          row.source.bookIdDetail!,
          row.toBookDetail(),
        );
      }

      // ส่งค่าเดิมของใบจองกลับไปครบ เปลี่ยนเฉพาะนามกับที่อยู่
      final payload = Bookroom.fromJson({
        ...booking.toJson(),
        'folioname': _nameCtrl.text.trim(),
        'folioaddress': _addressCtrl.text.trim(),
      });
      await widget.apiService.updateBooking(widget.bookId, payload);

      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSuccessSnackBar('บันทึกเรียบร้อย');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _notReady(String what) {
    context.showInfoSnackBar('$what ยังไม่เปิดใช้งาน');
  }

  Future<void> _pickDate() async {
    final picked = await Util.dateFieldPickerNullable(context, _folioDate);
    if (picked == null || !mounted) return;
    setState(() => _folioDate = picked);
  }

  /// ถามยืนยันเมื่อยังมีการแก้ไขค้างอยู่ — true = ออกได้
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการออกจากหน้านี้หรือไม่?',
      confirmText: 'ออกโดยไม่บันทึก',
    );
    return ok == true;
  }

  Future<void> _close() async {
    if (!await _confirmLeave()) return;
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // หน้าจอ
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            tooltip: 'ปิด',
            onPressed: _close,
          ),
          title: Text(
            'Folio เลขที่จอง ${widget.bookId}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _errorView(_error!)
            : LayoutBuilder(
                builder: (context, c) {
                  final width = c.maxWidth < _minTableWidth + 32
                      ? _minTableWidth
                      : c.maxWidth - 32;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: width, child: _folio()),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: AppTheme.dangerColor,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            onPressed: _load,
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _folio() {
    final b = _booking!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                const Text(
                  'ใบแจ้งรายงานการใช้ห้องพัก',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'ประกอบใบเสร็จรับเงิน  เล่มที่ ${_orDash(b.receivebook?.toString())}'
                  '   เลขที่ใบเสร็จ ${_orDash(b.receiveno?.toString())}'
                  '   ลงวันที่ ${Util.formatThaiDateStr(b.receivedate)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _fieldLabel('นาม'),
                    Expanded(child: _input(_nameCtrl)),
                    const SizedBox(width: 24),
                    _fieldLabel('วันที่'),
                    SizedBox(width: 220, child: _dateInput()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _fieldLabel('ที่อยู่'),
                    Expanded(child: _input(_addressCtrl)),
                    // เว้นที่ให้เท่ากับช่องวันที่ด้านบน คอลัมน์จะได้ตรงกัน
                    const SizedBox(width: 24 + 60 + 220),
                  ],
                ),
              ],
            ),
          ),
          _headerRow(),
          for (var i = 0; i < _rows.length; i++) _dataRow(i, _rows[i]),
          if (_rows.isEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'ใบจองนี้ยังไม่มีห้องพักที่กำหนดไว้',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ),
          _totalRow(),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => SizedBox(
    width: 60,
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    ),
  );

  Widget _input(TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.fieldFillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _dateInput() => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppTheme.fieldFillColor,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          _folioDate == null ? '-' : Util.formatThaiDate(_folioDate!),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // ตาราง
  // ---------------------------------------------------------------------------

  static const double _wNo = 70;
  static const double _wRoom = 100;
  static const double _wDate = 150;
  static const double _wDays = 90;
  static const double _wAmount = 120;
  static const double _wRemark = 220;

  Widget _headerRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryPale,
        border: Border(
          top: BorderSide(color: _line),
          bottom: BorderSide(color: _line),
        ),
      ),
      child: Row(
        children: [
          _headCell('ลำดับ', width: _wNo),
          const Expanded(child: _HeadText('ชื่อ-นามสกุล')),
          _headCell('ห้องพัก', width: _wRoom),
          _headCell('วันที่เข้า', width: _wDate),
          _headCell('วันที่ออก', width: _wDate),
          _headCell('รวมวัน', width: _wDays),
          _headCell('จำนวนเงิน', width: _wAmount),
          _headCell('หมายเหตุ', width: _wRemark),
        ],
      ),
    );
  }

  Widget _headCell(String text, {required double width}) =>
      SizedBox(width: width, child: _HeadText(text));

  Widget _dataRow(int index, _FolioRow row) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _line.withValues(alpha: 0.4))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _wNo,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                row.source.contractName ?? '',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          SizedBox(
            width: _wRoom,
            child: Text(
              row.source.roomNo ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          SizedBox(
            width: _wDate,
            child: Text(
              Util.formatThaiDateStr(row.source.startDate),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            width: _wDate,
            child: Text(
              Util.formatThaiDateStr(row.source.stopDate),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            width: _wDays,
            child: Text(
              '${row.source.numberDay ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          SizedBox(
            width: _wAmount,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                _money.format(row.source.price ?? 0),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          SizedBox(
            width: _wRemark,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: row.remarkCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: _cellInput(),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _cellInput() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppTheme.fieldFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );

  Widget _totalRow() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 12),
              child: Text(
                'รวมทั้งสิ้น',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(
            width: _wAmount,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                _money.format(_total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: _wRemark),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'มีการแก้ไขที่ยังไม่ได้บันทึก',
                style: TextStyle(fontSize: 13, color: AppTheme.warningColor),
              ),
            ),
          _button('พิมพ์', Icons.print_outlined, AppTheme.printColor, () {
            _notReady('พิมพ์');
          }),
          const SizedBox(width: 8),
          _button('พิมพ์สำเนา', Icons.copy_outlined, AppTheme.printColor, () {
            _notReady('พิมพ์สำเนา');
          }),
          const SizedBox(width: 8),
          _button(
            _saving ? 'กำลังบันทึก...' : 'บันทึก',
            Icons.save_outlined,
            AppTheme.saveColor,
            _saving ? () {} : _save,
          ),
          const SizedBox(width: 8),
          _button('กลับ', Icons.arrow_back, AppTheme.neutralColor, _close),
        ],
      ),
    );
  }

  Widget _button(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color == AppTheme.editColor
            ? AppTheme.onSecondaryColor
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _orDash(String? v) => (v == null || v.isEmpty) ? '-' : v;
}

/// ข้อความหัวคอลัมน์ของตาราง
class _HeadText extends StatelessWidget {
  final String text;
  const _HeadText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryDark,
        ),
      ),
    );
  }
}
