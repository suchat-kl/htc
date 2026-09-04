import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/employee.dart';
import '../models/organization.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final orgs = await widget.apiService.getOrganizationList();
      final users = await widget.apiService.getUserList();
      if (mounted) {
        setState(() {
          _organizations = orgs.where((o) => o.orgName != null && o.orgName!.isNotEmpty).toList();
          _users = users;
        });
      }
    } catch (e) {
      AppLogger.d('Error loading dropdowns: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getEmployees(
        page: _currentPage, size: _pageSize,
        name: _searchName, lastname: _searchLastname,
        orgID: _filterOrgID, userID: _filterUserID,
      );
      if (mounted) {
        final List<dynamic>? list = result['employees'] as List?;
        setState(() {
          _employees = list?.map((j) => Employee.fromJson(j)).toList() ?? [];
          _totalPages = result['totalPages'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); context.showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้'); }
    }
  }

  String _getOrgName(int? orgID) {
    if (orgID == null) return '-';
    return _organizations.firstWhere((o) => o.orgID == orgID, orElse: () => Organization(orgName: 'ไม่พบ')).orgName ?? '-';
  }

  String _getUserName(int? userID) {
    if (userID == null) return '-';
    final user = _users.firstWhere((u) => u['id'] == userID, orElse: () => {'fullName': 'ไม่พบ'});
    return user['fullName'] ?? 'ไม่พบ';
  }

  void _showAddEditDialog({Employee? employee}) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => _EmployeeDialog(employee: employee, apiService: widget.apiService, organizations: _organizations, users: _users),
    ).then((result) { if (result == true) _loadData(); });
  }

  Future<void> _deleteEmployee(Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text('ต้องการลบ "${emp.fullName}" ใช่หรือไม่?', style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('ลบ', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true && emp.empID != null) {
      try {
        await widget.apiService.deleteEmployee(emp.empID!);
        if (mounted) { context.showSuccessSnackBar('ลบข้อมูลสำเร็จ'); _loadData(); }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close, size: 28), onPressed: () => Navigator.pop(context), tooltip: 'กลับหน้าหลัก'),
        title: Text('บุคลากร', style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: Icon(Icons.add, size: iconSize), label: Text('เพิ่มรายการ', style: TextStyle(fontSize: bodyFontSize)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 14, vertical: isDesktop ? 14 : 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
          child: Center(
            child: Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [
              SizedBox(width: isLargeScreen ? 200 : (isDesktop ? 170 : double.infinity), child: TextField(style: TextStyle(fontSize: bodyFontSize), decoration: InputDecoration(hintText: 'ชื่อ...', prefixIcon: Icon(Icons.search, size: iconSize), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isDesktop ? 12 : 8)), onChanged: (v) { _searchName = v; _currentPage = 0; _loadData(); })),
              SizedBox(width: isLargeScreen ? 200 : (isDesktop ? 170 : double.infinity), child: TextField(style: TextStyle(fontSize: bodyFontSize), decoration: InputDecoration(hintText: 'นามสกุล...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isDesktop ? 12 : 8)), onChanged: (v) { _searchLastname = v; _currentPage = 0; _loadData(); })),
              SizedBox(width: isLargeScreen ? 250 : (isDesktop ? 220 : double.infinity), child: DropdownButtonFormField<int?>(initialValue: _filterOrgID, isExpanded: true, isDense: true, style: TextStyle(fontSize: bodyFontSize), decoration: InputDecoration(hintText: 'สังกัด', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isDesktop ? 12 : 8)), items: [DropdownMenuItem<int?>(value: null, child: Text('ทั้งหมด', style: TextStyle(fontSize: bodyFontSize))), ..._organizations.map((o) => DropdownMenuItem<int?>(value: o.orgID, child: Text(o.orgName ?? '', style: TextStyle(fontSize: bodyFontSize), overflow: TextOverflow.ellipsis)))], onChanged: (v) { _filterOrgID = v; _currentPage = 0; _loadData(); })),
              SizedBox(width: isLargeScreen ? 120 : (isDesktop ? 110 : 100), child: DropdownButtonFormField<int>(initialValue: _pageSize, isExpanded: true, isDense: true, style: TextStyle(fontSize: bodyFontSize), decoration: InputDecoration(hintText: 'แสดง', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isDesktop ? 12 : 8)), items: [5, 10, 15, 20].map((s) => DropdownMenuItem<int>(value: s, child: Text('$s แถว', style: TextStyle(fontSize: bodyFontSize)))).toList(), onChanged: (v) { _pageSize = v!; _currentPage = 0; _loadData(); })),
            ]),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text('ไม่พบข้อมูล', style: TextStyle(fontSize: 18, color: Colors.grey.shade500))]))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isDesktop ? 24 : 12),
                      child: Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withValues(alpha: 0.05)),
                          headingRowHeight: 50, dataRowMinHeight: 44, dataRowMaxHeight: 60,
                          columnSpacing: isLargeScreen ? 20 : (isDesktop ? 16 : 12),
                          columns: [
                            DataColumn(label: Text('รหัส', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('ชื่อ', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('นามสกุล', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('ตำแหน่ง', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('สังกัด', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('ผู้ใช้งาน', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            DataColumn(label: Text('จัดการ', style: TextStyle(fontSize: bodyFontSize, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                          ],
                          rows: _employees.map((e) => DataRow(cells: [
                            DataCell(Text('${e.empID ?? "-"}', style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Text(e.name ?? '-', style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Text(e.lastname ?? '-', style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Text(e.position ?? '-', style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Text(e.orgName ?? _getOrgName(e.orgID), style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Text(e.userName ?? _getUserName(e.userID), style: TextStyle(fontSize: bodyFontSize))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              InkWell(onTap: () => _showAddEditDialog(employee: e), borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.edit, size: iconSize, color: Colors.blue))),
                              const SizedBox(width: 6),
                              InkWell(onTap: () => _deleteEmployee(e), borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.delete, size: iconSize, color: Colors.red))),
                            ])),
                          ])).toList(),
                        ),
                      ))),
                    ),
        ),
        if (_totalPages > 1)
          Container(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: _currentPage > 0 ? () { _currentPage = 0; _loadData(); } : null, icon: Icon(Icons.first_page, size: iconSize)),
            IconButton(onPressed: _currentPage > 0 ? () { _currentPage--; _loadData(); } : null, icon: Icon(Icons.chevron_left, size: iconSize)),
            Text('หน้า ${_currentPage + 1} จาก $_totalPages', style: TextStyle(fontSize: bodyFontSize)),
            IconButton(onPressed: _currentPage < _totalPages - 1 ? () { _currentPage++; _loadData(); } : null, icon: Icon(Icons.chevron_right, size: iconSize)),
            IconButton(onPressed: _currentPage < _totalPages - 1 ? () { _currentPage = _totalPages - 1; _loadData(); } : null, icon: Icon(Icons.last_page, size: iconSize)),
          ])),
      ]),
      floatingActionButton: isDesktop ? null : FloatingActionButton(onPressed: () => _showAddEditDialog(), backgroundColor: AppTheme.primaryColor, child: const Icon(Icons.add)),
    );
  }
}

// ============ DIALOG ============
class _EmployeeDialog extends StatefulWidget {
  final Employee? employee;
  final ApiService apiService;
  final List<Organization> organizations;
  final List<Map<String, dynamic>> users;

  const _EmployeeDialog({this.employee, required this.apiService, required this.organizations, required this.users});

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
    _nameController.dispose(); _lastnameController.dispose(); _positionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final emp = Employee(
        empID: widget.employee?.empID,
        name: _nameController.text.trim(), lastname: _lastnameController.text.trim(),
        position: _positionController.text.trim(), orgID: _selectedOrgID ?? 10,
        userID: _selectedUserID,
      );
      if (isEdit) {
        await widget.apiService.updateEmployee(widget.employee!.empID!, emp);
      } else {
        await widget.apiService.createEmployee(emp);
      }
      if (mounted) { Navigator.pop(context, true); context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ'); }
    } catch (e) {
      setState(() { _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(width: isDesktop ? 550 : double.infinity, constraints: const BoxConstraints(maxWidth: 600), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: isDesktop ? 16 : 12), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(isEdit ? Icons.edit : Icons.add, color: AppTheme.primaryColor)), const SizedBox(width: 12), Expanded(child: Text(isEdit ? 'แก้ไขบุคลากร' : 'เพิ่มบุคลากร', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: Colors.white)))])),
          Flexible(child: SingleChildScrollView(padding: EdgeInsets.all(isDesktop ? 24 : 16), child: Form(key: _formKey, child: Column(children: [
            if (_errorMessage != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
            _buildField('ชื่อ', _nameController, isDesktop, validator: (v) => v?.isEmpty == true ? 'กรุณากรอกชื่อ' : null),
            const SizedBox(height: 14),
            _buildField('นามสกุล', _lastnameController, isDesktop, validator: (v) => v?.isEmpty == true ? 'กรุณากรอกนามสกุล' : null),
            const SizedBox(height: 14),
            _buildField('ตำแหน่ง', _positionController, isDesktop),
            const SizedBox(height: 14),
            _buildDropdown('สังกัด', _selectedOrgID, widget.organizations.map((o) => DropdownMenuItem<int>(value: o.orgID, child: Text(o.orgName ?? '', overflow: TextOverflow.ellipsis))).toList(), (v) => setState(() => _selectedOrgID = v)),
            const SizedBox(height: 14),
            _buildDropdown('ผู้ใช้งาน', _selectedUserID, [DropdownMenuItem<int?>(value: null, child: const Text('ไม่มี')), ...widget.users.map((u) => DropdownMenuItem<int?>(value: u['id'] as int?, child: Text(u['fullName'] ?? '')))], (v) => setState(() => _selectedUserID = v)),
            const SizedBox(height: 24),
            Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('ยกเลิก'))), const SizedBox(width: 16), Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _handleSave, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'อัปเดต' : 'บันทึก')))]),
          ])))),
        ])),
      );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isDesktop, {String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: isDesktop ? 14 : 13, fontWeight: FontWeight.w600)), const SizedBox(height: 6), TextFormField(controller: ctrl, validator: validator, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50), style: TextStyle(fontSize: isDesktop ? 15 : 14))]);
  }

  Widget _buildDropdown<T>(String label, T? value, List<DropdownMenuItem<T>> items, Function(T?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 6), DropdownButtonFormField<T>(initialValue: value, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50), items: items, onChanged: onChanged)]);
  }
}