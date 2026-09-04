import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/organization.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAllOrgs();
  }

  Future<void> _loadAllOrgs() async {
    try {
      final orgs = await widget.apiService.getOrganizationList();
      if (mounted) setState(() => _allOrgs = orgs);
    } catch (e) {
      AppLogger.d('Error loading orgs: $e');
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

  String _getParentName(int? parentId) {
    if (parentId == null) return '-';
    return _allOrgs
            .firstWhere(
              (o) => o.orgID == parentId,
              orElse: () => Organization(orgName: 'ไม่พบ'),
            )
            .orgName ??
        '-';
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
      if (result == true) _loadData();
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
        }
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
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
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
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ค้นหารหัส...',
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
                        _searchCode = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isLargeScreen
                        ? 250
                        : (isDesktop ? 220 : double.infinity),
                    child: TextField(
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาชื่อ...',
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
                        ? 150
                        : (isDesktop ? 130 : (screenWidth - 56) / 2 - 6),
                    child: 
                    TextField(
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาระดับ...',
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
                        _filterLevel = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                    
                   
                  ),
                  
                  SizedBox(
                    width: isLargeScreen ? 130 : (isDesktop ? 120 : 110),
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize,
                      isExpanded: true, // ✅ Add this
                      isDense: true, // ✅ Add this
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                         contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: isDesktop ? 12 : 8,
                        ), // ✅ Reduce padding
                      ),
                      items: [5, 10, 15, 20]
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s,
                              child: Text(
                                '$s แถว',
                                style: TextStyle(fontSize: bodyFontSize),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        _pageSize = v!;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _organizations.isEmpty
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppTheme.primaryColor.withValues(alpha: 0.05),
                            ),
                            headingRowHeight: 50,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 60,
                            columnSpacing: isLargeScreen
                                ? 24
                                : (isDesktop ? 20 : 14),
                            columns: [
                              /*
                              DataColumn(
                                label: Text(
                                  'orgID',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),

                              ),
                              */
                              DataColumn(
                                label: Text(
                                  'รหัส',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ต้นสังกัด',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ระดับ',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ชื่อหน่วยงาน',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'จัดการ',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                            rows: _organizations
                                .map(
                                  (o) => DataRow(
                                    cells: [
                                      /*
                                      DataCell(
                                        Text(
                                          '${o.orgID ?? "-"}',
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                          ),
                                        ),
                                      ),
*/
                                      DataCell(
                                        Text(
                                          o.orgCode ?? '-',
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _getParentName(o.orgidParent),
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          ' ${o.orgLevel ?? "-"}',
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: 300,
                                          ),
                                          child: Text(
                                            o.orgName ?? '-',
                                            style: TextStyle(
                                              fontSize: bodyFontSize,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _showAddEditDialog(org: o),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.edit,
                                                  size: iconSize,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _deleteOrg(o),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.delete,
                                                  size: iconSize,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (_totalPages > 1)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () {
                            _currentPage = 0;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.first_page, size: iconSize),
                  ),
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () {
                            _currentPage--;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.chevron_left, size: iconSize),
                  ),
                  Text(
                    'หน้า ${_currentPage + 1} จาก $_totalPages',
                    style: TextStyle(fontSize: bodyFontSize),
                  ),
                  IconButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            _currentPage++;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.chevron_right, size: iconSize),
                  ),
                  IconButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            _currentPage = _totalPages - 1;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.last_page, size: iconSize),
                  ),
                ],
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
    );
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
                      _buildDropdown(
                        'ต้นสังกัด',
                        _selectedParentID,
                        [
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
                        ],
                        (v) => setState(() => _selectedParentID = v),
                      ),
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
