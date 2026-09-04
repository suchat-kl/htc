import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/part.dart';
import '../services/api_service.dart';
import '../widgets/part_dialog.dart';
import '../utils/snackbar_helper.dart';

class PartScreen extends StatefulWidget {
  final ApiService apiService;
  const PartScreen({super.key, required this.apiService});

  @override
  State<PartScreen> createState() => _PartScreenState();
}

class _PartScreenState extends State<PartScreen> {
  List<Part> _parts = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchName;
  String? _filterType;
  String? _filterStatus;

  static const List<Map<String, String>> _types = [
    {'code': 'S', 'name': 'Stock'},
    {'code': 'N', 'name': 'Empty'},
  ];

  static const List<Map<String, String>> _statuses = [
    {'code': '1', 'name': 'ใช้งาน'},
    {'code': '2', 'name': 'ไม่ใช้งาน'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getParts(
        page: _currentPage,
        size: _pageSize,
        name: _searchName,
        type: _filterType,
        status: _filterStatus,
      );
      if (mounted) {
        final List<dynamic>? list = result['parts'] as List?;
        setState(() {
          _parts = list?.map((j) => Part.fromJson(j)).toList() ?? [];
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

  String _getTypeName(String? code) {
    if (code == null) return '-';
    return _types.firstWhere(
          (t) => t['code'] == code,
          orElse: () => {'name': code},
        )['name'] ??
        code;
  }

  String _getStatusName(String? code) {
    if (code == null) return '-';
    return _statuses.firstWhere(
          (s) => s['code'] == code,
          orElse: () => {'name': code},
        )['name'] ??
        code;
  }

  void _showAddEditDialog({Part? part}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PartDialog(part: part, apiService: widget.apiService),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deletePart(Part part) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${part.name}" ใช่หรือไม่?',
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
    if (confirm == true) {
      try {
        await widget.apiService.deletePart(part.partID!);
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
    final smallFontSize = isLargeScreen ? 14.0 : (isDesktop ? 13.0 : 12.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'วัสดุซ่อมบำรุง (Part)',
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
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  // ✅ TextField with matching height
                  SizedBox(
                    width: isLargeScreen
                        ? 220
                        : (isDesktop ? 180 : double.infinity),
                    height: isDesktop ? 48 : 44, // ✅ Fixed height
                    child: TextField(
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ค้นหารายการ...',
                        prefixIcon: Icon(Icons.search, size: iconSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isDesktop ? 14 : 12,
                        ), // ✅ Match dropdown
                      ),
                      onChanged: (v) {
                        _searchName = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),

                  // ✅ Dropdown with matching height
                  SizedBox(
                    width: isLargeScreen
                        ? 160
                        : (isDesktop ? 140 : (screenWidth - 56) / 2 - 6),
                    height: isDesktop ? 48 : 44, // ✅ Same fixed height
                    child: DropdownButtonFormField<String?>(
                      initialValue: _filterType, // ✅ Use value, not initialValue
                      isExpanded: true,
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ประเภท',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isDesktop ? 14 : 12,
                        ), // ✅ Same padding
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
                              t['name']!,
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _filterType = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),

                  // ✅ Status dropdown
                  SizedBox(
                    width: isLargeScreen
                        ? 160
                        : (isDesktop ? 140 : (screenWidth - 56) / 2 - 6),
                    height: isDesktop ? 48 : 44,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _filterStatus,
                      isExpanded: true,
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'สถานะ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isDesktop ? 14 : 12,
                        ),
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
                              s['name']!,
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _filterStatus = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),

                  // ✅ Page size dropdown
                  SizedBox(
                    width: isLargeScreen ? 120 : (isDesktop ? 100 : 100),
                    height: isDesktop ? 48 : 44,
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize,
                      isExpanded: true,
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isDesktop ? 14 : 12,
                        ),
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
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _parts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.build_outlined,
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
                            headingRowHeight: 56,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 64,
                            columnSpacing: isLargeScreen
                                ? 24
                                : (isDesktop ? 20 : 14),
                            columns: [
                              DataColumn(
                                label: Text(
                                  'ลำดับ',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'รายการ',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ประเภท',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'จำนวน',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  'หน่วย',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'สถานะ',
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
                            rows: _parts.asMap().entries.map((e) {
                              final i = e.key;
                              final p = e.value;
                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (s) => s.contains(WidgetState.hovered)
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.05,
                                        )
                                      : (i % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.shade50),
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      '${p.sequence}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      p.name ?? '-',
                                      style: TextStyle(
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _getTypeName(p.type),
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${p.stockLevel}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      p.unit ?? '-',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.status == '1'
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getStatusName(p.status),
                                        style: TextStyle(
                                          fontSize: smallFontSize,
                                          color: p.status == '1'
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              _showAddEditDialog(part: p),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
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
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _deletePart(p),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
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
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          // Pagination
          if (_totalPages > 1)
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
                  ...List.generate(_totalPages.clamp(0, 5), (i) {
                    int p = _totalPages <= 5
                        ? i
                        : (_currentPage < 3
                              ? i
                              : (_currentPage > _totalPages - 3
                                    ? _totalPages - 5 + i
                                    : _currentPage - 2 + i));
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () {
                          _currentPage = p;
                          _loadData();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _currentPage == p
                                ? AppTheme.primaryColor
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${p + 1}',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: _currentPage == p
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
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
                  const SizedBox(width: 16),
                  Text(
                    'หน้า ${_currentPage + 1} จาก $_totalPages',
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      color: Colors.grey.shade600,
                    ),
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
