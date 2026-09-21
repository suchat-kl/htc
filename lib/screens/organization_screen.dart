import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/organization.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import 'package:highway_training/utils/logger.dart';

class OrganizationScreen extends StatefulWidget {
  final ApiService apiService;
  const OrganizationScreen({super.key, required this.apiService});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  List<Organization> _organizations = [];
  List<Organization> _allOrgs = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchCode;
  String? _searchName;
  String? _filterLevel;

  /// ช่องค้นหา — ค้นหาเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น ไม่โหลดทุกตัวอักษร
  final TextEditingController _codeSearchCtrl = TextEditingController();
  final TextEditingController _nameSearchCtrl = TextEditingController();
  final TextEditingController _levelSearchCtrl = TextEditingController();

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันระหว่างหัวตารางกับแถวข้อมูล
  static const double _wCheck = 48;
  static const double _wCode = 150;
  static const double _wParent = 280;
  static const double _wLevel = 100;
  static const double _wName = 320;
  static const double _wAction = 110;

  static const double _tableWidth =
      _wCheck + _wCode + _wParent + _wLevel + _wName + _wAction + 24;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAllOrgs();
  }

  @override
  void dispose() {
    _codeSearchCtrl.dispose();
    _nameSearchCtrl.dispose();
    _levelSearchCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllOrgs() async {
    try {
      final orgs = await widget.apiService.getOrganizationList();
      if (mounted) setState(() => _allOrgs = orgs);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading orgs: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getOrganizations(
        page: _currentPage,
        size: _pageSize,
        orgCode: _searchCode,
        orgName: _searchName,
        orgLevel: _filterLevel,
      );
      if (mounted) {
        final List<dynamic>? list = result['organizations'] as List?;
        setState(() {
          _organizations =
              list?.map((j) => Organization.fromJson(j)).toList() ?? [];
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

  void _showAddEditDialog({Organization? org}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OrganizationDialog(
        org: org,
        apiService: widget.apiService,
        allOrgs: _allOrgs,
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
        _loadAllOrgs();
      }
    });
  }

  Future<void> _deleteOrg(Organization org) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${org.orgName}" ใช่หรือไม่?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && org.orgID != null) {
      try {
        await widget.apiService.deleteOrganization(org.orgID!);
        if (mounted) {
          context.showSuccessSnackBar('ลบข้อมูลสำเร็จ');
          _loadData();
          _loadAllOrgs();
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
      ..addAll(_organizations.map(_EditRow.from));
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
    final codes = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final code = r.codeCtrl.text.trim();
      if (code.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกรหัสหน่วยงาน';
      if (r.nameCtrl.text.trim().isEmpty) {
        return 'แถวที่ $no ยังไม่ได้กรอกชื่อหน่วยงาน';
      }
      if (codes.containsKey(code)) {
        return 'รหัส $code ซ้ำกัน (แถวที่ ${codes[code]! + 1} และ $no)';
      }
      codes[code] = i;
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
        await widget.apiService.deleteOrganization(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        final item = r.toOrganization();
        if (r.isNew) {
          await widget.apiService.createOrganization(item);
        } else if (r.changed) {
          await widget.apiService.updateOrganization(r.originalId!, item);
        }
      }

      if (!mounted) return;
      context.showSuccessSnackBar('บันทึกเรียบร้อยแล้ว');
      setState(() => _isSaving = false);
      await _loadData();
      await _loadAllOrgs();
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

  /// ค้นหาตามค่าในช่องค้นหาทั้งสามช่อง (กดปุ่มค้นหา หรือกด Enter)
  Future<void> _runSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchCode = _codeSearchCtrl.text;
      _searchName = _nameSearchCtrl.text;
      _filterLevel = _levelSearchCtrl.text;
      _currentPage = 0;
    });
    _loadData();
  }

  /// ล้างคำค้นทั้งหมดแล้วโหลดใหม่
  Future<void> _clearSearch() async {
    if (!await _confirmDiscard()) return;
    _codeSearchCtrl.clear();
    _nameSearchCtrl.clear();
    _levelSearchCtrl.clear();
    setState(() {
      _searchCode = null;
      _searchName = null;
      _filterLevel = null;
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
          _headerCell('รหัส', _wCode),
          _headerCell('ต้นสังกัด', _wParent),
          _headerCell('ระดับ', _wLevel),
          _headerCell('ชื่อหน่วยงาน', _wName),
          _headerCell('จัดการ', _wAction, align: TextAlign.center),
        ],
      ),
    );
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// orgID เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงไม่แสดงและแก้ไม่ได้
  Widget _editableRow(_EditRow row, int index) {
    // ต้นสังกัดต้องเป็นค่าที่มีอยู่ในรายการ ไม่งั้น dropdown จะพัง
    final parentValue = _allOrgs.any((o) => o.orgID == row.parentId)
        ? row.parentId
        : null;

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
            _wCode,
            TextField(
              controller: row.codeCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _cell(
            _wParent,
            DropdownButtonFormField<int?>(
              // key เปลี่ยนตามค่าและจำนวนหน่วยงาน เพื่อให้แสดงต้นสังกัดถูกต้อง
              // แม้รายการหน่วยงานจะโหลดเสร็จทีหลัง
              key: ValueKey(
                'parent-${row.uid}-${_allOrgs.length}-$parentValue',
              ),
              initialValue: parentValue,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: _rowInput(),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('-')),
                ..._allOrgs.map(
                  (o) => DropdownMenuItem<int?>(
                    value: o.orgID,
                    child: Text(
                      o.orgName ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => row.parentId = v),
            ),
          ),
          _cell(
            _wLevel,
            TextField(
              controller: row.levelCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
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
          SizedBox(
            width: _wAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _showAddEditDialog(org: row.toOrganization()),
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  tooltip: 'แก้ไขในหน้าต่าง',
                ),
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _deleteOrg(row.toOrganization()),
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: 'ลบทันที',
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          _rowButton('ลบที่เลือก', _deleteSelectedRows),
          const SizedBox(width: 12),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          const SizedBox(width: 4),
          _rowButton('เพิ่ม', _addRow),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
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
            'รหัสหน่วยงาน',
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
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 170 : double.infinity),
                      child: TextField(
                        controller: _codeSearchCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหารหัส...',
                          prefixIcon: Icon(Icons.search, size: iconSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // พิมพ์แล้วไม่โหลดข้อมูล ค้นหาเมื่อกดปุ่มหรือกด Enter
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 250
                          : (isDesktop ? 220 : double.infinity),
                      child: TextField(
                        controller: _nameSearchCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อ...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // พิมพ์แล้วไม่โหลดข้อมูล ค้นหาเมื่อกดปุ่มหรือกด Enter
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),

                    SizedBox(
                      width: isLargeScreen
                          ? 150
                          : (isDesktop ? 130 : (screenWidth - 56) / 2 - 6),
                      child: TextField(
                        controller: _levelSearchCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาระดับ...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // พิมพ์แล้วไม่โหลดข้อมูล ค้นหาเมื่อกดปุ่มหรือกด Enter
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),

                    // ปุ่มค้นหา — โหลดข้อมูลใหม่เมื่อกดเท่านั้น
                    ElevatedButton(
                      onPressed: _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 18,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        textStyle: TextStyle(fontSize: bodyFontSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ค้นหา'),
                    ),

                    // ปุ่มล้างคำค้นทั้งหมด
                    OutlinedButton(
                      onPressed: _clearSearch,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 16,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        textStyle: TextStyle(fontSize: bodyFontSize),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ล้าง'),
                    ),

                    // ตัวเลือกแถวต่อหน้าย้ายไปอยู่ในแถบแบ่งหน้า AppPagination ด้านล่างแล้ว
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
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

            _rowActionBar(),

            // แถบแบ่งหน้ามาตรฐาน — แสดงตลอดเพราะมีตัวเลือกแถวต่อหน้าอยู่ด้วย
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

/// หนึ่งแถวที่แก้ไขได้ในตารางรหัสหน่วยงาน
class _EditRow {
  /// orgID เดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalId;
  final String originalCode;
  final String originalName;
  final String originalLevel;
  final int? originalParentId;

  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController levelCtrl;

  /// ใช้เป็น key ของแถวในหน้าจอ
  final UniqueKey uid = UniqueKey();

  int? parentId;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalId,
    this.originalCode = '',
    this.originalName = '',
    this.originalLevel = '',
    this.originalParentId,
    this.parentId,
    required this.codeCtrl,
    required this.nameCtrl,
    required this.levelCtrl,
  });

  factory _EditRow.from(Organization o) => _EditRow(
    originalId: o.orgID,
    originalCode: o.orgCode ?? '',
    originalName: o.orgName ?? '',
    originalLevel: o.orgLevel ?? '',
    originalParentId: o.orgidParent,
    parentId: o.orgidParent,
    codeCtrl: TextEditingController(text: o.orgCode ?? ''),
    nameCtrl: TextEditingController(text: o.orgName ?? ''),
    levelCtrl: TextEditingController(text: o.orgLevel ?? ''),
  );

  factory _EditRow.empty() => _EditRow(
    codeCtrl: TextEditingController(),
    nameCtrl: TextEditingController(),
    levelCtrl: TextEditingController(),
  );

  bool get isNew => originalId == null;

  /// แถวเดิมที่มีค่าใดค่าหนึ่งเปลี่ยนไป
  bool get changed =>
      !isNew &&
      (codeCtrl.text.trim() != originalCode.trim() ||
          nameCtrl.text.trim() != originalName.trim() ||
          levelCtrl.text.trim() != originalLevel.trim() ||
          parentId != originalParentId);

  Organization toOrganization() => Organization(
    orgID: originalId,
    orgCode: codeCtrl.text.trim(),
    orgName: nameCtrl.text.trim(),
    orgLevel: levelCtrl.text.trim(),
    orgidParent: parentId,
  );

  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    levelCtrl.dispose();
  }
}

// ============ DIALOG ============
class _OrganizationDialog extends StatefulWidget {
  final Organization? org;
  final ApiService apiService;
  final List<Organization> allOrgs;

  const _OrganizationDialog({
    this.org,
    required this.apiService,
    required this.allOrgs,
  });

  @override
  State<_OrganizationDialog> createState() => _OrganizationDialogState();
}

class _OrganizationDialogState extends State<_OrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _orgCodeController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _orgLevelController = TextEditingController();

  int? _selectedParentID;
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.org != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _orgCodeController.text = widget.org!.orgCode ?? '';
      _orgNameController.text = widget.org!.orgName ?? '';
      _orgLevelController.text = widget.org!.orgLevel ?? '';
      _selectedParentID = widget.org!.orgidParent;
    }
  }

  @override
  void dispose() {
    _orgCodeController.dispose();
    _orgNameController.dispose();
    _orgLevelController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final org = Organization(
        orgID: widget.org?.orgID,
        orgCode: _orgCodeController.text.trim(),
        orgName: _orgNameController.text.trim(),
        orgLevel: _orgLevelController.text.trim(),
        orgidParent: _selectedParentID,
      );
      if (isEdit) {
        await widget.apiService.updateOrganization(widget.org!.orgID!, org);
      } else {
        await widget.apiService.createOrganization(org);
      }
      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 550 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: isDesktop ? 16 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'แก้ไขหน่วยงาน' : 'เพิ่มหน่วยงาน',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      _buildField(
                        'รหัสหน่วยงาน',
                        _orgCodeController,
                        isDesktop,
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown('ต้นสังกัด', _selectedParentID, [
                        // DropdownMenuItem<int?>(
                        //   value: null,
                        //   child: const Text('ไม่มี'),
                        // ),
                        ...widget.allOrgs.map(
                          (o) => DropdownMenuItem<int?>(
                            value: o.orgID,
                            child: Text(o.orgName ?? ''),
                          ),
                        ),
                      ], (v) => setState(() => _selectedParentID = v)),
                      const SizedBox(height: 14),
                      _buildField('ระดับ', _orgLevelController, isDesktop),
                      const SizedBox(height: 14),
                      _buildField(
                        'ชื่อหน่วยงาน',
                        _orgNameController,
                        isDesktop,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('ยกเลิก'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(isEdit ? 'อัปเดต' : 'บันทึก'),
                            ),
                          ),
                        ],
                      ),
                    ], // ✅ Column children close
                  ), // ✅ Column close
                ), // ✅ Form close
              ), // ✅ SingleChildScrollView close
            ), // ✅ Flexible close
          ], // ✅ Main Column children close
        ), // ✅ Main Column close
      ), // ✅ Container close
    ); // ✅ Dialog close
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    bool isDesktop, [
    String? Function(String?)? validator,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.fieldFillColor,
          ),
          style: TextStyle(fontSize: isDesktop ? 15 : 14),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    Function(T?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.fieldFillColor,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
