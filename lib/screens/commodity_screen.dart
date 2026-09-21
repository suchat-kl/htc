import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../widgets/app_pagination.dart';
import '../widgets/commodity_dialog.dart';
import '../utils/snackbar_helper.dart';

class CommodityScreen extends StatefulWidget {
  final ApiService apiService;

  const CommodityScreen({super.key, required this.apiService});

  @override
  State<CommodityScreen> createState() => _CommodityScreenState();
}

class _CommodityScreenState extends State<CommodityScreen> {
  List<Commodity> _commodities = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  String? _filterType;
  String? _filterStatus;

  /// ช่องค้นหา — ค้นหาเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น ไม่โหลดทุกตัวอักษร
  final TextEditingController _searchController = TextEditingController();

  /// เปลี่ยนค่าเพื่อบังคับสร้างตัวกรอง dropdown ใหม่
  /// ใช้ตอนผู้ใช้กดยกเลิกการยืนยัน เพื่อให้ dropdown กลับไปแสดงค่าเดิม
  int _filterRevision = 0;

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันระหว่างหัวตารางกับแถวข้อมูล
  static const double _wCheck = 48;
  static const double _wSequence = 80;
  static const double _wType = 150;
  static const double _wName = 240;
  static const double _wDescription = 260;
  static const double _wStock = 90;
  static const double _wStatus = 150;
  static const double _wAction = 110;

  static const double _tableWidth =
      _wCheck +
      _wSequence +
      _wType +
      _wName +
      _wDescription +
      _wStock +
      _wStatus +
      _wAction +
      24;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getCommodities(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        type: _filterType,
        status: _filterStatus,
      );

      if (mounted) {
        setState(() {
          _commodities = (result['commodities'] as List)
              .map((j) => Commodity.fromJson(j))
              .toList();
          _totalPages = result['totalPages'] ?? 0;
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

  void _showAddEditDialog({Commodity? commodity}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          CommodityDialog(commodity: commodity, apiService: widget.apiService),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteCommodity(Commodity commodity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${commodity.name}" ใช่หรือไม่?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteColor,
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
        await widget.apiService.deleteCommodity(commodity.commodityId!);
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
      ..addAll(_commodities.map(_EditRow.from));
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

  /// เพิ่มแถวว่างท้ายตาราง
  void _addRow() {
    setState(() => _rows.add(_EditRow.empty()));
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
        if (!r.isNew) _deletedIds.add(r.originalId!);
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
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      if (r.nameCtrl.text.trim().isEmpty) {
        return 'แถวที่ $no ยังไม่ได้กรอกรายการ';
      }
      if (int.tryParse(r.sequenceCtrl.text.trim()) == null) {
        return 'แถวที่ $no ลำดับต้องเป็นตัวเลข';
      }
    }
    return null;
  }

  /// บันทึกทุกแถวที่แก้ไขในครั้งเดียว
  ///
  /// ลบแถวที่เอาออก สร้างแถวใหม่ และอัปเดตแถวที่ค่าเปลี่ยน แล้วโหลดข้อมูลใหม่
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
        await widget.apiService.deleteCommodity(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        final item = r.toCommodity();
        if (r.isNew) {
          await widget.apiService.createCommodity(item);
        } else if (r.changed) {
          await widget.apiService.updateCommodity(r.originalId!, item);
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

  // ---------------------------------------------------------------------------
  // ค้นหา — ทุกทางที่ทำให้โหลดข้อมูลใหม่ต้องถามก่อนถ้ายังมีการแก้ไขค้าง
  // ---------------------------------------------------------------------------

  /// ค้นหาตามคำในช่องค้นหา (กดปุ่มค้นหา หรือกด Enter)
  Future<void> _runSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchName = _searchController.text;
      _currentPage = 0;
    });
    _loadData();
  }

  /// ล้างคำค้นแล้วโหลดใหม่
  Future<void> _clearSearch() async {
    if (!await _confirmDiscard()) return;
    _searchController.clear();
    setState(() {
      _searchName = null;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปลี่ยนตัวกรองประเภท — กดยกเลิกแล้วค่าเดิมต้องไม่เปลี่ยน
  Future<void> _changeFilterType(String? value) async {
    if (!await _confirmDiscard()) {
      setState(() => _filterRevision++);
      return;
    }
    setState(() {
      _filterType = value;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปลี่ยนตัวกรองสถานะ — กดยกเลิกแล้วค่าเดิมต้องไม่เปลี่ยน
  Future<void> _changeFilterStatus(String? value) async {
    if (!await _confirmDiscard()) {
      setState(() => _filterRevision++);
      return;
    }
    setState(() {
      _filterStatus = value;
      _currentPage = 0;
    });
    _loadData();
  }

  Widget _headerCell(String text, double width, {TextAlign? align}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  /// หัวตาราง — กว้างเท่ากับแถวข้อมูลเพื่อให้เลื่อนไปพร้อมกัน
  Widget _tableHeader() {
    return Container(
      width: _tableWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(width: _wCheck, child: _headerCheckbox()),
          _headerCell('ลำดับ', _wSequence),
          _headerCell('ประเภท', _wType),
          _headerCell('รายการ', _wName),
          _headerCell('คำอธิบาย', _wDescription),
          _headerCell('คงเหลือ', _wStock, align: TextAlign.right),
          _headerCell('สถานะ', _wStatus),
          _headerCell('จัดการ', _wAction, align: TextAlign.center),
        ],
      ),
    );
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัส (commodityId) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงไม่แสดงและแก้ไม่ได้
  /// ส่วน "คงเหลือ" ระบบคำนวณจากการเบิกจ่าย จึงแสดงอย่างเดียวเหมือนหน้าต่างเดิม
  Widget _editableRow(_EditRow row, int index) {
    return Container(
      // ผูก key กับแถว เพื่อให้ dropdown ไม่สลับค่ากันเมื่อมีการลบ/เพิ่มแถว
      key: ValueKey(row.uid),
      width: _tableWidth,
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : AppTheme.fieldFillColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          _cell(
            _wSequence,
            TextField(
              controller: row.sequenceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _cell(
            _wType,
            DropdownButtonFormField<String>(
              key: ValueKey('type-${row.uid}-${row.type}'),
              initialValue: _codeOrNull(row.type, const ['B', 'C']),
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _rowInput(),
              items: const [
                DropdownMenuItem(value: 'B', child: Text('เครื่องนอน')),
                DropdownMenuItem(value: 'C', child: Text('ของใช้')),
              ],
              onChanged: (v) => setState(() => row.type = v ?? row.type),
            ),
          ),
          _cell(
            _wName,
            TextField(
              controller: row.nameCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _cell(
            _wDescription,
            TextField(
              controller: row.descriptionCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _cell(
            _wStock,
            Text(
              '${row.stockLevel}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _cell(
            _wStatus,
            DropdownButtonFormField<String>(
              key: ValueKey('status-${row.uid}-${row.status}'),
              initialValue: _codeOrNull(row.status, const ['1', '2']),
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _rowInput(),
              items: const [
                DropdownMenuItem(value: '1', child: Text('ใช้งาน')),
                DropdownMenuItem(value: '2', child: Text('ไม่ใช้งาน')),
              ],
              onChanged: (v) => setState(() => row.status = v ?? row.status),
            ),
          ),
          SizedBox(
            width: _wAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _showAddEditDialog(commodity: row.toCommodity()),
                  icon: const Icon(Icons.edit, size: 20, color: AppTheme.primaryColor),
                  tooltip: 'แก้ไขในหน้าต่าง',
                ),
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _deleteCommodity(row.toCommodity()),
                  icon: const Icon(Icons.delete, size: 20, color: AppTheme.deleteColor),
                  tooltip: 'ลบทันที',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// คืน null ถ้าค่าที่มีอยู่ไม่ตรงกับตัวเลือกใด เพื่อไม่ให้ dropdown พัง
  String? _codeOrNull(String value, List<String> codes) {
    return codes.contains(value) ? value : null;
  }

  Widget _cell(double width, Widget child) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
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
          _rowButton(
            'ลบที่เลือก',
            _deleteSelectedRows,
            color: AppTheme.deleteColor,
          ),
          const SizedBox(width: 12),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          const SizedBox(width: 4),
          _rowButton('เพิ่ม', _addRow, color: AppTheme.addColor),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.saveColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.saveColor.withValues(
                alpha: 0.45,
              ),
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

  Widget _rowButton(
    String label,
    VoidCallback? onTap, {
    Color color = AppTheme.neutralColor,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
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
    // final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;

    // Calculate responsive sizes
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: isDesktop ? 20 : 14,
      vertical: isDesktop ? 14 : 10,
    );
    final tablePadding = isLargeScreen ? 24.0 : (isDesktop ? 20.0 : 12.0);

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
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: 'กลับหน้าหลัก',
              child: Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _closeScreen,
                  borderRadius: BorderRadius.circular(10),
                  child: const Center(
                    child: Icon(Icons.close, size: 24, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            'เครื่องนอน-ของใช้ (Commodity)',
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
                  backgroundColor: AppTheme.addColor,
                  foregroundColor: Colors.white,
                  padding: buttonPadding,
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
            // Search & Filter Bar
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
                    // Search field
                    SizedBox(
                      width: isLargeScreen
                          ? 350
                          : (isDesktop ? 280 : double.infinity),
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
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isDesktop ? 14 : 10,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.clear, size: iconSize),
                                  tooltip: 'ล้างคำค้น',
                                  onPressed: _clearSearch,
                                ),
                        ),
                        // พิมพ์แล้วไม่โหลดข้อมูล แค่ให้ปุ่มกากบาทโผล่/หาย
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),

                    // ปุ่มค้นหา — โหลดข้อมูลใหม่เมื่อกดเท่านั้น
                    ElevatedButton(
                      onPressed: _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.searchColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 18,
                          vertical: isDesktop ? 18 : 14,
                        ),
                        textStyle: TextStyle(fontSize: bodyFontSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ค้นหา'),
                    ),

                    // Type filter
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 180 : (screenWidth - 56) / 2 - 8),
                      child: DropdownButtonFormField<String>(
                        // key เปลี่ยนทุกครั้งที่ค่าเปลี่ยนหรือผู้ใช้กดยกเลิก
                        // เพื่อให้ช่องกลับไปแสดงค่าที่ใช้กรองอยู่จริง
                        key: ValueKey(
                          'filter-type-$_filterType-$_filterRevision',
                        ),
                        initialValue: _filterType,
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ประเภท',
                          hintStyle: TextStyle(fontSize: bodyFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isDesktop ? 14 : 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'ทั้งหมด',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'B',
                            child: Text(
                              'เครื่องนอน',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'C',
                            child: Text(
                              'ของใช้',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                        ],
                        onChanged: _changeFilterType,
                      ),
                    ),

                    // Status filter
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 180 : (screenWidth - 56) / 2 - 8),
                      child: DropdownButtonFormField<String>(
                        // key เปลี่ยนทุกครั้งที่ค่าเปลี่ยนหรือผู้ใช้กดยกเลิก
                        // เพื่อให้ช่องกลับไปแสดงค่าที่ใช้กรองอยู่จริง
                        key: ValueKey(
                          'filter-status-$_filterStatus-$_filterRevision',
                        ),
                        initialValue: _filterStatus,
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'สถานะ',
                          hintStyle: TextStyle(fontSize: bodyFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isDesktop ? 14 : 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'ทั้งหมด',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: '1',
                            child: Text(
                              'ใช้งาน',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: '2',
                            child: Text(
                              'ไม่ใช้งาน',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                        ],
                        onChanged: _changeFilterStatus,
                      ),
                    ),

                    // ตัวเลือกแถวต่อหน้าย้ายไปอยู่ในแถบแบ่งหน้า (AppPagination) แล้ว

                    // Total count
                    if (isDesktop)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isDesktop ? 14 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          'ทั้งหมด: ${_commodities.length} รายการ',
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
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
                            Icons.inventory_2_outlined,
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
                              backgroundColor: AppTheme.addColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: AppTheme.fieldFillColor,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(tablePadding),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            // ตารางกว้างกว่าจอได้ จึงเลื่อนแนวนอนทั้งหัวและแถว
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _tableHeader(),
                                  for (var i = 0; i < _rows.length; i++)
                                    _editableRow(_rows[i], i),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            _rowActionBar(),

            // แถบแบ่งหน้ามาตรฐาน (มีตัวเลือกแถวต่อหน้าในตัว)
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
                totalPages: _totalPages,
                pageSize: _pageSize,
                onPageChanged: (page) async {
                  if (!await _confirmDiscard()) return;
                  _currentPage = page;
                  _loadData();
                },
                onPageSizeChanged: (size) async {
                  if (!await _confirmDiscard()) return;
                  _pageSize = size;
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

/// หนึ่งแถวที่แก้ไขได้ในตารางเครื่องนอน-ของใช้
class _EditRow {
  /// รหัสเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalId;
  final String originalSequence;
  final String originalName;
  final String originalDescription;
  final String originalType;
  final String originalStatus;

  /// คงเหลือ ระบบคำนวณให้ แก้ในตารางไม่ได้ (เหมือนหน้าต่างเพิ่ม/แก้ไข)
  final double stockLevel;

  final TextEditingController sequenceCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;

  /// ใช้เป็น key ของแถวในหน้าจอ
  final UniqueKey uid = UniqueKey();

  String type;
  String status;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalId,
    this.originalSequence = '',
    this.originalName = '',
    this.originalDescription = '',
    this.originalType = 'B',
    this.originalStatus = '1',
    this.stockLevel = 0.0,
    required this.sequenceCtrl,
    required this.nameCtrl,
    required this.descriptionCtrl,
    required this.type,
    required this.status,
  });

  factory _EditRow.from(Commodity c) => _EditRow(
    originalId: c.commodityId,
    originalSequence: '${c.sequence}',
    originalName: c.name,
    originalDescription: c.description ?? '',
    originalType: c.type,
    originalStatus: c.status,
    stockLevel: c.stockLevel,
    sequenceCtrl: TextEditingController(text: '${c.sequence}'),
    nameCtrl: TextEditingController(text: c.name),
    descriptionCtrl: TextEditingController(text: c.description ?? ''),
    type: c.type,
    status: c.status,
  );

  factory _EditRow.empty() => _EditRow(
    sequenceCtrl: TextEditingController(text: '0'),
    nameCtrl: TextEditingController(),
    descriptionCtrl: TextEditingController(),
    type: 'B',
    status: '1',
  );

  bool get isNew => originalId == null;

  /// แถวเดิมที่มีค่าใดค่าหนึ่งเปลี่ยนไป
  bool get changed =>
      !isNew &&
      (sequenceCtrl.text.trim() != originalSequence.trim() ||
          nameCtrl.text.trim() != originalName.trim() ||
          descriptionCtrl.text.trim() != originalDescription.trim() ||
          type != originalType ||
          status != originalStatus);

  Commodity toCommodity() => Commodity(
    commodityId: originalId,
    name: nameCtrl.text.trim(),
    description: descriptionCtrl.text.trim(),
    status: status,
    sequence: int.tryParse(sequenceCtrl.text.trim()) ?? 0,
    type: type,
    stockLevel: stockLevel,
  );

  void dispose() {
    sequenceCtrl.dispose();
    nameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}
