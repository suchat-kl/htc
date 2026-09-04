import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/facility.dart';
import '../models/roomtype_facility.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class RoomtypeFacilityScreen extends StatefulWidget {
  final int roomTypeID;
  final String roomTypeName;
  final ApiService apiService;

  const RoomtypeFacilityScreen({
    super.key,
    required this.roomTypeID,
    required this.roomTypeName,
    required this.apiService,
  });

  @override
  State<RoomtypeFacilityScreen> createState() =>
      _RoomtypeFacilityScreenState();
}

class _RoomtypeFacilityScreenState extends State<RoomtypeFacilityScreen> {
  List<RoomtypeFacility> _facilities = [];
  // List<Commodity> _commodityList = [];
  List<Facility> _facilityListAdd = [];
  List<Facility> _facilityListEdit = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFacilityList();
  }

  Future<void> _loadFacilityList() async {
    try {
      if (AppLogger.on) AppLogger.d('=== Loading Facility Lists ===');
      if (AppLogger.on) AppLogger.d('roomTypeID: ${widget.roomTypeID}');

      final facilitiesAdd = await widget.apiService.getFacilitiesList(
        roomTypeID: widget.roomTypeID,
        mode: "add",
      );
      if (AppLogger.on) AppLogger.d('facilitiesAdd count: ${facilitiesAdd.length}');
      for (var f in facilitiesAdd) {
        if (AppLogger.on) AppLogger.d('  ADD - facilityID: ${f.facilityID}, name: ${f.name}');
      }

      final facilitiesEdit = await widget.apiService.getFacilitiesList(
        roomTypeID: widget.roomTypeID,
        mode: "edit",
      );
      if (AppLogger.on) AppLogger.d('facilitiesEdit count: ${facilitiesEdit.length}');
      for (var f in facilitiesEdit) {
        if (AppLogger.on) AppLogger.d('  EDIT - facilityID: ${f.facilityID}, name: ${f.name}');
      }

      if (mounted) {
        setState(() {
          _facilityListAdd = facilitiesAdd;
          _facilityListEdit = facilitiesEdit;
        });
        if (AppLogger.on) AppLogger.d('State updated successfully');
      }
      if (AppLogger.on) AppLogger.d('===================================');
    } catch (e) {
      if (AppLogger.on) AppLogger.e('❌ Error loading facility list: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getRoomtypeFacilities(
        widget.roomTypeID,
        page: _currentPage,
        size: _pageSize,
      );
      if (mounted) {
        final List<dynamic>? list = result['facilities'] as List?;
        setState(() {
          _facilities =
              list?.map((j) => RoomtypeFacility.fromJson(j)).toList() ?? [];
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

  String _getFacilityName(int facilityID, String mode) {
    final Facility c;
    if (mode == "edit") {
      c = _facilityListEdit.firstWhere(
        (c) => c.facilityID == facilityID,
        orElse: () => Facility(facilityID: facilityID, name: 'ไม่พบข้อมูล'),
      );
      return c.name;
    }
    return " ";
  }

  void _showAddEditDialog({RoomtypeFacility? facility, String? mode}) {
    if (AppLogger.on) AppLogger.d('=== Opening Dialog ===');
    if (AppLogger.on) AppLogger.d('Mode: $mode');
    if (AppLogger.on) AppLogger.d('RoomTypeID: ${widget.roomTypeID}');
    if (AppLogger.on) {
      AppLogger.d(
        'Facility: ${facility != null ? "Edit facilityID=${facility.facilityID}" : "New"}',
      );
    }

    if (mode == "edit") {
      if (AppLogger.on) {
        AppLogger.d(
          'Using _facilityListEdit (count: ${_facilityListEdit.length})',
        );
      }
      for (var f in _facilityListEdit) {
        if (AppLogger.on) AppLogger.d('  facilityID: ${f.facilityID}, name: ${f.name}');
      }
    } else {
      if (AppLogger.on) AppLogger.d('Using _facilityListAdd (count: ${_facilityListAdd.length})');
      for (var f in _facilityListAdd) {
        if (AppLogger.on) AppLogger.d('  facilityID: ${f.facilityID}, name: ${f.name}');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RoomtypeFacilityFormDialog(
        facility: facility,
        roomTypeID: widget.roomTypeID,
        apiService: widget.apiService,
        facilityList: mode == "edit" ? _facilityListEdit : _facilityListAdd,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteFacility(RoomtypeFacility facility) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${_getFacilityName(facility.facilityID, "edit")}" ใช่หรือไม่?',
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
        await widget.apiService.deleteRoomtypeFacility(
          widget.roomTypeID,
          facility.facilityID,
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
          'สิ่งอำนวยความสะดวก - ${widget.roomTypeName}',
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
                : _facilities.isEmpty
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
                                  'สิ่งอำนวยความสะดวก',
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
                            rows: _facilities.map((c) {
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
                                      c.facilityName ??
                                          'Facility #${c.facilityID}',
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
                                              facility: c,
                                              mode: "edit",
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
                                            onTap: () => _deleteFacility(c),
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
class _RoomtypeFacilityFormDialog extends StatefulWidget {
  final RoomtypeFacility? facility;
  final int roomTypeID;
  final ApiService apiService;
  final List<Facility> facilityList;

  const _RoomtypeFacilityFormDialog({
    this.facility,
    required this.roomTypeID,
    required this.apiService,
    required this.facilityList,
  });

  @override
  State<_RoomtypeFacilityFormDialog> createState() =>
      _RoomtypeFacilityFormDialogState();
}

class _RoomtypeFacilityFormDialogState
    extends State<_RoomtypeFacilityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sequenceController = TextEditingController();
  final _quantityController = TextEditingController();

  int? _selectedFacilityID;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEdit => widget.facility != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _selectedFacilityID = widget.facility!.facilityID;
      _sequenceController.text = widget.facility!.sequence.toString();
      _quantityController.text = widget.facility!.quantity.toString();
    } else if (widget.facilityList.isNotEmpty) {
      _selectedFacilityID = widget.facilityList.first.facilityID;
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
    if (_selectedFacilityID == null) {
      setState(() => _errorMessage = 'กรุณาเลือกสิ่งอำนวยความสะดวก');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rc = RoomtypeFacility(
        roomTypeID: widget.roomTypeID,
        facilityID: _selectedFacilityID!,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        quantity: double.tryParse(_quantityController.text) ?? 0.0,
      );

      if (isEdit) {
        await widget.apiService.updateRoomtypeFacility(
          widget.roomTypeID,
          widget.facility!.facilityID,
          rc,
        );
      } else {
        //add
        await widget.apiService.createRoomtypeFacility(rc);
        widget.facilityList.removeWhere(
          (item) => item.facilityID == rc.facilityID,
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

    // ✅ Filter unique facilities
    final uniqueMap = <int, Facility>{};
    for (var c in widget.facilityList) {
      if (c.facilityID != null) {
        uniqueMap.putIfAbsent(c.facilityID!, () => c);
      }
    }
    final uniqueList = uniqueMap.values.toList();
    // ✅ DEBUG PRINTS
    if (AppLogger.on) AppLogger.d('=== Facility Dropdown Debug ===');
    if (AppLogger.on) AppLogger.d('Mode: ${isEdit ? "EDIT" : "ADD"}');
    if (AppLogger.on) AppLogger.d('widget.facilityList length: ${widget.facilityList.length}');
    if (AppLogger.on) AppLogger.d('uniqueList length: ${uniqueList.length}');
    if (AppLogger.on) AppLogger.d('_selectedFacilityID: $_selectedFacilityID');
    if (AppLogger.on) AppLogger.d('FacilityList items:');
    for (var f in widget.facilityList) {
      if (AppLogger.on) AppLogger.d('  facilityID: ${f.facilityID}, name: ${f.name}');
    }
    if (AppLogger.on) AppLogger.d('UniqueList items:');
    for (var f in uniqueList) {
      if (AppLogger.on) AppLogger.d('  facilityID: ${f.facilityID}, name: ${f.name}');
    }
    if (AppLogger.on) AppLogger.d('===================================');

    // ✅ Validate selected value exists in the list
    if (_selectedFacilityID != null && uniqueList.isNotEmpty) {
      final exists = uniqueList.any((c) => c.facilityID == _selectedFacilityID);
      if (!exists) {
        // Reset to first item if not found
        if (AppLogger.on) AppLogger.w('⚠️ Selected value not found! Resetting to first item...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedFacilityID = uniqueList.first.facilityID;
              if (AppLogger.on) AppLogger.d('Reset _selectedFacilityID to: $_selectedFacilityID');
            });
          }
        });
      }
    } else if (uniqueList.isNotEmpty && _selectedFacilityID == null) {
      _selectedFacilityID = uniqueList.first.facilityID;
       if (AppLogger.on) AppLogger.d('Set default _selectedFacilityID to: $_selectedFacilityID');
    }
    else if (uniqueList.isEmpty) {
      if (AppLogger.on) AppLogger.w('⚠️ uniqueList is EMPTY!');
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
                              ? 'แก้ไขสิ่งอำนวยความสะดวก'
                              : 'เพิ่มสิ่งอำนวยความสะดวก',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Room Type Facility',
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
                        'สิ่งอำนวยความสะดวก',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ✅ Fixed: Use value instead of initialValue
                      DropdownButtonFormField<int>(
                        initialValue: _selectedFacilityID, // ✅ value, not initialValue
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
                                value: c.facilityID,
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
                            : (v) => setState(() => _selectedFacilityID = v),
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
