import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/employee.dart';
import '../models/organization.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import 'package:highway_training/utils/logger.dart';

class EmployeeScreen extends StatefulWidget {
  final ApiService apiService;
  const EmployeeScreen({super.key, required this.apiService});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  List<Employee> _employees = [];
  List<Organization> _organizations = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  String? _searchLastname;
  int? _filterOrgID;
  int? _filterUserID;

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสบุคลากรที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  /// สังกัดเริ่มต้นของแถวใหม่ ให้ตรงกับค่าเริ่มต้นในหน้าต่างเพิ่ม/แก้ไข
  static const int _defaultOrgID = 10;

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันทั้งหัวตารางและแถวข้อมูล
  // ตารางกว้างกว่าจอเล็ก จึงห่อด้วยตัวเลื่อนแนวนอนแล้วตรึงความกว้างไว้
  static const double _wCheck = 44;
  static const double _wCode = 60;
  static const double _wName = 150;
  static const double _wLastname = 150;
  static const double _wPosition = 170;
  static const double _wOrg = 220;
  static const double _wUser = 190;
  static const double _wAction = 100;
  static const double _colGap = 8;
  static const double _tableWidth =
      _wCheck +
      _wCode +
      _wName +
      _wLastname +
      _wPosition +
      _wOrg +
      _wUser +
      _wAction +
      _colGap * 7 +
      32;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDropdowns();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final orgs = await widget.apiService.getOrganizationList();
      final users = await widget.apiService.getUserList();
      if (mounted) {
        setState(() {
          _organizations = orgs
              .where((o) => o.orgName != null && o.orgName!.isNotEmpty)
              .toList();
          _users = users;
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading dropdowns: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getEmployees(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        lastname: _searchLastname,
        orgID: _filterOrgID,
        userID: _filterUserID,
      );
      if (mounted) {
        final List<dynamic>? list = result['employees'] as List?;
        setState(() {
          _employees = list?.map((j) => Employee.fromJson(j)).toList() ?? [];
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

  String _getUserName(int? userID) {
    if (userID == null) return '-';
    final user = _users.firstWhere(
      (u) => u['id'] == userID,
      orElse: () => {'fullName': 'ไม่พบ'},
    );
    return user['fullName'] ?? 'ไม่พบ';
  }

  void _showAddEditDialog({Employee? employee}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EmployeeDialog(
        employee: employee,
        apiService: widget.apiService,
        organizations: _organizations,
        users: _users,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteEmployee(Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${emp.fullName}" ใช่หรือไม่?',
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
    if (confirm == true && emp.empID != null) {
      try {
        await widget.apiService.deleteEmployee(emp.empID!);
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
      ..addAll(_employees.map(_EditRow.from));
  }

  /// มีการแก้ไขที่ยังไม่ได้บันทึกหรือไม่
  bool get _dirty =>
      _rows.any((r) => r.isNew || r.changed) || _deletedIds.isNotEmpty;

  Widget _headerCheckbox() {
    final selected = _rows.where((r) => r.selected).length;
    final value = _rows.isEmpty || selected == 0
        ? false
        : (selected == _rows.length ? true : null);
    // หัวตารางพื้นอ่อน จึงใช้สีมาตรฐานของธีมได้เลย
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

  /// เพิ่มแถวว่างท้ายตาราง สังกัดตั้งค่าเริ่มต้นเหมือนหน้าต่างเพิ่มข้อมูล
  void _addRow() {
    setState(() => _rows.add(_EditRow.empty(_defaultOrgID)));
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
        if (!r.isNew) _deletedIds.add(r.originalEmpID!);
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
    final fullNames = <String, int>{};
    final userIDs = <int, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final name = r.nameCtrl.text.trim();
      final lastname = r.lastnameCtrl.text.trim();
      if (name.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกชื่อ';
      if (lastname.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกนามสกุล';
      if (r.orgID == null) return 'แถวที่ $no ยังไม่ได้เลือกสังกัด';

      final fullName = '$name $lastname';
      if (fullNames.containsKey(fullName)) {
        return 'ชื่อ $fullName ซ้ำกัน (แถวที่ ${fullNames[fullName]! + 1} และ $no)';
      }
      fullNames[fullName] = i;

      // ผู้ใช้งานหนึ่งบัญชีผูกได้กับบุคลากรคนเดียว ถ้าซ้ำจะอ้างอิงผิดคน
      final userID = r.userID;
      if (userID != null) {
        if (userIDs.containsKey(userID)) {
          return 'ผู้ใช้งาน ${_getUserName(userID)} ถูกเลือกซ้ำ '
              '(แถวที่ ${userIDs[userID]! + 1} และ $no)';
        }
        userIDs[userID] = i;
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
        await widget.apiService.deleteEmployee(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        if (r.isNew) {
          await widget.apiService.createEmployee(r.toEmployee());
        } else if (r.changed) {
          await widget.apiService.updateEmployee(
            r.originalEmpID!,
            r.toEmployee(),
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

  /// รายการสังกัดของ dropdown ในแถว
  ///
  /// ถ้าค่าปัจจุบันไม่มีในรายการ (สังกัดถูกลบ หรือรายการยังโหลดไม่เสร็จ)
  /// ให้ใส่รายการนั้นเพิ่มไว้ ไม่งั้น DropdownButtonFormField จะ assert
  List<DropdownMenuItem<int>> _orgItems(int? current) {
    final items = _organizations
        .where((o) => o.orgID != null)
        .map(
          (o) => DropdownMenuItem<int>(
            value: o.orgID,
            child: Text(o.orgName ?? '', overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
    if (current != null && !_organizations.any((o) => o.orgID == current)) {
      items.add(
        DropdownMenuItem<int>(
          value: current,
          child: Text(_getOrgName(current), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  /// รายการผู้ใช้งานของ dropdown ในแถว — เลือก "ไม่มี" ได้
  List<DropdownMenuItem<int?>> _userItems(int? current) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('ไม่มี')),
      ..._users.map(
        (u) => DropdownMenuItem<int?>(
          value: u['id'] as int?,
          child: Text(u['fullName'] ?? '', overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    if (current != null && !_users.any((u) => u['id'] == current)) {
      items.add(
        DropdownMenuItem<int?>(
          value: current,
          child: Text(_getUserName(current), overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  /// หัวตารางที่แก้ไขได้
  Widget _tableHeader(double fontSize) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryColor,
    );
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(width: _wCheck, child: _headerCheckbox()),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wCode,
            child: Text('รหัส', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wName,
            child: Text('ชื่อ', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wLastname,
            child: Text('นามสกุล', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wPosition,
            child: Text('ตำแหน่ง', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wOrg,
            child: Text('สังกัด', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wUser,
            child: Text('ผู้ใช้งาน', style: style),
          ),
          const SizedBox(width: _colGap),
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
  /// รหัสบุคลากร (empID) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแสดงอย่างเดียว
  /// แถวที่เพิ่งเพิ่มยังไม่มีรหัส จึงแสดงขีดและปิดปุ่มรายแถวไว้
  Widget _editableRow(_EditRow row, int index, double fontSize, double icon) {
    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wCode,
            child: Text(
              row.isNew ? '-' : '${row.originalEmpID}',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wName,
            child: TextField(
              controller: row.nameCtrl,
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wLastname,
            child: TextField(
              controller: row.lastnameCtrl,
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wPosition,
            child: TextField(
              controller: row.positionCtrl,
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wOrg,
            child: DropdownButtonFormField<int>(
              // ผูก key กับแถว เพื่อให้ค่าที่แสดงตรงกับข้อมูลเสมอหลังโหลดใหม่
              key: ValueKey('org-${row.uid}'),
              initialValue: row.orgID,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _orgItems(row.orgID),
              onChanged: (v) => setState(() => row.orgID = v),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wUser,
            child: DropdownButtonFormField<int?>(
              key: ValueKey('user-${row.uid}'),
              initialValue: row.userID,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _userItems(row.userID),
              onChanged: (v) => setState(() => row.userID = v),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _showAddEditDialog(employee: row.toEmployee()),
                  icon: Icon(Icons.edit, size: icon, color: Colors.blue),
                  tooltip: 'แก้ไขในหน้าต่าง',
                ),
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _deleteEmployee(row.toEmployee()),
                  icon: Icon(Icons.delete, size: icon, color: Colors.red),
                  tooltip: 'ลบทันที',
                ),
              ],
            ),
          ),
        ],
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
            'บุคลากร',
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
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ชื่อ...',
                          prefixIcon: Icon(Icons.search, size: iconSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        onChanged: (v) {
                          _searchName = v;
                          _currentPage = 0;
                          _loadData();
                        },
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 170 : double.infinity),
                      child: TextField(
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'นามสกุล...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        onChanged: (v) {
                          _searchLastname = v;
                          _currentPage = 0;
                          _loadData();
                        },
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 250
                          : (isDesktop ? 220 : double.infinity),
                      child: DropdownButtonFormField<int?>(
                        initialValue: _filterOrgID,
                        isExpanded: true,
                        isDense: true,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'สังกัด',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: isDesktop ? 12 : 8,
                          ),
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
                        onChanged: (v) {
                          _filterOrgID = v;
                          _currentPage = 0;
                          _loadData();
                        },
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
                            Icons.people_outline,
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
                          // ตารางกว้างกว่าจอ จึงเลื่อนแนวนอนได้
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: _tableWidth,
                              child: Column(
                                children: [
                                  _tableHeader(bodyFontSize),
                                  for (var i = 0; i < _rows.length; i++)
                                    _editableRow(
                                      _rows[i],
                                      i,
                                      bodyFontSize,
                                      iconSize,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // แถวปุ่มของการแก้ไขในตาราง แสดงตลอดเพื่อให้กดเพิ่มแถวแรกได้
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

/// หนึ่งแถวที่แก้ไขได้ในตารางบุคลากร
class _EditRow {
  /// รหัสบุคลากรเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalEmpID;
  final Employee? original;

  /// ตัวเลขประจำแถว ใช้เป็น key ของ dropdown ไม่ให้ค่าค้างข้ามการโหลดใหม่
  final int uid;
  static int _uidSeq = 0;

  final TextEditingController nameCtrl;
  final TextEditingController lastnameCtrl;
  final TextEditingController positionCtrl;

  int? orgID;
  int? userID;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalEmpID,
    this.original,
    required this.nameCtrl,
    required this.lastnameCtrl,
    required this.positionCtrl,
    this.orgID,
    this.userID,
  }) : uid = ++_uidSeq;

  factory _EditRow.from(Employee e) => _EditRow(
    originalEmpID: e.empID,
    original: e,
    nameCtrl: TextEditingController(text: e.name ?? ''),
    lastnameCtrl: TextEditingController(text: e.lastname ?? ''),
    positionCtrl: TextEditingController(text: e.position ?? ''),
    orgID: e.orgID,
    userID: e.userID,
  );

  factory _EditRow.empty(int defaultOrgID) => _EditRow(
    nameCtrl: TextEditingController(),
    lastnameCtrl: TextEditingController(),
    positionCtrl: TextEditingController(),
    orgID: defaultOrgID,
  );

  bool get isNew => originalEmpID == null;

  /// แถวเดิมที่มีค่าอย่างน้อยหนึ่งช่องเปลี่ยนไป
  bool get changed {
    if (isNew || original == null) return false;
    final o = original!;
    return nameCtrl.text.trim() != (o.name ?? '').trim() ||
        lastnameCtrl.text.trim() != (o.lastname ?? '').trim() ||
        positionCtrl.text.trim() != (o.position ?? '').trim() ||
        orgID != o.orgID ||
        userID != o.userID;
  }

  Employee toEmployee() => Employee(
    empID: originalEmpID,
    name: nameCtrl.text.trim(),
    lastname: lastnameCtrl.text.trim(),
    position: positionCtrl.text.trim(),
    orgID: orgID ?? 10,
    userID: userID,
  );

  void dispose() {
    nameCtrl.dispose();
    lastnameCtrl.dispose();
    positionCtrl.dispose();
  }
}

// ============ DIALOG ============
class _EmployeeDialog extends StatefulWidget {
  final Employee? employee;
  final ApiService apiService;
  final List<Organization> organizations;
  final List<Map<String, dynamic>> users;

  const _EmployeeDialog({
    this.employee,
    required this.apiService,
    required this.organizations,
    required this.users,
  });

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _positionController = TextEditingController();
  int? _selectedOrgID = 10;
  int? _selectedUserID;
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.employee!.name ?? '';
      _lastnameController.text = widget.employee!.lastname ?? '';
      _positionController.text = widget.employee!.position ?? '';
      _selectedOrgID = widget.employee!.orgID ?? 10;
      _selectedUserID = widget.employee!.userID;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastnameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final emp = Employee(
        empID: widget.employee?.empID,
        name: _nameController.text.trim(),
        lastname: _lastnameController.text.trim(),
        position: _positionController.text.trim(),
        orgID: _selectedOrgID ?? 10,
        userID: _selectedUserID,
      );
      if (isEdit) {
        await widget.apiService.updateEmployee(widget.employee!.empID!, emp);
      } else {
        await widget.apiService.createEmployee(emp);
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
                      isEdit ? 'แก้ไขบุคลากร' : 'เพิ่มบุคลากร',
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
                        'ชื่อ',
                        _nameController,
                        isDesktop,
                        validator: (v) =>
                            v?.isEmpty == true ? 'กรุณากรอกชื่อ' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        'นามสกุล',
                        _lastnameController,
                        isDesktop,
                        validator: (v) =>
                            v?.isEmpty == true ? 'กรุณากรอกนามสกุล' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField('ตำแหน่ง', _positionController, isDesktop),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        'สังกัด',
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
                      const SizedBox(height: 14),
                      _buildDropdown('ผู้ใช้งาน', _selectedUserID, [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: const Text('ไม่มี'),
                        ),
                        ...widget.users.map(
                          (u) => DropdownMenuItem<int?>(
                            value: u['id'] as int?,
                            child: Text(u['fullName'] ?? ''),
                          ),
                        ),
                      ], (v) => setState(() => _selectedUserID = v)),
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
            fillColor: Colors.grey.shade50,
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
            fillColor: Colors.grey.shade50,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
