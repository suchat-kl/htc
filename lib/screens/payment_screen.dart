// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// หนึ่งแถวค่าห้องในตารางสรุปค่าบริการ
class PaymentLine {
  /// ชื่อประเภทห้อง เช่น ห้องพักธรรมดา, ห้องสัมนา 1
  final String name;

  /// จำนวนห้อง
  final int rooms;

  /// จำนวน คืน/วัน/ชั่วโมง
  final int units;

  /// จำนวนเงิน (บาท)
  final double amount;

  const PaymentLine({
    required this.name,
    required this.rooms,
    required this.units,
    required this.amount,
  });
}

/// หนึ่งแถวของค่าบริการอื่นๆ
class OtherServiceLine {
  final String serviceType;
  final String detail;
  final double amount;

  const OtherServiceLine({
    required this.serviceType,
    required this.detail,
    required this.amount,
  });
}

/// หน้ารับชำระเงิน — สรุปค่าบริการของใบจองหนึ่ง
///
/// เปิดจากปุ่มรับชำระในหน้ารายการรับชำระเงิน หน้าตาตามหน้าจอสรุปค่าบริการ
/// ของระบบเดิม
///
/// ข้อมูลที่ต่อแล้ว: ชื่อผู้ใช้บริการ ช่วงวันที่ และสถานะการจอง (จากใบจอง)
/// ข้อมูลที่รอสเปก: ค่าห้องพัก/ห้องกิจกรรม ค่าอาหาร ค่าบริการอื่นๆ ชื่อผู้บันทึก
/// และการพิมพ์/บันทึก — โครงสร้างข้อมูลเตรียมไว้แล้วใน [PaymentLine],
/// [OtherServiceLine] เมื่อได้ที่มาของข้อมูลให้เติมใน [_load]
class PaymentScreen extends StatefulWidget {
  final ApiService apiService;

  /// เลขที่ใบจองที่จะรับชำระ
  final int bookId;

  const PaymentScreen({
    super.key,
    required this.apiService,
    required this.bookId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static final _money = NumberFormat('#,##0.00');

  /// ตารางกว้างอย่างน้อยเท่านี้ จอแคบกว่าให้เลื่อนแนวนอน ไม่บีบคอลัมน์จนอ่านไม่ออก
  static const double _minTableWidth = 900;

  /// สีเส้นตาราง
  static final Color _line = AppTheme.primaryColor.withValues(alpha: 0.45);

  bool _loading = true;
  String? _error;

  Bookroom? _booking;
  List<DocumentStatus> _statuses = [];
  int? _statusId;

  // ---------- ค่าบริการ (รอสเปกที่มาของข้อมูล) ----------
  List<PaymentLine> _lodgingLines = [];
  List<PaymentLine> _activityLines = [];
  double _foodAmount = 0;
  List<OtherServiceLine> _otherServices = [];

  // ---------- ข้อมูลใบเสร็จ ----------
  final _remarkCtrl = TextEditingController();
  final _receiptBookCtrl = TextEditingController();
  final _receiptNoCtrl = TextEditingController();
  DateTime? _receiptDate;

  /// ชื่อผู้บันทึก — จะอ่านจากฐานข้อมูล ยังไม่ได้ต่อ
  String? _recorderName;
  final DateTime _recordDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    _receiptBookCtrl.dispose();
    _receiptNoCtrl.dispose();
    super.dispose();
  }

  double get _otherAmount =>
      _otherServices.fold<double>(0, (sum, s) => sum + s.amount);

  double get _total =>
      _lodgingLines.fold<double>(0, (sum, l) => sum + l.amount) +
      _activityLines.fold<double>(0, (sum, l) => sum + l.amount) +
      _foodAmount +
      _otherAmount;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // ส่งเฉพาะ bookID — ได้ใบจองเดียว ใช้ contractname1, departmentname,
      // startdate, stopdate ทำส่วนหัวของสรุปค่าบริการ
      final res = await widget.apiService.searchBookings(
        bookID: widget.bookId,
      );
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
      final statuses = await widget.apiService.getDocumentStatusList();

      // TODO: ค่าห้องพัก ห้องกิจกรรม ค่าอาหาร ค่าบริการอื่นๆ และชื่อผู้บันทึก
      // รอสเปกว่าดึงจากตารางไหน แล้วเติม _lodgingLines, _activityLines,
      // _foodAmount, _otherServices, _recorderName ตรงนี้

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _statuses = statuses;
        _statusId = booking.statusId;
        _lodgingLines = const [];
        _activityLines = const [];
        _foodAmount = 0;
        _otherServices = const [];
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading payment summary: $e');
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ\n${e.toString()}';
        _loading = false;
      });
    }
  }

  /// ปุ่มที่ยังไม่ได้ทำ — แจ้งผู้ใช้แทนการกดแล้วเงียบ
  void _notReady(String what) {
    context.showInfoSnackBar('$what ยังไม่เปิดใช้งาน');
  }

  Future<void> _pickReceiptDate() async {
    final picked = await Util.dateFieldPickerNullable(context, _receiptDate);
    if (picked == null || !mounted) return;
    setState(() => _receiptDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รับชำระเงิน เลขที่จอง ${widget.bookId}',
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
                    child: SizedBox(width: width, child: _summaryTable()),
                  ),
                );
              },
            ),
    );
  }

  Widget _errorView(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ตารางสรุปค่าบริการ — สร้างเองด้วย Row เพราะมีช่องที่รวมหลายคอลัมน์
  // ซึ่ง Table ของ Flutter ทำไม่ได้ สัดส่วน 4 คอลัมน์: รายการ ห้อง คืน เงิน
  // ---------------------------------------------------------------------------

  Widget _summaryTable() {
    final b = _booking!;
    final customer = [
      b.contractname1,
      b.departmentname,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' / ');
    final period =
        '${Util.formatThaiDateStr(b.startdate)} – '
        '${Util.formatThaiDateStr(b.stopdate)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row([
            _cell(
              4,
              const Text(
                'สรุปค่าบริการ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              align: Alignment.center,
            ),
          ]),
          _row([
            _cell(1, _label('ชื่อผู้ใช้บริการ')),
            _cell(3, _text(customer.isEmpty ? '-' : customer)),
          ]),
          _row([_cell(1, _label('ระหว่างวันที่')), _cell(3, _text(period))]),
          _headerRows(),
          _sectionRow('ห้องพัก'),
          ..._lineRows(_lodgingLines),
          _sectionRow('ห้องกิจกรรม'),
          ..._lineRows(_activityLines),
          _row([
            _cell(1, _label('ค่าอาหาร อาหารว่าง และเครื่องดื่ม')),
            _cell(
              2,
              _smallButton('รายละเอียด', () => _notReady('รายละเอียดค่าอาหาร')),
              align: Alignment.centerRight,
            ),
            _cell(1, _amount(_foodAmount), align: Alignment.centerRight),
          ]),
          _row([
            _cell(3, _label('ค่าบริการอื่นๆ')),
            _cell(1, _amount(_otherAmount), align: Alignment.centerRight),
          ]),
          _row([_cell(3, _otherServiceBox()), _cell(1, const SizedBox())]),
          _row([
            _cell(3, _label('รวมเงินทั้งหมด'), align: Alignment.centerRight),
            _cell(
              1,
              Text(
                _money.format(_total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              align: Alignment.centerRight,
            ),
          ]),
          _row([_cell(4, _label('หมายเหตุ'))]),
          _row([
            _cell(
              4,
              TextField(
                controller: _remarkCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: _input(),
              ),
            ),
          ]),
          _row([
            _cell(2, _receiptBox()),
            _cell(2, _recorderBox(), align: Alignment.bottomRight),
          ]),
          _actionBar(),
        ],
      ),
    );
  }

  /// หัวตาราง 2 ชั้น: "รายการ" สูงสองชั้นทางซ้าย และ "จำนวน" ครอบสามคอลัมน์
  Widget _headerRows() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cellBox(
              _cell(1, _label('รายการ'), align: Alignment.center),
              rightBorder: true,
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row([
                    _cell(3, _label('จำนวน'), align: Alignment.center),
                  ], bottomBorder: true),
                  _row([
                    _cell(1, _label('ห้อง'), align: Alignment.center),
                    _cell(
                      1,
                      _label('คืน/วัน/ชั่วโมง'),
                      align: Alignment.center,
                    ),
                    _cell(1, _label('เงิน(บาท)'), align: Alignment.center),
                  ], bottomBorder: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// แถวหัวกลุ่ม เช่น ห้องพัก / ห้องกิจกรรม
  Widget _sectionRow(String title) {
    return _row([
      _cell(1, _label(title)),
      _cell(1, const SizedBox()),
      _cell(1, const SizedBox()),
      _cell(1, const SizedBox()),
    ]);
  }

  List<Widget> _lineRows(List<PaymentLine> lines) {
    if (lines.isEmpty) {
      return [
        _row([
          _cell(
            4,
            Text(
              'ยังไม่มีข้อมูล',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
        ]),
      ];
    }
    return [
      for (final l in lines)
        _row([
          _cell(1, _text(l.name)),
          _cell(1, _text('${l.rooms}'), align: Alignment.centerRight),
          _cell(1, _text('${l.units}'), align: Alignment.centerRight),
          _cell(1, _amount(l.amount), align: Alignment.centerRight),
        ]),
    ];
  }

  /// ตารางย่อยค่าบริการอื่นๆ — รายละเอียดการเลือก/เพิ่ม/ลบ ผู้ใช้จะแจ้งเพิ่ม
  Widget _otherServiceBox() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(flex: 2, child: _subHead('ประเภทบริการ')),
                    Expanded(
                      flex: 5,
                      child: _subHead('รายละเอียด', center: true),
                    ),
                    Expanded(
                      flex: 2,
                      child: _subHead('จำนวนเงิน', right: true),
                    ),
                  ],
                ),
                for (final s in _otherServices) ...[
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(flex: 2, child: _text(s.serviceType)),
                      Expanded(flex: 5, child: _text(s.detail)),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _amount(s.amount),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _smallButton('ลบที่เลือก', () => _notReady('ลบที่เลือก')),
              const SizedBox(width: 12),
              _smallButton('เลือกทั้งหมด', () => _notReady('เลือกทั้งหมด')),
              const SizedBox(width: 4),
              _smallButton('เพิ่ม', () => _notReady('เพิ่มค่าบริการ')),
            ],
          ),
        ],
      ),
    );
  }

  /// เล่มที่/เลขที่/วันที่ใบเสร็จ
  Widget _receiptBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _receiptField('เล่มที่ใบเสร็จ', _textInput(_receiptBookCtrl)),
          const SizedBox(height: 10),
          _receiptField('เลขที่ใบเสร็จ', _textInput(_receiptNoCtrl)),
          const SizedBox(height: 10),
          _receiptField('วันที่', _receiptDateInput()),
        ],
      ),
    );
  }

  Widget _receiptField(String label, Widget input) {
    return Row(
      children: [
        SizedBox(width: 140, child: _text(label)),
        Expanded(child: input),
      ],
    );
  }

  Widget _textInput(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14),
      decoration: _input(),
    );
  }

  Widget _receiptDateInput() {
    return InkWell(
      onTap: _pickReceiptDate,
      child: InputDecorator(
        decoration: _input().copyWith(
          suffixIcon: _receiptDate == null
              ? const Icon(Icons.calendar_today, size: 16)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: 'ล้างวันที่',
                  onPressed: () => setState(() => _receiptDate = null),
                ),
        ),
        child: Text(
          _receiptDate == null ? '' : Util.formatThaiDate(_receiptDate!),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  /// ชื่อผู้บันทึกและวันที่ มุมขวาล่าง
  Widget _recorderBox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _text(_recorderName ?? '-'),
          const SizedBox(height: 14),
          _text('วันที่ ${Util.formatThaiDate(_recordDate)}'),
        ],
      ),
    );
  }

  /// แถบล่างสุด: สถานะการจอง + พิมพ์ บันทึก กลับ
  Widget _actionBar() {
    final hasStatus = _statuses.any((s) => s.statusId == _statusId);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              initialValue: hasStatus ? _statusId : null,
              isExpanded: true,
              decoration: _input().copyWith(labelText: 'สถานะการจอง'),
              items: [
                for (final s in _statuses)
                  if (s.statusId != null)
                    DropdownMenuItem(
                      value: s.statusId,
                      child: Text(
                        s.statusName ?? '-',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => _statusId = v),
            ),
          ),
          const SizedBox(width: 10),
          _actionButton(
            'พิมพ์',
            Icons.print_outlined,
            AppTheme.primaryColor,
            () => _notReady('พิมพ์'),
          ),
          const SizedBox(width: 8),
          _actionButton(
            'บันทึก',
            Icons.save_outlined,
            const Color(0xFF43A047),
            () => _notReady('บันทึก'),
          ),
          const SizedBox(width: 8),
          _actionButton(
            'กลับ',
            Icons.arrow_back,
            Colors.grey.shade600,
            () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ชิ้นส่วนย่อย
  // ---------------------------------------------------------------------------

  /// หนึ่งแถวของตาราง มีเส้นใต้แถวและเส้นคั่นระหว่างช่อง
  Widget _row(List<_Cell> cells, {bool bottomBorder = true}) {
    return Container(
      decoration: BoxDecoration(
        border: bottomBorder ? Border(bottom: BorderSide(color: _line)) : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++)
              _cellBox(cells[i], rightBorder: i < cells.length - 1),
          ],
        ),
      ),
    );
  }

  _Cell _cell(
    int flex,
    Widget child, {
    Alignment align = Alignment.centerLeft,
    bool rightBorder = false,
  }) => _Cell(flex, child, align, rightBorder);

  Widget _cellBox(_Cell c, {required bool rightBorder}) {
    return Expanded(
      flex: c.flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: c.align,
        decoration: BoxDecoration(
          border: rightBorder || c.rightBorder
              ? Border(right: BorderSide(color: _line))
              : null,
        ),
        child: c.child,
      ),
    );
  }

  Widget _label(String v) => Text(
    v,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  );

  Widget _text(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _amount(double v) =>
      Text(_money.format(v), style: const TextStyle(fontSize: 14));

  Widget _subHead(String v, {bool center = false, bool right = false}) {
    return Text(
      v,
      textAlign: right
          ? TextAlign.right
          : (center ? TextAlign.center : TextAlign.left),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  InputDecoration _input() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  Widget _smallButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// ข้อมูลหนึ่งช่องในแถวของตารางสรุป
class _Cell {
  final int flex;
  final Widget child;
  final Alignment align;
  final bool rightBorder;
  const _Cell(this.flex, this.child, this.align, this.rightBorder);
}
