// lib/screens/food_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/employee.dart';
import '../models/foodtype.dart';
import '../models/tfood.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// หนึ่งแถวของใบแจ้งค่าอาหาร — แก้ไขได้ในหน้าจอ
///
/// [id] เป็น null สำหรับแถวที่เพิ่งกดเพิ่ม ยังไม่มีใน tfood
class FoodInvoiceLine {
  int? id;
  int? foodtypeId;
  String? foodtypeName;

  /// ราคาต่อคน — มาจากประเภทอาหารที่เลือก
  int price;

  /// จำนวนคน
  int persons;

  /// จำนวนมื้อ
  int meals;

  int? sequence;
  String? startdate;
  String? stopdate;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected;

  FoodInvoiceLine({
    this.id,
    this.foodtypeId,
    this.foodtypeName,
    this.price = 0,
    this.persons = 0,
    this.meals = 0,
    this.sequence,
    this.startdate,
    this.stopdate,
    this.selected = false,
  });

  factory FoodInvoiceLine.fromTfood(Tfood t) => FoodInvoiceLine(
    id: t.id,
    foodtypeId: t.foodtypeid,
    foodtypeName: t.foodtypeName,
    price: t.price ?? 0,
    persons: t.amount ?? 0,
    meals: t.times ?? 0,
    sequence: t.sequence,
    startdate: t.startdate,
    stopdate: t.stopdate,
  );

  /// จำนวนเงิน = ราคา/คน x คน x มื้อ
  double get amount => (price * persons * meals).toDouble();
}

/// ใบแจ้งค่าอาหาร อาหารว่าง และเครื่องดื่ม ของใบจองหนึ่ง
///
/// เปิดจากปุ่มรายละเอียดในแถวค่าอาหารของหน้ารับชำระเงิน
///
/// รายการมาจาก tfood ของใบจองนั้น แก้ไขในหน้าจอได้ (เลือกประเภทอาหาร จำนวนคน
/// จำนวนมื้อ เพิ่มแถว ลบแถวที่เลือก) จำนวนเงินและยอดรวมคำนวณให้ทันที
/// การบันทึกลงฐานข้อมูลและการพิมพ์ยังรอสเปก
class FoodInvoiceScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  final int bookId;

  const FoodInvoiceScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
    required this.bookId,
  });

  @override
  State<FoodInvoiceScreen> createState() => _FoodInvoiceScreenState();
}

class _FoodInvoiceScreenState extends State<FoodInvoiceScreen> {
  static final _money = NumberFormat('#,##0.00');

  /// ตารางกว้างอย่างน้อยเท่านี้ จอแคบกว่าให้เลื่อนแนวนอน
  static const double _minTableWidth = 1000;

  static final Color _line = AppTheme.primaryColor.withValues(alpha: 0.45);

  bool _loading = true;
  String? _error;

  Bookroom? _booking;
  List<Foodtype> _foodtypes = [];
  List<FoodInvoiceLine> _lines = [];

  final _remarkCtrl = TextEditingController();

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
    super.dispose();
  }

  double get _total => _lines.fold<double>(0, (sum, l) => sum + l.amount);

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

      final foodtypes = await widget.apiService.getFoodtypeList();

      // รายการอาหารของใบจองนี้ ดึงทีเดียวทั้งหมด (ใบจองหนึ่งมีไม่กี่รายการ)
      final tfoodRes = await widget.apiService.getTfoods(
        bookID: widget.bookId,
        size: 200,
      );
      final lines = ((tfoodRes['tfoods'] as List?) ?? const [])
          .map((j) => FoodInvoiceLine.fromTfood(Tfood.fromJson(j)))
          .toList();
      lines.sort((a, b) => (a.sequence ?? 0).compareTo(b.sequence ?? 0));

      final recorder = await _resolveRecorder();

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _foodtypes = foodtypes;
        _lines = lines;
        _remarkCtrl.text = booking.bookremark ?? '';
        _recorderEmpId = recorder.empId;
        _recorderName = recorder.name;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading food invoice: $e');
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ\n${e.toString()}';
        _loading = false;
      });
    }
  }

  /// รหัสและชื่อของผู้บันทึก จากผู้ใช้ที่ล็อกอิน — วิธีเดียวกับหน้ารับชำระเงิน
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

  void _notReady(String what) {
    context.showInfoSnackBar('$what ยังไม่เปิดใช้งาน');
  }

  /// บันทึกใบแจ้งค่าอาหาร — รอสเปก ตรวจความครบถ้วนไว้ก่อน
  void _save() {
    if (_recorderEmpId == null) {
      context.showErrorSnackBar(
        'ไม่พบรหัสพนักงานของผู้ใช้ที่ล็อกอิน จึงบันทึกไม่ได้',
      );
      return;
    }
    final incomplete = _lines.any((l) => l.foodtypeId == null);
    if (incomplete) {
      context.showErrorSnackBar('มีแถวที่ยังไม่ได้เลือกรายการอาหาร');
      return;
    }
    _notReady('บันทึก');
  }

  void _addLine() {
    setState(() => _lines.add(FoodInvoiceLine(sequence: _lines.length + 1)));
  }

  void _selectAll() {
    final allSelected = _lines.isNotEmpty && _lines.every((l) => l.selected);
    setState(() {
      for (final l in _lines) {
        l.selected = !allSelected;
      }
    });
  }

  /// ลบเฉพาะในหน้าจอ ยังไม่ลบในฐานข้อมูลจนกว่าจะกดบันทึก (รอสเปกการบันทึก)
  void _deleteSelected() {
    final count = _lines.where((l) => l.selected).length;
    if (count == 0) {
      context.showInfoSnackBar('ยังไม่ได้เลือกรายการที่จะลบ');
      return;
    }
    setState(() => _lines.removeWhere((l) => l.selected));
    context.showSuccessSnackBar('ลบออกจากหน้าจอแล้ว $count รายการ');
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
          'ใบแจ้งค่าอาหาร เลขที่จอง ${widget.bookId}',
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
                    child: SizedBox(width: width, child: _invoice()),
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

  Widget _invoice() {
    final b = _booking!;
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
                'ใบแจ้งค่าอาหาร อาหารว่าง และเครื่องดื่ม',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              align: Alignment.center,
            ),
          ]),
          _row([
            _cell(1, _label('ชื่อผู้ใช้บริการ')),
            _cell(3, _text(_orDash(b.departmentname))),
          ]),
          _row([_cell(1, _label('ระหว่างวันที่')), _cell(3, _text(period))]),
          _row([
            _cell(3, _label('ค่าบริการ')),
            _cell(1, _amountText(_total), align: Alignment.centerRight),
          ]),
          _row([_cell(3, _linesBox()), _cell(1, const SizedBox())]),
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
            _cell(2, const SizedBox(height: 60)),
            _cell(2, _recorderBox(), align: Alignment.bottomRight),
          ]),
          _actionBar(),
        ],
      ),
    );
  }

  /// ตารางรายการอาหาร — เลือกประเภท กรอกคนและมื้อ ราคาและจำนวนเงินคำนวณให้
  Widget _linesBox() {
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 34),
                    Expanded(flex: 6, child: _subHead('รายการ', center: true)),
                    Expanded(flex: 2, child: _subHead('ราคา/คน', right: true)),
                    Expanded(flex: 2, child: _subHead('คน', center: true)),
                    Expanded(flex: 2, child: _subHead('มื้อ', center: true)),
                    Expanded(
                      flex: 2,
                      child: _subHead('จำนวนเงิน', right: true),
                    ),
                  ],
                ),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'ยังไม่มีรายการอาหาร กดปุ่มเพิ่มเพื่อสร้างรายการ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                for (final line in _lines) _lineRow(line),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _smallButton('ลบที่เลือก', _deleteSelected),
              const SizedBox(width: 12),
              _smallButton('เลือกทั้งหมด', _selectAll),
              const SizedBox(width: 4),
              _smallButton('เพิ่ม', _addLine),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineRow(FoodInvoiceLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Checkbox(
              value: line.selected,
              onChanged: (v) => setState(() => line.selected = v ?? false),
            ),
          ),
          Expanded(flex: 6, child: _foodtypeField(line)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _text(_money.format(line.price)),
            ),
          ),
          Expanded(
            flex: 2,
            child: _numberField(
              line.persons,
              (v) => setState(() => line.persons = v),
            ),
          ),
          Expanded(
            flex: 2,
            child: _numberField(
              line.meals,
              (v) => setState(() => line.meals = v),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _text(_money.format(line.amount)),
            ),
          ),
        ],
      ),
    );
  }

  /// ช่องเลือกประเภทอาหาร แสดงชื่อพร้อมราคาแบบเดียวกับระบบเดิม
  Widget _foodtypeField(FoodInvoiceLine line) {
    final known = _foodtypes.any((f) => f.id == line.foodtypeId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonFormField<int>(
        initialValue: known ? line.foodtypeId : null,
        isExpanded: true,
        decoration: _input(),
        hint: Text(
          line.foodtypeName ?? 'เลือกรายการ',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        items: [
          for (final f in _foodtypes)
            if (f.id != null)
              DropdownMenuItem(
                value: f.id,
                child: Text(
                  '${f.name ?? '-'} (${_money.format(f.price ?? 0)})',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
        onChanged: (v) {
          final f = _foodtypes.firstWhere(
            (x) => x.id == v,
            orElse: () => Foodtype(id: v),
          );
          setState(() {
            line.foodtypeId = v;
            line.foodtypeName = f.name;
            // ราคาต่อคนมาจากประเภทอาหาร เปลี่ยนรายการแล้วราคาเปลี่ยนตาม
            line.price = f.price ?? 0;
          });
        },
      ),
    );
  }

  Widget _numberField(int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextFormField(
        initialValue: '$value',
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        decoration: _input(),
        onChanged: (v) => onChanged(int.tryParse(v.trim()) ?? 0),
      ),
    );
  }

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

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
            _save,
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
  // ชิ้นส่วนย่อย — โครงตารางเดียวกับหน้ารับชำระเงิน
  // ---------------------------------------------------------------------------

  Widget _row(List<_Cell> cells) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
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
  }) => _Cell(flex, child, align);

  Widget _cellBox(_Cell c, {required bool rightBorder}) {
    return Expanded(
      flex: c.flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: c.align,
        decoration: BoxDecoration(
          border: rightBorder ? Border(right: BorderSide(color: _line)) : null,
        ),
        child: c.child,
      ),
    );
  }

  static String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v;

  Widget _label(String v) => Text(
    v,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  );

  Widget _text(String v) => Text(v, style: const TextStyle(fontSize: 14));

  Widget _amountText(double v) =>
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

/// ข้อมูลหนึ่งช่องในแถวของใบแจ้งค่าอาหาร
class _Cell {
  final int flex;
  final Widget child;
  final Alignment align;
  const _Cell(this.flex, this.child, this.align);
}
