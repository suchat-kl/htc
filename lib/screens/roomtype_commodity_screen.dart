import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/commodity.dart';
import '../models/roomtype_commodity.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class RoomtypeCommodityScreen extends StatefulWidget {
  final int roomTypeID;
  final String roomTypeName;
  final ApiService apiService;

  const RoomtypeCommodityScreen({
    super.key,
    required this.roomTypeID,
    required this.roomTypeName,
    required this.apiService,
  });

  @override
  State<RoomtypeCommodityScreen> createState() =>
      _RoomtypeCommodityScreenState();
}

class _RoomtypeCommodityScreenState extends State<RoomtypeCommodityScreen> {
  List<RoomtypeCommodity> _commodities = [];
  // List<Commodity> _commodityList = [];
  List<Commodity> _commodityListAdd = [];
  List<Commodity> _commodityListEdit = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCommodityList();
  }

  Future<void> _loadCommodityList() async {
    try {
      // final commodities = await widget.apiService.getCommoditiesList();
      final commoditiesAdd = await widget.apiService.getCommoditiesList(
        roomTypeID: widget.roomTypeID,
        mode: "add"
      );
      final commoditiesEdit = await widget.apiService.getCommoditiesList(
        roomTypeID: widget.roomTypeID,
        mode: "edit",
      );
      if (mounted) {
        // ✅ Filter out duplicates and null IDs
        // final uniqueMap = <int, Commodity>{};
        // for (var c in commodities) {
        //   if (c.commodityId != null) {
        //     uniqueMap.putIfAbsent(c.commodityId!, () => c);
        //   }
        // }
        setState(() { 
          // _commodityList = uniqueMap.values.toList()
          _commodityListAdd = commoditiesAdd;
          _commodityListEdit = commoditiesEdit;
          
          });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading commodity list: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getRoomtypeCommodities(
        widget.roomTypeID,
        page: _currentPage,
        size: _pageSize,
      );
      if (mounted) {
        final List<dynamic>? list = result['commodities'] as List?;
        setState(() {
          _commodities =
              list?.map((j) => RoomtypeCommodity.fromJson(j)).toList() ?? [];
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

  String _getCommodityName(int commodityID,String mode) {
    final Commodity c ;
    if (mode=="edit") {
    c= _commodityListEdit.firstWhere(
      (c) => c.commodityId == commodityID,
      orElse: () => Commodity(commodityId: commodityID, name: 'ไม่พบข้อมูล'),
    );
    return c.name;
    }
    return " ";
  }

  void _showAddEditDialog({RoomtypeCommodity? commodity,String? mode}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RoomtypeCommodityFormDialog(
        commodity: commodity,
        roomTypeID: widget.roomTypeID,
        apiService: widget.apiService,
        commodityList: mode=="edit"?_commodityListEdit:_commodityListAdd,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteCommodity(RoomtypeCommodity commodity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${_getCommodityName(commodity.commodityID,"edit")}" ใช่หรือไม่?',
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
        await widget.apiService.deleteRoomtypeCommodity(
          widget.roomTypeID,
          commodity.commodityID,
        );
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
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'กลับ',
        ),
        title: Text(
          'เครื่องนอน/ของใช้ - ${widget.roomTypeName}',
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
              onPressed: () => _showAddEditDialog(mode: "add"),
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
          // Page size selector
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 12,
              vertical: 8,
            ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('แสดง', style: TextStyle(fontSize: bodyFontSize)),
                const SizedBox(width: 8),
                SizedBox(
                  width: isDesktop ? 120 : 100,
                  child: DropdownButtonFormField<int>(
                    initialValue: _pageSize,
                    style: TextStyle(fontSize: bodyFontSize),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
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
          // Table - FIXED
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
                : _commodities.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
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
                            onPressed: () => _showAddEditDialog(mode: "add"),
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มรายการ'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
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
                            headingRowHeight: isDesktop ? 60 : 50,
                            // ✅ FIX: min must be <= max
                            dataRowMinHeight: isDesktop
                                ? 48
                                : 44, // min = 48 on desktop
                            dataRowMaxHeight: isDesktop
                                ? 72
                                : 60, // max = 72 on desktop (must be >= min)
                            columnSpacing: isLargeScreen
                                ? 28
                                : (isDesktop ? 22 : 16),
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
                              ),
                              DataColumn(
                                label: Text(
                                  'เครื่องนอน/ของใช้',
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
                                  'จัดการ',
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                            rows: _commodities.map((c) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${c.sequence}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      c.commodityName ??
                                          'Commodity #${c.commodityID}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${c.quantity}',
                                      style: TextStyle(fontSize: bodyFontSize),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: 'แก้ไข',
                                          child: InkWell(
                                            onTap: () => _showAddEditDialog(
                                              commodity: c,mode: "edit"
                                            ),
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
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'ลบ',
                                          child: InkWell(
                                            onTap: () => _deleteCommodity(c),
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
              onPressed: () => _showAddEditDialog(mode: "add"),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            ),
    );
  }
}

// ============ FORM DIALOG (Add/Edit) ============
class _RoomtypeCommodityFormDialog extends StatefulWidget {
  final RoomtypeCommodity? commodity;
  final int roomTypeID;
  final ApiService apiService;
  final List<Commodity> commodityList;

  const _RoomtypeCommodityFormDialog({
    this.commodity,
    required this.roomTypeID,
    required this.apiService,
    required this.commodityList,
  });

  @override
  State<_RoomtypeCommodityFormDialog> createState() =>
      _RoomtypeCommodityFormDialogState();
}

class _RoomtypeCommodityFormDialogState
    extends State<_RoomtypeCommodityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sequenceController = TextEditingController();
  final _quantityController = TextEditingController();

  int? _selectedCommodityID;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEdit => widget.commodity != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _selectedCommodityID = widget.commodity!.commodityID;
      _sequenceController.text = widget.commodity!.sequence.toString();
      _quantityController.text = widget.commodity!.quantity.toString();
    } else if (widget.commodityList.isNotEmpty) {
      _selectedCommodityID = widget.commodityList.first.commodityId;
    }
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommodityID == null) {
      setState(() => _errorMessage = 'กรุณาเลือกเครื่องนอน/ของใช้');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rc = RoomtypeCommodity(
        roomTypeID: widget.roomTypeID,
        commodityID: _selectedCommodityID!,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        quantity: double.tryParse(_quantityController.text) ?? 0.0,
      );

      if (isEdit) {
        await widget.apiService.updateRoomtypeCommodity(
          widget.roomTypeID,
          widget.commodity!.commodityID,
          rc,
        );
      } else {
        //add
        await widget.apiService.createRoomtypeCommodity(rc);
        widget.commodityList.removeWhere(
          (item) => item.commodityId == rc.commodityID,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccessSnackBar(
          isEdit ? 'อัปเดตข้อมูลสำเร็จ' : 'บันทึกข้อมูลสำเร็จ',
        );
        
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
// Delete by commodityID
  // void deleteCommodityById(int commodityID) {
  //   widget.commodityList.removeWhere((item) => item.commodityId == commodityID);
  // }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 768;

    // ✅ Filter unique commodities
    final uniqueMap = <int, Commodity>{};
    for (var c in widget.commodityList) {
      if (c.commodityId != null) {
        uniqueMap.putIfAbsent(c.commodityId!, () => c);
      }
    }
    final uniqueList = uniqueMap.values.toList();

    // ✅ Validate selected value exists
    if (_selectedCommodityID != null && uniqueList.isNotEmpty) {
      final exists = uniqueList.any(
        (c) => c.commodityId == _selectedCommodityID,
      );
      if (!exists) {
        // Use post-frame callback to avoid build errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedCommodityID = uniqueList.first.commodityId;
            });
          }
        });
      }
    } else if (uniqueList.isNotEmpty && _selectedCommodityID == null) {
      _selectedCommodityID = uniqueList.first.commodityId;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 550 : screenWidth * 0.95,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.65,
        ),
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
                    width: isDesktop ? 45 : 38,
                    height: isDesktop ? 45 : 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEdit
                              ? 'แก้ไขเครื่องนอน/ของใช้'
                              : 'เพิ่มเครื่องนอน/ของใช้',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Room Type Commodity',
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _errorMessage = null),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'เครื่องนอน/ของใช้',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ✅ Use unique list
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCommodityID,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: uniqueList
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.commodityId,
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14 : 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isEdit
                            ? null
                            : (v) => setState(() => _selectedCommodityID = v),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ลำดับ',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sequenceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'กรอกลำดับ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        style: TextStyle(fontSize: isDesktop ? 16 : 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'จำนวน',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'กรอกจำนวน',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        style: TextStyle(fontSize: isDesktop ? 16 : 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 14 : 12,
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
                                padding: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 14 : 12,
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
                      SizedBox(height: isDesktop ? 0 : 20),
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
}
