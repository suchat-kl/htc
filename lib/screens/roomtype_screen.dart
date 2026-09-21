import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highway_training/screens/roomtype_commodity_screen.dart';
import 'package:highway_training/screens/roomtype_facility_screen.dart';
import '../config/theme.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../widgets/app_pagination.dart';
import '../widgets/roomtype_dialog.dart';
import '../utils/snackbar_helper.dart';

// import '../models/commodity.dart';
// import '../models/roomtype_commodity.dart';

class RoomtypeScreen extends StatefulWidget {
  final ApiService apiService;

  const RoomtypeScreen({super.key, required this.apiService});

  @override
  State<RoomtypeScreen> createState() => _RoomtypeScreenState();
}

class _RoomtypeScreenState extends State<RoomtypeScreen> {
  List<Roomtype> _roomtypes = [];
  // List<Commodity> _commodityList = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  String? _filterType;
  String? _filterStatus;

  /// ช่องค้นหารายการ — ค้นหาเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น
  /// ไม่โหลดข้อมูลใหม่ทุกตัวอักษร เพราะจะทับการแก้ไขที่ยังไม่ได้บันทึก
  final TextEditingController _searchController = TextEditingController();

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันทั้งหัวตารางและแถวข้อมูล
  static const double _wCheck = 44;
  static const double _wSeq = 80;
  static const double _wType = 140;
  static const double _wDesc = 220;
  static const double _wPrice = 110;
  static const double _wRemark = 170;
  static const double _wStatus = 140;
  static const double _wAction = 200;
  static const double _minTableWidth = 1400;

  // ✅ Hardcoded lists
  static const List<Map<String, String>> _types = [
    {'code': 'R', 'name': 'Room'},
    {'code': 'C', 'name': 'Conference'},
  ];

  static const List<Map<String, String>> _statuses = [
    {'code': '1', 'name': 'ใช้งาน'},
    {'code': '2', 'name': 'ไม่ใช้งาน'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    // _loadCommodityList(); // ✅ Load commodity list for dropdown
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _showCommodityDialog(Roomtype roomtype) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomtypeCommodityScreen(
          roomTypeID: roomtype.roomtypeID!,
          roomTypeName: roomtype.name,
          apiService: widget.apiService,
        ),
      ),
    ).then((_) => _loadData()); // Reload when returning
  }

  void _showFacilityDialog(Roomtype roomtype) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomtypeFacilityScreen(
          roomTypeID: roomtype.roomtypeID!,
          roomTypeName: roomtype.name,
          apiService: widget.apiService,
        ),
      ),
    ).then((_) => _loadData()); // Reload when returning
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getRoomtypes(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        type: _filterType,
        status: _filterStatus,
      );
      if (mounted) {
        final List<dynamic>? roomtypeList = result['roomType'] as List?;
        setState(() {
          _roomtypes =
              roomtypeList
                  ?.map((j) => Roomtype.fromJson(j as Map<String, dynamic>))
                  .where((r) => r.roomtypeID != null && r.name.isNotEmpty)
                  .toList() ??
              [];
          _totalPages = result['totalPages'] as int? ?? 0;
          // สร้างแถวแก้ไขใหม่ทุกครั้งที่โหลด การแก้ไขค้างจะถูกทิ้งไปพร้อมกัน
          _rebuildRows();
          _deletedIds.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้');
      }
    }
  }

  void _showAddEditDialog({Roomtype? roomtype}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          RoomtypeDialog(roomtype: roomtype, apiService: widget.apiService),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteRoomtype(Roomtype roomtype) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${roomtype.name}" ใช่หรือไม่?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'ลบ',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.apiService.deleteRoomtype(roomtype.roomtypeID!);
        if (mounted) {
          context.showSuccessSnackBar('ลบข้อมูลสำเร็จ');
          _loadData();
        }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // แก้ไขในตาราง — แก้หลายแถวแล้วกดบันทึกทีเดียว
  // ---------------------------------------------------------------------------

  /// สร้างแถวแก้ไขจากข้อมูลที่โหลดมา ทิ้งของเดิมเพื่อไม่ให้ controller ค้าง
  void _rebuildRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(_roomtypes.map(_EditRow.from));
  }

  /// มีการแก้ไขที่ยังไม่ได้บันทึกหรือไม่
  bool get _dirty =>
      _rows.any((r) => r.isNew || r.changed) || _deletedIds.isNotEmpty;

  Widget _headerCheckbox() {
    final selected = _rows.where((r) => r.selected).length;
    final value = _rows.isEmpty || selected == 0
        ? false
        : (selected == _rows.length ? true : null);
    return Checkbox(
      tristate: true,
      value: value,
      activeColor: AppTheme.primaryColor,
      onChanged: _rows.isEmpty ? null : (_) => _selectAll(),
    );
  }

  void _selectAll() {
    final all = _rows.isNotEmpty && _rows.every((r) => r.selected);
    setState(() {
      for (final r in _rows) {
        r.selected = !all;
      }
    });
  }

  /// เพิ่มแถวว่างท้ายตาราง รหัสประเภทห้องมาจากฐานข้อมูลจึงยังไม่มีค่า
  void _addRow() {
    setState(() => _rows.add(_EditRow.empty(_filterType, _filterStatus)));
  }

  /// ลบออกจากหน้าจอ แถวที่มีอยู่แล้วจะถูกลบจริงตอนกดบันทึก
  void _deleteSelectedRows() {
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      context.showInfoSnackBar('ยังไม่ได้เลือกรายการที่จะลบ');
      return;
    }
    setState(() {
      for (final r in selected) {
        if (!r.isNew) _deletedIds.add(r.originalRoomtypeID!);
        r.dispose();
        _rows.remove(r);
      }
    });
    context.showInfoSnackBar(
      'ลบ ${selected.length} รายการออกจากหน้าจอแล้ว กดบันทึกเพื่อยืนยัน',
    );
  }

  /// ข้อความแจ้งเตือนเมื่อยังบันทึกไม่ได้ — null แปลว่าผ่าน
  String? _validateRows() {
    // ลำดับนับแยกตามประเภทห้อง จึงเช็คซ้ำเฉพาะในประเภทเดียวกัน
    final seqs = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final seqText = r.sequenceCtrl.text.trim();
      if (seqText.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกลำดับ';
      final seq = int.tryParse(seqText);
      if (seq == null) return 'แถวที่ $no ลำดับต้องเป็นตัวเลข';
      if (r.name.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกรายการ';
      final priceText = r.priceCtrl.text.trim();
      if (priceText.isNotEmpty && double.tryParse(priceText) == null) {
        return 'แถวที่ $no ราคาต้องเป็นตัวเลข';
      }
      final key = '${r.type}|$seq';
      if (seqs.containsKey(key)) {
        return 'ลำดับ $seq ของประเภทเดียวกันซ้ำกัน '
            '(แถวที่ ${seqs[key]! + 1} และ $no)';
      }
      seqs[key] = i;
    }
    return null;
  }

  /// บันทึกทุกแถวที่แก้ไขในครั้งเดียว
  ///
  /// ลบแถวที่เอาออก สร้างแถวใหม่ และอัปเดตแถวที่แก้ค่า แล้วโหลดข้อมูลใหม่
  Future<void> _saveRows() async {
    if (_isSaving) return;
    final problem = _validateRows();
    if (problem != null) {
      context.showErrorSnackBar(problem);
      return;
    }
    if (!_dirty) {
      context.showInfoSnackBar('ไม่มีการแก้ไขที่ต้องบันทึก');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final id in _deletedIds) {
        await widget.apiService.deleteRoomtype(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        if (r.isNew) {
          await widget.apiService.createRoomtype(r.toRoomtype());
        } else if (r.changed) {
          await widget.apiService.updateRoomtype(
            r.originalRoomtypeID!,
            r.toRoomtype(),
          );
        }
      }

      if (!mounted) return;
      context.showSuccessSnackBar('บันทึกเรียบร้อยแล้ว');
      setState(() => _isSaving = false);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar(
        'บันทึกไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}',
      );
      // อาจบันทึกสำเร็จไปแล้วบางส่วน จึงโหลดใหม่ให้ตรงของจริง
      await _loadData();
    }
  }

  /// ปิดหน้าจอ ถามก่อนถ้ายังมีการแก้ไขค้าง
  Future<void> _closeScreen() async {
    if (!await _confirmDiscard()) return;
    if (mounted) Navigator.pop(context);
  }

  /// ถามยืนยันเมื่อยังมีการแก้ไขค้างอยู่ — true = ไปต่อได้
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?',
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  /// ค้นหาตามคำที่พิมพ์ไว้ — ถามก่อนถ้ายังมีการแก้ไขค้าง
  Future<void> _runSearch() async {
    if (!await _confirmDiscard()) return;
    final keyword = _searchController.text.trim();
    setState(() {
      _searchName = keyword.isEmpty ? null : keyword;
      _currentPage = 0;
    });
    _loadData();
  }

  /// ล้างคำค้นแล้วโหลดใหม่ — ถามก่อนถ้ายังมีการแก้ไขค้าง
  Future<void> _clearSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchController.clear();
      _searchName = null;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปลี่ยนตัวกรองประเภท — ถ้าผู้ใช้ไม่ยอมทิ้งการแก้ไข ค่าในช่องจะไม่เปลี่ยน
  Future<void> _changeTypeFilter(String? type) async {
    if (type == _filterType) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _filterType = type;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปลี่ยนตัวกรองสถานะ — ถ้าผู้ใช้ไม่ยอมทิ้งการแก้ไข ค่าในช่องจะไม่เปลี่ยน
  Future<void> _changeStatusFilter(String? status) async {
    if (status == _filterStatus) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _filterStatus = status;
      _currentPage = 0;
    });
    _loadData();
  }

  /// รายการตัวเลือกของช่องในแถว — เติมค่าเดิมเข้าไปด้วยถ้ายังไม่มีในรายการ
  /// (กันค่าที่ฐานข้อมูลมีแต่ไม่อยู่ในรายการตายตัวทำให้ช่องเลือกพัง)
  List<DropdownMenuItem<String>> _codeItems(
    List<Map<String, String>> source,
    String current,
  ) {
    final items = source
        .map(
          (m) => DropdownMenuItem<String>(
            value: m['code'],
            child: Text(m['name'] ?? '', overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
    if (!items.any((i) => i.value == current)) {
      items.insert(
        0,
        DropdownMenuItem<String>(value: current, child: Text(current)),
      );
    }
    return items;
  }

  /// หัวตาราง
  Widget _tableHeader(double bodyFontSize) {
    final style = TextStyle(
      fontSize: bodyFontSize,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryColor,
    );
    Widget cell(double width, String label, {TextAlign? align}) => SizedBox(
      width: width,
      child: Text(label, style: style, textAlign: align),
    );

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(width: _wCheck, child: _headerCheckbox()),
          cell(_wSeq, 'ลำดับ'),
          const SizedBox(width: 8),
          cell(_wType, 'ประเภท'),
          const SizedBox(width: 8),
          Expanded(child: Text('รายการ', style: style)),
          const SizedBox(width: 8),
          cell(_wDesc, 'คำอธิบาย'),
          const SizedBox(width: 8),
          cell(_wPrice, 'ราคา'),
          const SizedBox(width: 8),
          cell(_wRemark, 'หมายเหตุ'),
          const SizedBox(width: 8),
          cell(_wStatus, 'สถานะ'),
          const SizedBox(width: 8),
          cell(_wAction, 'จัดการ', align: TextAlign.center),
        ],
      ),
    );
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัสประเภทห้อง (roomtypeID) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงไม่แสดงและแก้ไม่ได้
  Widget _editableRow(
    _EditRow row,
    int index,
    double bodyFontSize,
    double iconSize,
  ) {
    return Container(
      key: ObjectKey(row),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: _wCheck,
            child: Checkbox(
              value: row.selected,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => row.selected = v ?? false),
            ),
          ),
          // ลำดับ — ตัวเลขล้วน
          SizedBox(
            width: _wSeq,
            child: TextField(
              controller: row.sequenceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // ประเภท
          SizedBox(
            width: _wType,
            child: DropdownButtonFormField<String>(
              initialValue: row.type,
              isExpanded: true,
              style: TextStyle(fontSize: bodyFontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _codeItems(_types, row.type),
              onChanged: (v) => setState(() => row.type = v ?? 'C'),
            ),
          ),
          const SizedBox(width: 8),
          // รายการ
          Expanded(
            child: TextField(
              controller: row.nameCtrl,
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // คำอธิบาย
          SizedBox(
            width: _wDesc,
            child: TextField(
              controller: row.descriptionCtrl,
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // ราคา — ตัวเลขและจุดทศนิยม
          SizedBox(
            width: _wPrice,
            child: TextField(
              controller: row.priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // หมายเหตุ
          SizedBox(
            width: _wRemark,
            child: TextField(
              controller: row.remarkCtrl,
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // สถานะ
          SizedBox(
            width: _wStatus,
            child: DropdownButtonFormField<String>(
              initialValue: row.status,
              isExpanded: true,
              style: TextStyle(fontSize: bodyFontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _codeItems(_statuses, row.status),
              onChanged: (v) => setState(() => row.status = v ?? '1'),
            ),
          ),
          const SizedBox(width: 8),
          // จัดการ — ทำงานกับฐานข้อมูลทันที จึงปิดไว้สำหรับแถวที่เพิ่งเพิ่ม
          SizedBox(
            width: _wAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconAction(
                  icon: Icons.edit,
                  color: Colors.blue,
                  iconSize: iconSize,
                  tooltip: 'แก้ไขในหน้าต่าง',
                  onTap: row.isNew
                      ? null
                      : () => _showAddEditDialog(roomtype: row.toRoomtype()),
                ),
                const SizedBox(width: 6),
                _iconAction(
                  icon: Icons.delete,
                  color: Colors.red,
                  iconSize: iconSize,
                  tooltip: 'ลบทันที',
                  onTap: row.isNew
                      ? null
                      : () => _deleteRoomtype(row.toRoomtype()),
                ),
                const SizedBox(width: 6),
                _iconAction(
                  icon: Icons.inventory,
                  color: Colors.orange,
                  iconSize: iconSize,
                  tooltip: 'เครื่องนอน/ของใช้',
                  onTap: row.isNew
                      ? null
                      : () => _showCommodityDialog(row.toRoomtype()),
                ),
                const SizedBox(width: 6),
                _iconAction(
                  icon: Icons.star,
                  color: Colors.green,
                  iconSize: iconSize,
                  tooltip: 'สิ่งอำนวยความสะดวก',
                  onTap: row.isNew
                      ? null
                      : () => _showFacilityDialog(row.toRoomtype()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ปุ่มไอคอนรายแถว — แถวที่เพิ่งเพิ่มจะถูกปิดไว้เพราะยังไม่มีในฐานข้อมูล
  Widget _iconAction({
    required IconData icon,
    required Color color,
    required double iconSize,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (enabled ? color : Colors.grey).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (_dirty)
            Text(
              'มีการแก้ไขที่ยังไม่ได้บันทึก',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
            ),
          _rowButton('ลบที่เลือก', _deleteSelectedRows),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          _rowButton('เพิ่ม', _addRow),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF43A047,
              ).withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);

    return PopScope(
      // ปิดด้วยปุ่มย้อนกลับของเบราว์เซอร์ก็ต้องถามก่อนเหมือนกัน
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: _closeScreen,
            tooltip: 'กลับหน้าหลัก',
          ),
          title: Text(
            'ประเภทห้อง (Room Type)',
            style: TextStyle(
              fontSize: headerFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: Icon(Icons.add, size: iconSize),
                label: Text(
                  'เพิ่มรายการ',
                  style: TextStyle(fontSize: bodyFontSize),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 14,
                    vertical: isDesktop ? 14 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Filters
            Container(
              padding: EdgeInsets.all(isDesktop ? 20 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isLargeScreen
                          ? 300
                          : (isDesktop ? 250 : double.infinity),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหารายการ...',
                          hintStyle: TextStyle(fontSize: bodyFontSize),
                          prefixIcon: Icon(Icons.search, size: iconSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isDesktop ? 14 : 10,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: iconSize),
                                  tooltip: 'ล้างคำค้น',
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                        // ค้นหาเมื่อกด Enter เท่านั้น ไม่โหลดใหม่ทุกตัวอักษร
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    // ปุ่มค้นหา — ถามก่อนถ้ายังมีการแก้ไขที่ยังไม่ได้บันทึก
                    ElevatedButton(
                      onPressed: _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 20,
                          vertical: isDesktop ? 18 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(fontSize: bodyFontSize),
                      ),
                      child: const Text('ค้นหา'),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 180
                          : (isDesktop ? 160 : (screenWidth - 56) / 2 - 8),
                      // ใช้ DropdownButton ที่คุมค่าเองได้ เพื่อให้ค่าในช่องไม่เปลี่ยน
                      // เมื่อผู้ใช้กดยกเลิกการยืนยันทิ้งการแก้ไข
                      child: InputDecorator(
                        isEmpty: _filterType == null,
                        decoration: InputDecoration(
                          hintText: 'ประเภท',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 14 : 10,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _filterType,
                            isExpanded: true,
                            isDense: true,
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              color: Colors.black87,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'ทั้งหมด',
                                  style: TextStyle(fontSize: bodyFontSize),
                                ),
                              ),
                              ..._types.map(
                                (t) => DropdownMenuItem<String?>(
                                  value: t['code'],
                                  child: Text(
                                    t['name'] ?? '',
                                    style: TextStyle(fontSize: bodyFontSize),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _changeTypeFilter,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 160
                          : (isDesktop ? 140 : (screenWidth - 56) / 2 - 8),
                      // ช่องเลือกคุมค่าเองเช่นเดียวกับตัวกรองประเภท
                      child: InputDecorator(
                        isEmpty: _filterStatus == null,
                        decoration: InputDecoration(
                          hintText: 'สถานะ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 14 : 10,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _filterStatus,
                            isExpanded: true,
                            isDense: true,
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              color: Colors.black87,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'ทั้งหมด',
                                  style: TextStyle(fontSize: bodyFontSize),
                                ),
                              ),
                              ..._statuses.map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s['code'],
                                  child: Text(
                                    s['name'] ?? '',
                                    style: TextStyle(fontSize: bodyFontSize),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _changeStatusFilter,
                          ),
                        ),
                      ),
                    ),
                    // ตัวเลือกแถวต่อหน้าย้ายไปอยู่ในแถบแบ่งหน้าด้านล่างแล้ว
                  ],
                ),
              ),
            ),
            // Table
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'กำลังโหลดข้อมูล...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่พบข้อมูล',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มรายการ'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isDesktop ? 24 : 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              // ตารางเลื่อนแนวนอนได้เมื่อจอแคบกว่าความกว้างที่ต้องใช้
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final tableWidth =
                                      constraints.maxWidth < _minTableWidth
                                      ? _minTableWidth
                                      : constraints.maxWidth;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Column(
                                        children: [
                                          _tableHeader(bodyFontSize),
                                          ..._rows.asMap().entries.map(
                                            (e) => _editableRow(
                                              e.value,
                                              e.key,
                                              bodyFontSize,
                                              iconSize,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _rowActionBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            // แถบแบ่งหน้ามาตรฐาน — แสดงเมื่อมีข้อมูล เพราะมีตัวเลือกแถวต่อหน้าอยู่ด้วย
            if (!_isLoading && _rows.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: isDesktop ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: AppPagination(
                  currentPage: _currentPage,
                  totalPages: _totalPages == 0 ? 1 : _totalPages,
                  pageSize: _pageSize,
                  // ดึงข้อมูลทีละหน้าจาก API จึงต้องโหลดใหม่ทุกครั้งที่เปลี่ยน
                  onPageChanged: (p) async {
                    if (!await _confirmDiscard()) return;
                    _currentPage = p;
                    _loadData();
                  },
                  onPageSizeChanged: (s) async {
                    if (!await _confirmDiscard()) return;
                    _pageSize = s;
                    _currentPage = 0;
                    _loadData();
                  },
                ),
              ),
          ],
        ),
        floatingActionButton: isDesktop
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddEditDialog(),
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

/// หนึ่งแถวที่แก้ไขได้ในตารางประเภทห้อง
///
/// roomtypeID เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงไม่แสดงในตารางและแก้ไม่ได้
class _EditRow {
  /// รหัสเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalRoomtypeID;
  final String originalSequence;
  final String originalType;
  final String originalName;
  final String originalDescription;
  final String originalPrice;
  final String originalRemark;
  final String originalStatus;

  final TextEditingController sequenceCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController remarkCtrl;
  String type;
  String status;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalRoomtypeID,
    this.originalSequence = '',
    this.originalType = 'C',
    this.originalName = '',
    this.originalDescription = '',
    this.originalPrice = '',
    this.originalRemark = '',
    this.originalStatus = '1',
    required this.sequenceCtrl,
    required this.nameCtrl,
    required this.descriptionCtrl,
    required this.priceCtrl,
    required this.remarkCtrl,
    required this.type,
    required this.status,
  });

  factory _EditRow.from(Roomtype r) {
    final price = r.price?.toString() ?? '';
    return _EditRow(
      originalRoomtypeID: r.roomtypeID,
      originalSequence: '${r.sequence}',
      originalType: r.type ?? 'C',
      originalName: r.name,
      originalDescription: r.description ?? '',
      originalPrice: price,
      originalRemark: r.remark ?? '',
      originalStatus: r.status,
      sequenceCtrl: TextEditingController(text: '${r.sequence}'),
      nameCtrl: TextEditingController(text: r.name),
      descriptionCtrl: TextEditingController(text: r.description ?? ''),
      priceCtrl: TextEditingController(text: price),
      remarkCtrl: TextEditingController(text: r.remark ?? ''),
      type: r.type ?? 'C',
      status: r.status,
    );
  }

  /// แถวใหม่ — ตั้งประเภทและสถานะตามตัวกรองที่เลือกอยู่ ถ้าไม่ได้กรองใช้ค่าเริ่มต้น
  factory _EditRow.empty(String? defaultType, String? defaultStatus) =>
      _EditRow(
        sequenceCtrl: TextEditingController(),
        nameCtrl: TextEditingController(),
        descriptionCtrl: TextEditingController(),
        priceCtrl: TextEditingController(),
        remarkCtrl: TextEditingController(),
        type: defaultType ?? 'C',
        status: defaultStatus ?? '1',
      );

  bool get isNew => originalRoomtypeID == null;

  String get name => nameCtrl.text.trim();

  /// แถวเดิมที่ถูกแก้ค่าใดค่าหนึ่ง
  bool get changed =>
      !isNew &&
      (sequenceCtrl.text.trim() != originalSequence.trim() ||
          type != originalType ||
          name != originalName.trim() ||
          descriptionCtrl.text.trim() != originalDescription.trim() ||
          priceCtrl.text.trim() != originalPrice.trim() ||
          remarkCtrl.text.trim() != originalRemark.trim() ||
          status != originalStatus);

  Roomtype toRoomtype() => Roomtype(
    roomtypeID: originalRoomtypeID,
    name: name,
    type: type,
    description: descriptionCtrl.text.trim(),
    status: status,
    sequence: int.tryParse(sequenceCtrl.text.trim()) ?? 0,
    price: double.tryParse(priceCtrl.text.trim()),
    remark: remarkCtrl.text.trim(),
  );

  void dispose() {
    sequenceCtrl.dispose();
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    priceCtrl.dispose();
    remarkCtrl.dispose();
  }
}
