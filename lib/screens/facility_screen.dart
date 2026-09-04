import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/facility.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;

    // Calculate responsive sizes
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final smallFontSize = isLargeScreen ? 14.0 : (isDesktop ? 13.0 : 12.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: isDesktop ? 20 : 14,
      vertical: isDesktop ? 14 : 10,
    );
    final tablePadding = isLargeScreen ? 24.0 : (isDesktop ? 20.0 : 12.0);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Tooltip(
            message: 'กลับหน้าหลัก',
            child: Material(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
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
                backgroundColor: AppTheme.secondaryColor,
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
                      ),
                      onChanged: (v) {
                        _searchName = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
              
                  // Type filter
                       /*       SizedBox(
                    width: isLargeScreen
                        ? 200
                        : (isDesktop ? 180 : (screenWidth - 56) / 2 - 8),
                    child: DropdownButtonFormField<String>(
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
                        fillColor: Colors.grey.shade50,
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
                      onChanged: (v) {
                        _filterType = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
              */
                  // Status filter
                  SizedBox(
                    width: isLargeScreen
                        ? 200
                        : (isDesktop ? 180 : (screenWidth - 56) / 2 - 8),
                    child: DropdownButtonFormField<String>(
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
                        fillColor: Colors.grey.shade50,
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
                      onChanged: (v) {
                        _filterStatus = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
              
                  // Page size selector
                  SizedBox(
                    width: isLargeScreen ? 130 : (isDesktop ? 120 : 100),
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize,
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        hintStyle: TextStyle(fontSize: bodyFontSize),
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
                      items: [5, 10, 20, 50, 100]
                          .map(
                            (size) => DropdownMenuItem<int>(
                              value: size,
                              child: Text(
                                '$size แถว',
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
                : _facilities.isEmpty
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
                    color: Colors.grey.shade50,
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
                              dataRowMinHeight: isDesktop ? 60 : 50,
                              dataRowMaxHeight: isDesktop ? 80 : 70,
                              columnSpacing: isLargeScreen
                                  ? 32
                                  : (isDesktop ? 24 : 16),
                              horizontalMargin: isDesktop ? 24 : 16,
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
                                  numeric: true,
                                ),
                                // DataColumn(
                                //   label: Text(
                                //     'ประเภท',
                                //     style: TextStyle(
                                //       fontSize: bodyFontSize,
                                //       fontWeight: FontWeight.bold,
                                //       color: AppTheme.primaryColor,
                                //     ),
                                //   ),
                                // ),
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
                                    'คำอธิบาย',
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                // DataColumn(
                                //   label: Text(
                                //     'Stock',
                                //     style: TextStyle(
                                //       fontSize: bodyFontSize,
                                //       fontWeight: FontWeight.bold,
                                //       color: AppTheme.primaryColor,
                                //     ),
                                //   ),
                                //   numeric: true,
                                // ),
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
                              rows: _facilities.asMap().entries.map((entry) {
                                final index = entry.key;
                                final c = entry.value;
                                final isEvenRow = index % 2 == 0;

                                return DataRow(
                                  color:
                                      WidgetStateProperty.resolveWith<Color?>((
                                        Set<WidgetState> states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.hovered,
                                        )) {
                                          return AppTheme.primaryColor
                                              .withValues(alpha: 0.05);
                                        }
                                        return isEvenRow
                                            ? Colors.white
                                            : Colors.grey.shade50;
                                      }),
                                  cells: [
                                    // ลำดับ
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${c.sequence}',
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    // ประเภท
                                    // DataCell(
                                    //   Container(
                                    //     padding: const EdgeInsets.symmetric(
                                    //       horizontal: 12,
                                    //       vertical: 6,
                                    //     ),
                                    //     decoration: BoxDecoration(
                                    //       color: c.type == 'B'
                                    //           ? Colors.blue.withValues(
                                    //               alpha: 0.08,
                                    //             )
                                    //           : Colors.orange.withValues(
                                    //               alpha: 0.08,
                                    //             ),
                                    //       borderRadius: BorderRadius.circular(
                                    //         8,
                                    //       ),
                                    //       border: Border.all(
                                    //         color: c.type == 'B'
                                    //             ? Colors.blue.withValues(
                                    //                 alpha: 0.3,
                                    //               )
                                    //             : Colors.orange.withValues(
                                    //                 alpha: 0.3,
                                    //               ),
                                    //       ),
                                    //     ),
                                    //     child: Text(
                                    //       c.typeName,
                                    //       style: TextStyle(
                                    //         fontSize: bodyFontSize,
                                    //         fontWeight: FontWeight.w500,
                                    //         color: c.type == 'B'
                                    //             ? Colors.blue.shade700
                                    //             : Colors.orange.shade700,
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),

                                    // รายการ
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: isLargeScreen
                                              ? 300
                                              : (isDesktop ? 220 : 180),
                                        ),
                                        child: Text(
                                          c.name,
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // คำอธิบาย
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: isLargeScreen
                                              ? 350
                                              : (isDesktop ? 250 : 200),
                                        ),
                                        child: Text(
                                          c.description ?? '-',
                                          style: TextStyle(
                                            fontSize: bodyFontSize,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // Stock Level
                                    // DataCell(
                                    //   Text(
                                    //     '${c.stockLevel}',
                                    //     style: TextStyle(
                                    //       fontSize: bodyFontSize,
                                    //       fontWeight: FontWeight.w600,
                                    //     ),
                                    //   ),
                                    // ),

                                    // สถานะ
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.status == '1'
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: c.status == '1'
                                                ? Colors.green.withValues(
                                                    alpha: 0.3,
                                                  )
                                                : Colors.red.withValues(
                                                    alpha: 0.3,
                                                  ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              c.status == '1'
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: smallFontSize,
                                              color: c.status == '1'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              c.statusName,
                                              style: TextStyle(
                                                fontSize: bodyFontSize,
                                                fontWeight: FontWeight.w600,
                                                color: c.status == '1'
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // จัดการ
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: 'แก้ไข',
                                            child: InkWell(
                                              onTap: () => _showAddEditDialog(
                                                facility: c,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
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
                                          ),
                                          const SizedBox(width: 8),
                                          Tooltip(
                                            message: 'ลบ',
                                            child: InkWell(
                                              onTap: () => _deleteFacility(c),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
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
          ),

          // Pagination Bar
          if (_totalPages > 1)
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First page
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () {
                            _currentPage = 0;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.first_page, size: iconSize),
                    tooltip: 'หน้าแรก',
                  ),
                  // Previous
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () {
                            _currentPage--;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.chevron_left, size: iconSize),
                    tooltip: 'ก่อนหน้า',
                  ),

                  // Page numbers
                  ...List.generate(_totalPages.clamp(0, 7), (i) {
                    int pageNum;
                    if (_totalPages <= 7) {
                      pageNum = i;
                    } else if (_currentPage < 4) {
                      pageNum = i;
                    } else if (_currentPage > _totalPages - 4) {
                      pageNum = _totalPages - 7 + i;
                    } else {
                      pageNum = _currentPage - 3 + i;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () {
                          _currentPage = pageNum;
                          _loadData();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: isDesktop ? 44 : 38,
                          height: isDesktop ? 44 : 38,
                          decoration: BoxDecoration(
                            color: _currentPage == pageNum
                                ? AppTheme.primaryColor
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${pageNum + 1}',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: _currentPage == pageNum
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Next
                  IconButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            _currentPage++;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.chevron_right, size: iconSize),
                    tooltip: 'ถัดไป',
                  ),
                  // Last page
                  IconButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            _currentPage = _totalPages - 1;
                            _loadData();
                          }
                        : null,
                    icon: Icon(Icons.last_page, size: iconSize),
                    tooltip: 'หน้าสุดท้าย',
                  ),

                  const SizedBox(width: 16),
                  Text(
                    'หน้า ${_currentPage + 1} จาก $_totalPages',
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.w500,
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
