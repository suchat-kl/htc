import 'package:flutter/material.dart';
import 'package:highway_training/screens/roomtype_commodity_screen.dart';
import 'package:highway_training/screens/roomtype_facility_screen.dart';
import '../config/theme.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../widgets/roomtype_dialog.dart';
import '../utils/snackbar_helper.dart';
import 'package:intl/intl.dart';
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
  // Future<void> _loadCommodityList() async {
  //   try {
  //    final  commodities = await widget.apiService.getCommoditiesList();
  //     if (mounted) setState(() => _commodityList = commodities);
  //   } catch (e) {
  //     debugPrint('Error loading commodity list: $e');
  //   }
  // }

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
  // ✅ Get type name from hardcoded list
  String _getTypeName(String? code) {
    if (code == null) return '-';
    final type = _types.firstWhere(
      (t) => t['code'] == code,
      orElse: () => {'name': code},
    );
    return type['name'] ?? code;
  }

  // ✅ Get status name from hardcoded list
  String _getStatusName(String? code) {
    if (code == null) return '-';
    final status = _statuses.firstWhere(
      (s) => s['code'] == code,
      orElse: () => {'name': code},
    );
    return status['name'] ?? code;
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
          onPressed: () => Navigator.of(context).pop(),
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
                  SizedBox(
                    width: isLargeScreen
                        ? 180
                        : (isDesktop ? 160 : (screenWidth - 56) / 2 - 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterType,
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
                        ..._types.map(
                          (t) => DropdownMenuItem<String>(
                            value: t['code'],
                            child: Text(
                              t['name'] ?? '',
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
                  SizedBox(
                    width: isLargeScreen
                        ? 160
                        : (isDesktop ? 140 : (screenWidth - 56) / 2 - 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterStatus,
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
                        ..._statuses.map(
                          (s) => DropdownMenuItem<String>(
                            value: s['code'],
                            child: Text(
                              s['name'] ?? '',
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
                  SizedBox(
                    width: isLargeScreen ? 130 : (isDesktop ? 120 : 100),
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize,
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
                          vertical: isDesktop ? 14 : 10,
                        ),
                      ),
                      items: [5, 10, 20, 50]
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
                : _roomtypes.isEmpty
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
                                ? 28
                                : (isDesktop ? 22 : 14),
                            horizontalMargin: isDesktop ? 24 : 16,
                            // COLUMNS (8 columns total - removed separate icon columns, combined into จัดการ)
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
                              DataColumn(
                                label: Text(
                                  'ราคา',
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
                                  'หมายเหตุ',
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

                            // ROWS (8 cells per row)
                            rows: _roomtypes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final r = entry.value;
                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (states) =>
                                      states.contains(WidgetState.hovered)
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.05,
                                        )
                                      : (index % 2 == 0
                                            ? Colors.white
                                            : Colors.grey.shade50),
                                ),
                                cells: [
                                  // 1. ลำดับ
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${r.sequence}',
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  // 2. ประเภท
                                  DataCell(
                                    Text(
                                      _getTypeName(r.type),
                                      style: TextStyle(
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // 3. รายการ
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isLargeScreen ? 250 : 200,
                                      ),
                                      child: Text(
                                        r.name,
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 4. คำอธิบาย
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isLargeScreen ? 300 : 220,
                                      ),
                                      child: Text(
                                        r.description ?? '-',
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 5. ราคา
                                  DataCell(
                                    Text(
                                      r.price != null
                                          ? NumberFormat(
                                              '#,###.00',
                                            ).format(r.price)
                                          : '-',
                                      style: TextStyle(
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // 6. หมายเหตุ
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isLargeScreen ? 200 : 150,
                                      ),
                                      child: Text(
                                        r.remark ?? '-',
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 7. สถานะ
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: r.status == '1'
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: r.status == '1'
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
                                            r.status == '1'
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            size: smallFontSize,
                                            color: r.status == '1'
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getStatusName(r.status),
                                            style: TextStyle(
                                              fontSize: bodyFontSize,
                                              fontWeight: FontWeight.w600,
                                              color: r.status == '1'
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 8. จัดการ (ALL buttons combined)
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: 'แก้ไข',
                                          child: InkWell(
                                            onTap: () =>
                                                _showAddEditDialog(roomtype: r),
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
                                        ),
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'ลบ',
                                          child: InkWell(
                                            onTap: () => _deleteRoomtype(r),
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
                                        ),
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'เครื่องนอน/ของใช้',
                                          child: InkWell(
                                            onTap: () =>
                                                _showCommodityDialog(r),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.inventory,
                                                size: iconSize,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'สิ่งอำนวยความสะดวก',
                                          child: InkWell(
                                            onTap: () => _showFacilityDialog(r),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.star,
                                                size: iconSize,
                                                color: Colors.green,
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
          // Pagination
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
                    int pageNum = _totalPages <= 5
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
