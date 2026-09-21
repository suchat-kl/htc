// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/documentstatus.dart';
import '../models/employee.dart';
import '../models/tfood.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'food_invoice_screen.dart';

/// หนึ่งแถวค่าห้องในตารางสรุปค่าบริการ
class PaymentLine {
  /// ชื่อประเภทห้อง เช่น ห้องพักธรรมดา, ห้องสัมนา 1
  final String name;

  /// จำนวนห้อง
  final int rooms;

  /// จำนวน คืน/วัน/ชั่วโมง — null = ยังไม่มีข้อมูล แสดงเป็นช่องว่าง
  /// เป็นทศนิยมได้ ห้องกิจกรรมนับช่วงเวลาครึ่งวันเป็น 0.5
  final num? units;

  /// จำนวนเงิน (บาท) — null = ยังไม่มีข้อมูล แสดงเป็นช่องว่าง ไม่นับในยอดรวม
  final double? amount;

  const PaymentLine({
    required this.name,
    required this.rooms,
    this.units,
    this.amount,
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
/// ข้อมูลที่ต่อแล้ว: ชื่อผู้ใช้บริการ ช่วงวันที่ สถานะการจอง ค่าอาหาร หมายเหตุ และ
/// ข้อมูลใบเสร็จ (เล่มที่ เลขที่ วันที่) — ทั้งหมดจากใบจองชุดเดียวกัน
/// ค่าห้องพัก (getPaymentLodging) และค่าห้องกิจกรรม (getPaymentActivity)
/// ผู้บันทึก (ผู้ใช้ที่ล็อกอิน)
/// ข้อมูลที่รอสเปก: ค่าอาหาร ค่าบริการอื่นๆ และการพิมพ์/บันทึก
/// — โครงสร้างข้อมูลเตรียมไว้แล้วใน [OtherServiceLine] เมื่อได้ที่มาของข้อมูล
/// ให้เติมใน [_load]
class PaymentScreen extends StatefulWidget {
  final ApiService apiService;

  /// ผู้ใช้ที่ล็อกอินอยู่ — ใช้เป็นผู้บันทึกการรับชำระ
  final AuthProvider authProvider;

  /// เลขที่ใบจองที่จะรับชำระ
  final int bookId;

  const PaymentScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
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

  // ---------- ข้อมูลใบเสร็จ (เติมจากใบจองตอนโหลด) ----------
  final _remarkCtrl = TextEditingController();
  final _receiptBookCtrl = TextEditingController();
  final _receiptNoCtrl = TextEditingController();
  DateTime? _receiptDate;

  /// ผู้บันทึก — ผู้ใช้ที่ล็อกอินอยู่ แบบเดียวกับช่องผู้เบิกของหน้าบันทึกรับจ่าย
  /// วัสดุซ่อมบำรุง ชื่อแสดงเหนือวันที่มุมขวาล่าง ส่วนรหัสเก็บไว้ใช้ตอนบันทึก
  String? _recorderName;
  int? _recorderEmpId;
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
      _lodgingLines.fold<double>(0, (sum, l) => sum + (l.amount ?? 0)) +
      _activityLines.fold<double>(0, (sum, l) => sum + (l.amount ?? 0)) +
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
      final statuses = await widget.apiService.getDocumentStatusList();

      // ผู้บันทึก: หาชื่อจากรายชื่อพนักงานด้วยรหัสของผู้ใช้ที่ล็อกอิน
      final recorder = await _resolveRecorder();

      // หมายเหตุและข้อมูลใบเสร็จมาจากใบจองชุดเดียวกับส่วนหัว
      _remarkCtrl.text = booking.bookremark ?? '';
      _receiptBookCtrl.text = booking.receivebook?.toString() ?? '';
      _receiptNoCtrl.text = booking.receiveno?.toString() ?? '';
      final receiptDate = booking.receivedate == null
          ? null
          : DateTime.tryParse(booking.receivedate!);

      // ห้องพัก: ครบทุกช่อง รายการ ห้อง คืน/วัน/ชั่วโมง เงิน จากคิวรี่ค่าห้องพัก
      final lodging = await widget.apiService.getPaymentLodging(
        bookId: widget.bookId,
      );

      // ห้องกิจกรรม: ครบทุกช่องจากคิวรี่ค่าห้องกิจกรรม (นับตามช่วงเวลาใน t_schedule)
      final activity = await widget.apiService.getPaymentActivity(
        bookId: widget.bookId,
      );

      // ค่าอาหาร อาหารว่าง และเครื่องดื่ม: ยอดรวมของรายการอาหารในใบจอง
      // ตัวเดียวกับที่แสดงในใบแจ้งค่าอาหาร
      final foodAmount = await _loadFoodAmount();

      // TODO: ค่าบริการอื่นๆ รอสเปกว่าดึงจากตารางไหน แล้วเติม _otherServices

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _statuses = statuses;
        _statusId = booking.statusId;
        _lodgingLines = lodging
            .map(
              (l) => PaymentLine(
                name: l.name ?? '-',
                rooms: l.rooms,
                units: l.nights,
                amount: l.baht,
              ),
            )
            .toList();
        _activityLines = activity
            .map(
              (a) => PaymentLine(
                name: a.name ?? '-',
                rooms: a.rooms,
                units: a.units,
                amount: a.baht,
              ),
            )
            .toList();
        _receiptDate = receiptDate;
        _recorderEmpId = recorder.empId;
        _recorderName = recorder.name;
        _foodAmount = foodAmount;
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

  /// ยอดรวมค่าอาหารของใบจอง = ผลรวมของ ราคา/คน x คน x มื้อ ทุกรายการ
  ///
  /// คิดจาก tfood ชุดเดียวกับใบแจ้งค่าอาหาร ยอดสองหน้าจึงตรงกันเสมอ
  /// ดึงไม่สำเร็จให้เป็น 0 แทนที่จะทำทั้งหน้าพัง
  Future<double> _loadFoodAmount() async {
    try {
      final res = await widget.apiService.getTfoods(
        bookID: widget.bookId,
        size: 200,
      );
      final list = (res['tfoods'] as List?) ?? const [];
      return list.fold<double>(0, (sum, j) {
        final t = Tfood.fromJson(j as Map<String, dynamic>);
        return sum + ((t.price ?? 0) * (t.amount ?? 0) * (t.times ?? 0));
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading tfoods: $e');
      return 0;
    }
  }

  /// รหัสและชื่อของผู้บันทึก จากผู้ใช้ที่ล็อกอิน
  ///
  /// ใช้ empID ของผู้ใช้ แล้วหาชื่อ-นามสกุลจาก getEmployeesList เหมือนช่องผู้เบิก
  /// ของหน้าบันทึกรับจ่ายวัสดุซ่อมบำรุง ถ้าหาในรายชื่อไม่เจอใช้ชื่อจากบัญชีแทน
  /// ไม่ถอยไปใช้พนักงานคนแรกในรายชื่อ เพราะจะบันทึกผิดคน
  /// โหลดรายชื่อไม่สำเร็จก็ไม่ให้ทั้งหน้าพัง แสดงชื่อจากบัญชีไปก่อน
  Future<({int? empId, String? name})> _resolveRecorder() async {
    final empId = widget.authProvider.empID;
    final fallback = widget.authProvider.fullName;
    if (empId == null) return (empId: null, name: fallback);
    try {
      final List<Employee> emps = await widget.apiService.getEmployeesList();
      for (final e in emps) {
        if (e.empID == empId) {
          final name = '${e.name ?? ''} ${e.lastname ?? ''}'.trim();
          return (empId: empId, name: name.isEmpty ? fallback : name);
        }
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading employees: $e');
    }
    return (empId: empId, name: fallback);
  }

  /// เปิดใบแจ้งค่าอาหาร อาหารว่าง และเครื่องดื่ม ของใบจองนี้
  ///
  /// กลับมาแล้วโหลดใหม่ เผื่อรายการอาหารถูกแก้ ยอดค่าอาหารจะได้ตรงกัน
  Future<void> _openFoodInvoice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodInvoiceScreen(
          apiService: widget.apiService,
          authProvider: widget.authProvider,
          bookId: widget.bookId,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  /// บันทึกการรับชำระ — ตอนนี้ตรวจแค่ว่ามีผู้บันทึก ส่วนการบันทึกจริงรอสเปก
  ///
  /// ต้องมี [_recorderEmpId] เพราะจะบันทึกรหัสพนักงานผู้รับชำระลงฐานข้อมูล
  /// ผู้ใช้ที่ไม่มีรหัสพนักงานผูกกับบัญชีจึงบันทึกไม่ได้
  void _save() {
    if (_recorderEmpId == null) {
      context.showErrorSnackBar(
        'ไม่พบรหัสพนักงานของผู้ใช้ที่ล็อกอิน จึงบันทึกการรับชำระไม่ได้',
      );
      return;
    }
    _notReady('บันทึก');
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
              _smallButton('รายละเอียด', _openFoodInvoice),
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
                // ช่องหมายเหตุสูงแถวเดียว เหมือนใบแจ้งค่าอาหาร
                maxLines: 1,
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
          _cell(1, _text(_unitsText(l.units)), align: Alignment.centerRight),
          _cell(
            1,
            l.amount == null ? const SizedBox() : _amount(l.amount!),
            align: Alignment.centerRight,
          ),
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
            AppTheme.printColor,
            () => _notReady('พิมพ์'),
          ),
          const SizedBox(width: 8),
          _actionButton(
            'บันทึก',
            Icons.save_outlined,
            AppTheme.saveColor,
            _save,
          ),
          const SizedBox(width: 8),
          _actionButton(
            'กลับ',
            Icons.arrow_back,
            AppTheme.neutralColor,
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

  /// 24 -> "24", 24.5 -> "24.5" ไม่ต่อ .0 ท้ายจำนวนเต็ม
  static String _unitsText(num? v) {
    if (v == null) return '';
    return v == v.truncate() ? '${v.toInt()}' : v.toStringAsFixed(1);
  }

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
