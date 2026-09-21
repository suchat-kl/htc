import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/organization.dart';
import '../models/section.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import 'package:highway_training/utils/logger.dart';

class SectionScreen extends StatefulWidget {
  final ApiService apiService;
  const SectionScreen({super.key, required this.apiService});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  List<Section> _sections = [];
  List<Organization> _organizations = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  int? _filterOrgID;

  /// ช่องค้นหาชื่อกลุ่ม — ค้นหาเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น
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
  static const double _wCode = 90;
  static const double _wOrg = 240;
  static const double _wAction = 110;
  static const double _minTableWidth = 780;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    try {
      final orgs = await widget.apiService.getOrganizationList();
      if (mounted) {
        setState(
          () => _organizations = orgs
              .where((o) => o.orgName != null && o.orgName!.isNotEmpty)
              .toList(),
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading orgs: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getSections(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        orgID: _filterOrgID,
      );
      if (mounted) {
        final List<dynamic>? list = result['sections'] as List?;
        setState(() {
          _sections = list?.map((j) => Section.fromJson(j)).toList() ?? [];
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

  String _getOrgName(int? orgID) {
    if (orgID == null) return '-';
    return _organizations
            .firstWhere(
              (o) => o.orgID == orgID,
              orElse: () => Organization(orgName: 'ไม่พบ'),
            )
            .orgName ??
        '-';
  }

  void _showAddEditDialog({Section? section}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SectionDialog(
        section: section,
        apiService: widget.apiService,
        organizations: _organizations,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteSection(Section section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${section.name}" ใช่หรือไม่?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteColor,
            ),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && section.secID != null) {
      try {
        await widget.apiService.deleteSection(section.secID!);
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
      ..addAll(_sections.map(_EditRow.from));
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

  /// เพิ่มแถวว่างท้ายตาราง รหัสกลุ่มมาจากฐานข้อมูลจึงยังไม่มีค่า
  void _addRow() {
    setState(() => _rows.add(_EditRow.empty(_filterOrgID)));
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
        if (!r.isNew) _deletedIds.add(r.originalSecID!);
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
    final names = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final name = r.nameCtrl.text.trim();
      if (name.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกชื่อกลุ่ม';
      if (r.orgID == null) return 'แถวที่ $no ยังไม่ได้เลือกสังกัด';
      // ชื่อกลุ่มซ้ำกันได้ถ้าอยู่คนละสังกัด
      final key = '${r.orgID}|$name';
      if (names.containsKey(key)) {
        return 'ชื่อกลุ่ม "$name" ซ้ำกัน (แถวที่ ${names[key]! + 1} และ $no)';
      }
      names[key] = i;
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
        await widget.apiService.deleteSection(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        if (r.isNew) {
          await widget.apiService.createSection(r.toSection());
        } else if (r.changed) {
          await widget.apiService.updateSection(
            r.originalSecID!,
            r.toSection(),
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

  /// เปลี่ยนตัวกรองสังกัด — ถ้าผู้ใช้ไม่ยอมทิ้งการแก้ไข ค่าในช่องจะไม่เปลี่ยน
  Future<void> _changeOrgFilter(int? orgID) async {
    if (orgID == _filterOrgID) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _filterOrgID = orgID;
      _currentPage = 0;
    });
    _loadData();
  }

  /// รายการสังกัดของช่องเลือกในแถว — เติมค่าเดิมเข้าไปด้วยถ้ายังไม่มีในรายการ
  List<DropdownMenuItem<int>> _orgItems(_EditRow row) {
    final items = _organizations
        .where((o) => o.orgID != null)
        .map(
          (o) => DropdownMenuItem<int>(
            value: o.orgID!,
            child: Text(o.orgName ?? '', overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
    final id = row.orgID;
    if (id != null && !items.any((i) => i.value == id)) {
      items.insert(
        0,
        DropdownMenuItem<int>(
          value: id,
          child: Text(
            row.originalOrgName ?? _getOrgName(id),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(width: _wCheck, child: _headerCheckbox()),
          SizedBox(
            width: _wCode,
            child: Text('รหัสกลุ่ม', style: style),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('ชื่อกลุ่ม', style: style)),
          const SizedBox(width: 8),
          SizedBox(
            width: _wOrg,
            child: Text('รหัสสังกัด', style: style),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _wAction,
            child: Text('จัดการ', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัสกลุ่มเป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแสดงอย่างเดียว แก้ไม่ได้
  Widget _editableRow(
    _EditRow row,
    int index,
    double bodyFontSize,
    double iconSize,
  ) {
    return Container(
      key: ObjectKey(row),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : AppTheme.fieldFillColor,
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
          SizedBox(
            width: _wCode,
            child: Text(
              row.isNew ? 'ใหม่' : '${row.originalSecID}',
              style: TextStyle(
                fontSize: bodyFontSize,
                fontWeight: FontWeight.w500,
                color: row.isNew ? AppTheme.warningColor : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.nameCtrl,
              style: TextStyle(fontSize: bodyFontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _wOrg,
            child: DropdownButtonFormField<int>(
              initialValue: row.orgID,
              isExpanded: true,
              style: TextStyle(fontSize: bodyFontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _orgItems(row),
              onChanged: (v) => setState(() => row.orgID = v),
            ),
          ),
          const SizedBox(width: 8),
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
                      : () => _showAddEditDialog(section: row.toSection()),
                ),
                const SizedBox(width: 6),
                _iconAction(
                  icon: Icons.delete,
                  color: Colors.red,
                  iconSize: iconSize,
                  tooltip: 'ลบทันที',
                  onTap: row.isNew
                      ? null
                      : () => _deleteSection(row.toSection()),
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
            'กลุ่ม',
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
                          ? 250
                          : (isDesktop ? 220 : double.infinity),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อกลุ่ม...',
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
                        backgroundColor: AppTheme.searchColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 20,
                          vertical: isDesktop ? 16 : 14,
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
                          ? 280
                          : (isDesktop ? 250 : double.infinity),
                      // ใช้ DropdownButton ที่คุมค่าเองได้ เพื่อให้ค่าในช่องไม่เปลี่ยน
                      // เมื่อผู้ใช้กดยกเลิกการยืนยันทิ้งการแก้ไข
                      child: InputDecorator(
                        isEmpty: _filterOrgID == null,
                        decoration: InputDecoration(
                          hintText: 'สังกัด',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _filterOrgID,
                            isExpanded: true,
                            isDense: true,
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              color: Colors.black87,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'ทั้งหมด',
                                  style: TextStyle(fontSize: bodyFontSize),
                                ),
                              ),
                              ..._organizations.map(
                                (o) => DropdownMenuItem<int?>(
                                  value: o.orgID,
                                  child: Text(
                                    o.orgName ?? '',
                                    style: TextStyle(fontSize: bodyFontSize),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _changeOrgFilter,
                          ),
                        ),
                      ),
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
                            Icons.group_outlined,
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

/// หนึ่งแถวที่แก้ไขได้ในตารางกลุ่ม
///
/// รหัสกลุ่ม (secID) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแก้ไม่ได้และไม่ต้องกรอก
class _EditRow {
  /// รหัสเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalSecID;
  final String originalName;
  final int? originalOrgID;
  final String? originalOrgName;

  final TextEditingController nameCtrl;
  int? orgID;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalSecID,
    this.originalName = '',
    this.originalOrgID,
    this.originalOrgName,
    required this.nameCtrl,
    this.orgID,
  });

  factory _EditRow.from(Section s) => _EditRow(
    originalSecID: s.secID,
    originalName: s.name ?? '',
    originalOrgID: s.orgID,
    originalOrgName: s.orgName,
    nameCtrl: TextEditingController(text: s.name ?? ''),
    orgID: s.orgID,
  );

  /// แถวใหม่ — ตั้งสังกัดตามตัวกรองที่เลือกอยู่ ถ้าไม่ได้กรองใช้ค่าเริ่มต้น 10
  factory _EditRow.empty(int? defaultOrgID) =>
      _EditRow(nameCtrl: TextEditingController(), orgID: defaultOrgID ?? 10);

  bool get isNew => originalSecID == null;

  /// แถวเดิมที่ถูกแก้ชื่อหรือเปลี่ยนสังกัด
  bool get changed =>
      !isNew &&
      (nameCtrl.text.trim() != originalName.trim() || orgID != originalOrgID);

  Section toSection() => Section(
    secID: originalSecID,
    name: nameCtrl.text.trim(),
    orgID: orgID ?? 10,
  );

  void dispose() {
    nameCtrl.dispose();
  }
}

// ============ DIALOG ============
class _SectionDialog extends StatefulWidget {
  final Section? section;
  final ApiService apiService;
  final List<Organization> organizations;

  const _SectionDialog({
    this.section,
    required this.apiService,
    required this.organizations,
  });

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedOrgID = 10;
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.section != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.section!.name ?? '';
      _selectedOrgID = widget.section!.orgID ?? 10;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final section = Section(
        secID: widget.section?.secID,
        name: _nameController.text.trim(),
        orgID: _selectedOrgID ?? 10,
      );
      if (isEdit) {
        await widget.apiService.updateSection(widget.section!.secID!, section);
      } else {
        await widget.apiService.createSection(section);
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
                      isEdit ? 'แก้ไขกลุ่ม' : 'เพิ่มกลุ่ม',
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
                        'ชื่อกลุ่ม',
                        _nameController,
                        isDesktop,
                        validator: (v) =>
                            v?.isEmpty == true ? 'กรุณากรอกชื่อกลุ่ม' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        'รหัสสังกัด',
                        _selectedOrgID,
                        widget.organizations
                            .map(
                              (o) => DropdownMenuItem<int>(
                                value: o.orgID,
                                child: Text(
                                  o.orgName ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedOrgID = v),
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
                                backgroundColor: AppTheme.saveColor,
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    bool isDesktop, {
    String? Function(String?)? validator,
  }) {
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
