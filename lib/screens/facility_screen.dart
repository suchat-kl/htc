import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/facility.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../widgets/app_pagination.dart';
import '../widgets/facility_dialog.dart';
import '../utils/snackbar_helper.dart';

class FacilityScreen extends StatefulWidget {
  final ApiService apiService;

  const FacilityScreen({super.key, required this.apiService});

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  List<Facility> _facilities = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  // String? _filterType;
  String? _filterStatus;

  /// ช่องค้นหา — ค้นเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น
  final TextEditingController _searchCtrl = TextEditingController();

  /// นับรอบรีเซ็ตตัวกรอง — เปลี่ยนค่าเพื่อบังคับสร้าง dropdown ใหม่
  /// ให้กลับไปแสดงค่าเดิมเมื่อผู้ใช้ไม่ยอมทิ้งการแก้ไข
  int _filterEpoch = 0;

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getFacilities(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        // type: _filterType,
        status: _filterStatus,
      );

      if (mounted) {
        setState(() {
          _facilities = (result['facilities'] as List)
              .map((j) => Facility.fromJson(j))
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

  void _showAddEditDialog({Facility? facility}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          FacilityDialog(facility: facility, apiService: widget.apiService),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteFacility(Facility facility) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${facility.name}" ใช่หรือไม่?',
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
        await widget.apiService.deleteFacility(facility.facilityID!);
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
      ..addAll(_facilities.map(_EditRow.from));
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

  /// เพิ่มแถวว่างท้ายตาราง รหัสเป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่ให้กรอก
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
  ///
  /// รหัสเป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่มีการตรวจรหัสซ้ำ
  /// แต่ชื่อรายการต้องไม่ซ้ำกัน
  String? _validateRows() {
    final names = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final name = r.nameCtrl.text.trim();
      if (name.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกรายการ';
      if (r.sequence == null) return 'แถวที่ $no ลำดับต้องเป็นตัวเลข';
      if (names.containsKey(name)) {
        return 'รายการ "$name" ซ้ำกัน (แถวที่ ${names[name]! + 1} และ $no)';
      }
      names[name] = i;
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
        await widget.apiService.deleteFacility(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        final item = r.toFacility();
        if (r.isNew) {
          await widget.apiService.createFacility(item);
        } else if (r.changed) {
          await widget.apiService.updateFacility(r.originalId!, item);
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

  /// ค้นหาตามคำในช่องค้นหา — เรียกจากปุ่มค้นหาและการกด Enter
  Future<void> _search() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchName = _searchCtrl.text;
      _currentPage = 0;
    });
    _loadData();
  }

  /// ล้างคำค้นแล้วโหลดใหม่
  Future<void> _clearSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchCtrl.clear();
      _searchName = '';
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปลี่ยนตัวกรองสถานะ — ถ้าไม่ยอมทิ้งการแก้ไข ให้ dropdown กลับไปแสดงค่าเดิม
  Future<void> _changeStatusFilter(String? value) async {
    if (value == _filterStatus) return;
    if (!await _confirmDiscard()) {
      setState(() => _filterEpoch++);
      return;
    }
    setState(() {
      _filterStatus = value;
      _currentPage = 0;
    });
    _loadData();
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัส (facilityID) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงไม่แสดงและแก้ไม่ได้
  DataRow _editableRow(
    _EditRow row,
    int index,
    bool isDesktop,
    bool isLargeScreen,
    double bodyFontSize,
    double iconSize,
  ) {
    final isEvenRow = index % 2 == 0;
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.hovered)) {
          return AppTheme.primaryColor.withValues(alpha: 0.05);
        }
        return isEvenRow ? Colors.white : AppTheme.fieldFillColor;
      }),
      cells: [
        DataCell(
          Checkbox(
            value: row.selected,
            activeColor: AppTheme.primaryColor,
            onChanged: (v) => setState(() => row.selected = v ?? false),
          ),
        ),

        // ลำดับ
        DataCell(
          _rowInputField(row.seqCtrl, 70, bodyFontSize, digitsOnly: true),
        ),

        // รายการ
        DataCell(
          _rowInputField(
            row.nameCtrl,
            isLargeScreen ? 300 : (isDesktop ? 220 : 180),
            bodyFontSize,
          ),
        ),

        // คำอธิบาย
        DataCell(
          _rowInputField(
            row.descCtrl,
            isLargeScreen ? 350 : (isDesktop ? 250 : 200),
            bodyFontSize,
          ),
        ),

        // สถานะ
        DataCell(
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              initialValue: row.status,
              isExpanded: true,
              style: TextStyle(
                fontSize: bodyFontSize,
                color: AppTheme.textPrimary,
              ),
              decoration: _rowInput(),
              items: const [
                DropdownMenuItem(value: '1', child: Text('ใช้งาน')),
                DropdownMenuItem(value: '2', child: Text('ไม่ใช้งาน')),
              ],
              onChanged: (v) => setState(() => row.status = v ?? '1'),
            ),
          ),
        ),

        // จัดการ
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rowIcon(
                Icons.edit,
                Colors.blue,
                iconSize,
                'แก้ไขในหน้าต่าง',
                row.isNew
                    ? null
                    : () => _showAddEditDialog(facility: row.toFacility()),
              ),
              const SizedBox(width: 8),
              _rowIcon(
                Icons.delete,
                Colors.red,
                iconSize,
                'ลบทันที',
                row.isNew ? null : () => _deleteFacility(row.toFacility()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ปุ่มไอคอนรายแถว ปิดไว้สำหรับแถวที่เพิ่งเพิ่ม (ยังไม่มีในฐานข้อมูล)
  Widget _rowIcon(
    IconData icon,
    Color color,
    double iconSize,
    String tooltip,
    VoidCallback? onTap,
  ) {
    final c = onTap == null ? Colors.grey : color;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: iconSize, color: c),
        ),
      ),
    );
  }

  Widget _rowInputField(
    TextEditingController c,
    double w,
    double fontSize, {
    bool digitsOnly = false,
  }) {
    return SizedBox(
      width: w,
      child: TextField(
        controller: c,
        style: TextStyle(fontSize: fontSize),
        keyboardType: digitsOnly ? TextInputType.number : null,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: _rowInput(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_dirty)
            Text(
              'มีการแก้ไขที่ยังไม่ได้บันทึก',
              style: TextStyle(fontSize: 13, color: AppTheme.warningColor),
            ),
          _rowButton(
            'ลบที่เลือก',
            _deleteSelectedRows,
            color: AppTheme.deleteColor,
          ),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          _rowButton('เพิ่ม', _addRow, color: AppTheme.addColor),
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

  Widget _columnLabel(String text, double fontSize) => Text(
    text,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryColor,
    ),
  );

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
            'สิ่งอำนวยความสะดวก (Facility)',
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
                        controller: _searchCtrl,
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
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: iconSize),
                                  tooltip: 'ล้างคำค้น',
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                        // พิมพ์แล้วให้ปุ่มกากบาทโผล่/หาย แต่ยังไม่โหลดข้อมูล
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _search(),
                      ),
                    ),

                    // ปุ่มค้นหา — โหลดข้อมูลใหม่เมื่อกดเท่านั้น
                    ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.searchColor,
                        foregroundColor: Colors.white,
                        padding: buttonPadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(fontSize: bodyFontSize),
                      ),
                      child: const Text('ค้นหา'),
                    ),

                    // Status filter
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 180 : (screenWidth - 56) / 2 - 8),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('fstatus-$_filterStatus-$_filterEpoch'),
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
                        onChanged: _changeStatusFilter,
                      ),
                    ),

                    // ตัวเลือกแถวต่อหน้าย้ายไปอยู่ในแถบแบ่งหน้า AppPagination ด้านล่างแล้ว

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
                          'ทั้งหมด: ${_facilities.length} รายการ',
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
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('เพิ่มแถวในตาราง'),
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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppTheme.primaryColor.withValues(alpha: 0.05),
                                ),
                                headingRowHeight: isDesktop ? 60 : 50,
                                dataRowMinHeight: isDesktop ? 60 : 56,
                                dataRowMaxHeight: isDesktop ? 80 : 72,
                                columnSpacing: isLargeScreen
                                    ? 32
                                    : (isDesktop ? 24 : 16),
                                horizontalMargin: isDesktop ? 24 : 16,
                                columns: [
                                  DataColumn(label: _headerCheckbox()),
                                  DataColumn(
                                    label: _columnLabel('ลำดับ', bodyFontSize),
                                  ),
                                  DataColumn(
                                    label: _columnLabel('รายการ', bodyFontSize),
                                  ),
                                  DataColumn(
                                    label: _columnLabel(
                                      'คำอธิบาย',
                                      bodyFontSize,
                                    ),
                                  ),
                                  DataColumn(
                                    label: _columnLabel('สถานะ', bodyFontSize),
                                  ),
                                  DataColumn(
                                    label: _columnLabel('จัดการ', bodyFontSize),
                                  ),
                                ],
                                rows: _rows.asMap().entries.map((entry) {
                                  return _editableRow(
                                    entry.value,
                                    entry.key,
                                    isDesktop,
                                    isLargeScreen,
                                    bodyFontSize,
                                    iconSize,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            _rowActionBar(isDesktop),

            // แถบแบ่งหน้ามาตรฐาน — แสดงตลอดเพราะมีตัวเลือกแถวต่อหน้าอยู่ด้วย
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
                  setState(() => _currentPage = page);
                  _loadData();
                },
                onPageSizeChanged: (size) async {
                  if (!await _confirmDiscard()) return;
                  setState(() {
                    _pageSize = size;
                    _currentPage = 0;
                  });
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

/// หนึ่งแถวที่แก้ไขได้ในตารางสิ่งอำนวยความสะดวก
class _EditRow {
  /// รหัสเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalId;
  final String originalName;
  final String originalDesc;
  final String originalStatus;
  final String originalSeq;

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController seqCtrl;

  /// สถานะ ('1' = ใช้งาน, '2' = ไม่ใช้งาน)
  String status;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalId,
    this.originalName = '',
    this.originalDesc = '',
    this.originalStatus = '1',
    this.originalSeq = '0',
    this.status = '1',
    required this.nameCtrl,
    required this.descCtrl,
    required this.seqCtrl,
  });

  factory _EditRow.from(Facility f) {
    final seq = '${f.sequence}';
    return _EditRow(
      originalId: f.facilityID,
      originalName: f.name,
      originalDesc: f.description ?? '',
      originalStatus: f.status,
      originalSeq: seq,
      status: f.status,
      nameCtrl: TextEditingController(text: f.name),
      descCtrl: TextEditingController(text: f.description ?? ''),
      seqCtrl: TextEditingController(text: seq),
    );
  }

  factory _EditRow.empty() => _EditRow(
    nameCtrl: TextEditingController(),
    descCtrl: TextEditingController(),
    seqCtrl: TextEditingController(text: '0'),
  );

  bool get isNew => originalId == null;

  /// ว่างถือเป็น 0 — null แปลว่ากรอกมาไม่ใช่ตัวเลข
  int? get sequence {
    final t = seqCtrl.text.trim();
    return t.isEmpty ? 0 : int.tryParse(t);
  }

  /// แถวเดิมที่ถูกแก้ค่าใดค่าหนึ่ง
  bool get changed =>
      !isNew &&
      (status != originalStatus ||
          nameCtrl.text.trim() != originalName.trim() ||
          descCtrl.text.trim() != originalDesc.trim() ||
          seqCtrl.text.trim() != originalSeq.trim());

  Facility toFacility() => Facility(
    facilityID: originalId,
    name: nameCtrl.text.trim(),
    description: descCtrl.text.trim(),
    status: status,
    sequence: sequence ?? 0,
  );

  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    seqCtrl.dispose();
  }
}
