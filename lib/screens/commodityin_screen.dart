import 'package:flutter/material.dart';
import 'package:highway_training/models/employee.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/utils/util.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/commodity.dart';
import '../models/commodity_in.dart';
import '../services/api_service.dart';
import '../widgets/commodityin_dialog.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class CommodityInScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  const CommodityInScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
  });

  @override
  State<CommodityInScreen> createState() => _CommodityInScreenState();
}

class _CommodityInScreenState extends State<CommodityInScreen> {
  List<CommodityIn> _transactions = [];
  List<Commodity> _commodities = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  int? _filterCommodityID;
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCommodities();
    _loadEmployees();
  }

  Future<void> _loadCommodities() async {
    try {
      final commodities = await widget.apiService.getCommoditiesList();
      if (mounted) setState(() => _commodities = commodities);
    } catch (e) {
      AppLogger.d('Error loading commodities: $e');
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await widget.apiService.getEmployeesList();
      if (mounted) setState(() => _employees = employees);
    } catch (e) {
      AppLogger.d('Error loading commodities: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getCommodityInTransactions(
        page: _currentPage,
        size: _pageSize,
        commodityID: _filterCommodityID,
        type: _filterType,
      );
      if (mounted) {
        final List<dynamic>? list = result['transactions'] as List?;
        setState(() {
          _transactions =
              list?.map((j) => CommodityIn.fromJson(j)).toList() ?? [];
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

  String _getCommodityName(int? id) {
    if (id == null) return '-';
    return _commodities
        .firstWhere(
          (c) => c.commodityId == id,
          orElse: () => Commodity(commodityId: id, name: 'ไม่พบ'),
        )
        .name;
  }

  /* String? _getEmployeeName(int? id) {
    if (id == null) return '-';
    return _employees
        .firstWhere(
          (c) => c.empID == id,
          orElse: () => Employee(empID: id, name: 'ไม่พบ'),
        )
        .name;
  }
*/
  void _showAddEditDialog({CommodityIn? transaction}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CommodityInDialog(
        transaction: transaction,
        apiService: widget.apiService,
        commodities: _commodities,
        employees: _employees,
        authProvider: widget.authProvider,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteTransaction(CommodityIn t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบรายการ ${t.commodityName} นี้ใช่หรือไม่?',
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
    if (confirm == true && t.commodityInTransactionID != null) {
      try {
        await widget.apiService.deleteCommodityIn(t.commodityInTransactionID!);
        if (mounted) {
          context.showSuccessSnackBar('ลบข้อมูลสำเร็จ');
          _loadData();
        }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts);
      String d =
          "${Util.formatThaiDate(dt)} ${DateFormat(' HH:mm').format(dt)}";

      return d; //DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return ts;
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
          'บันทึกรับจ่ายของใช้',
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
            padding: EdgeInsets.all(isDesktop ? 16 : 10),
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
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: isLargeScreen
                        ? 220
                        : (isDesktop ? 180 : 150), // ✅ Reduced width
                    child: DropdownButtonFormField<int?>(
                      initialValue:
                          _filterCommodityID, // ✅ Use value, not initialValue
                      isExpanded: true, // ✅ Add this
                      style: TextStyle(fontSize: bodyFontSize - 1),
                      decoration: InputDecoration(
                        hintText: 'ของใช้',
                        hintStyle: TextStyle(fontSize: bodyFontSize - 1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        isDense: true, // ✅ Add this
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bodyFontSize - 1),
                          ),
                        ),
                        ..._commodities.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.commodityId,
                            child: Text(
                              c.name,
                              style: TextStyle(fontSize: bodyFontSize - 1),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _filterCommodityID = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isLargeScreen
                        ? 130
                        : (isDesktop ? 110 : 100), // ✅ Reduced width
                    child: DropdownButtonFormField<String?>(
                      initialValue: _filterType, // ✅ Use value, not initialValue
                      isExpanded: true, // ✅ Add this
                      style: TextStyle(fontSize: bodyFontSize - 1),
                      decoration: InputDecoration(
                        hintText: 'เบิก/จ่าย',
                        hintStyle: TextStyle(fontSize: bodyFontSize - 1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        isDense: true, // ✅ Add this
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bodyFontSize - 1),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'D',
                          child: Text(
                            'รับ',
                            style: TextStyle(fontSize: bodyFontSize - 1),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'C',
                          child: Text(
                            'จ่าย',
                            style: TextStyle(fontSize: bodyFontSize - 1),
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
                        ? 100
                        : (isDesktop ? 85 : 80), // ✅ Reduced width
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize, // ✅ Use value, not initialValue
                      isExpanded: true, // ✅ Add this
                      style: TextStyle(fontSize: bodyFontSize - 1),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        hintStyle: TextStyle(fontSize: bodyFontSize - 1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        isDense: true, // ✅ Add this
                      ),
                      items: [5, 10, 15, 20]
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s,
                              child: Text(
                                '$s',
                                style: TextStyle(fontSize: bodyFontSize - 1),
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
                : _transactions.isEmpty
                ? Center(
                    child: Text(
                      'ไม่พบข้อมูล',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
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
                                ? 20
                                : (isDesktop ? 16 : 12),
                            columns: [
                              DataColumn(
                                label: Text(
                                  'ID',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ของใช้',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'รับ/จ่าย',
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
                                  'คงเหลือ',
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
                                  'วันที่',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ผู้เบิก',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ใบสั่งซื้อ',
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
                                  'บันทึกเมื่อ',
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
                            rows: _transactions.map((t) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${t.commodityInTransactionID ?? '-'}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      t.commodityName ??
                                          _getCommodityName(t.commodityID),
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.type == 'D'
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.orange.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        t.typeName,
                                        style: TextStyle(
                                          fontSize: smallFontSize,
                                          color: t.type == 'D'
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${t.qty}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${t.balance ?? '-'}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      Util.formatThaiDateStr(t.date), //?? '-'
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      t.employeeName ?? '-',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      t.po ?? '-',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${t.price}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatTimestamp(t.timestamp),
                                      style: TextStyle(fontSize: smallFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _showAddEditDialog(
                                            transaction: t,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              size: iconSize - 2,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => _deleteTransaction(t),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.delete,
                                              size: iconSize - 2,
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
