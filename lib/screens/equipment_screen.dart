import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/equipment.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../widgets/equipment_dialog.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class EquipmentScreen extends StatefulWidget {
  final ApiService apiService;
  const EquipmentScreen({super.key, required this.apiService});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<Equipment> _equipment = [];
  List<Map<String, dynamic>> _booktitles = [];
  List<Roomtype> _roomtypes = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  int? _filterBookingid;
  int? _filterRoomtypeid;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final titles = await widget.apiService.getBooktitles();
      final types = await widget.apiService.getRoomtypeList();
      if (mounted) {
        setState(() {
          _booktitles = titles;
          _roomtypes = types;
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading dropdowns: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getEquipment(
        page: _currentPage,
        size: _pageSize,
        bookingid: _filterBookingid,
        roomtypeid: _filterRoomtypeid,
      );
      if (mounted) {
        final list = result['equipment'] as List?;
        setState(() {
          _equipment = list?.map((j) => Equipment.fromJson(j)).toList() ?? [];
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

  String _getBooktitle(int? id) {
    if (id == null) return '-';
    final b = _booktitles.firstWhere(
      (b) => b['bookID'] == id,
      orElse: () => {'booktitle': 'ไม่พบ'},
    );
    return b['booktitle']?.toString() ?? '-';
  }

  String _getRoomtypeName(int? id) {
    if (id == null) return '-';
    return _roomtypes
        .firstWhere(
          (r) => r.roomtypeID == id,
          orElse: () => Roomtype(name: 'ไม่พบ'),
        )
        .name;
  }

  void _showDialog({Equipment? equipment}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EquipmentDialog(
        equipment: equipment,
        apiService: widget.apiService,
        booktitles: _booktitles,
        roomtypes: _roomtypes,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _delete(Equipment eq) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${eq.booktitle}" ใช่หรือไม่?',
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
    if (confirm == true && eq.equipmentID != null) {
      try {
        await widget.apiService.deleteEquipment(eq.equipmentID!);
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
          'รายการขอใช้โสตฯ',
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
              onPressed: () => _showDialog(),
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
                  // ✅ Use SizedBox with fixed width, or use Expanded in a Row
                  SizedBox(
                    width: isLargeScreen
                        ? 220
                        : (isDesktop ? 180 : 150), // ✅ Reduced widths
                    child: DropdownButtonFormField<int?>(
                      initialValue: _filterBookingid,
                      isExpanded: true, // ✅ Add this
                      style: TextStyle(
                        fontSize: bodyFontSize - 1,
                      ), // ✅ Smaller font
                      decoration: InputDecoration(
                        hintText: 'โครงการ',
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
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bodyFontSize - 1),
                          ),
                        ),
                        ..._booktitles.map(
                          (b) => DropdownMenuItem<int?>(
                            value: b['bookID'] as int?,
                            child: Text(
                              b['booktitle']?.toString() ?? '',
                              style: TextStyle(fontSize: bodyFontSize - 1),
                              overflow: TextOverflow.ellipsis, // ✅ Add ellipsis
                              maxLines: 6,//1
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _filterBookingid = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isLargeScreen ? 180 : (isDesktop ? 150 : 130),
                    child: DropdownButtonFormField<int?>(
                      initialValue: _filterRoomtypeid,
                      isExpanded: true,
                      style: TextStyle(fontSize: bodyFontSize - 1),
                      decoration: InputDecoration(
                        hintText: 'ประเภทห้อง',
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
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bodyFontSize - 1),
                          ),
                        ),
                        ..._roomtypes
                            .where((r) => r.roomtypeID != null)
                            .map(
                              (r) => DropdownMenuItem<int?>(
                                value: r.roomtypeID,
                                child: Text(
                                  r.name,
                                  style: TextStyle(fontSize: bodyFontSize - 1),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                      onChanged: (v) {
                        _filterRoomtypeid = v;
                        _currentPage = 0;
                        _loadData();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isLargeScreen ? 90 : (isDesktop ? 80 : 75),
                    child: DropdownButtonFormField<int>(
                      initialValue: _pageSize,
                      isExpanded: true,
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
                        isDense: true,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _equipment.isEmpty
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
                    padding: EdgeInsets.all(isDesktop ? 16 : 8),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            // ✅ Add minimum width constraint
                            constraints: BoxConstraints(
                              minWidth: isLargeScreen
                                  ? 1200
                                  : (isDesktop ? 1000 : 800),
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppTheme.primaryColor.withValues(alpha: 0.05),
                              ),
                              headingRowHeight: 44,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 48,
                              columnSpacing: isLargeScreen
                                  ? 10
                                  : (isDesktop ? 8 : 4),
                              horizontalMargin: isDesktop ? 10 : 6,
                              columns: [
                                DataColumn(
                                  label: _hdr('ลำดับ', 40, bodyFontSize),
                                ),
                                DataColumn(
                                  label: _hdr(
                                    'กิจกรรม/โครงการ',
                                    200,//150
                                    bodyFontSize,
                                  ),
                                ),
                                DataColumn(
                                  label: _hdr('สถานที่', 70, bodyFontSize),
                                ),
                                DataColumn(
                                  label: _hdr('ประเภทห้อง', 80, bodyFontSize),
                                ),
                                DataColumn(
                                  label: _hdr(
                                    'วันที่เริ่มต้น',
                                    200, //75
                                    bodyFontSize,
                                  ),
                                ),
                                DataColumn(
                                  label: _hdr(
                                    'วันที่สิ้นสุด',
                                    200,
                                    bodyFontSize,
                                  ),
                                ),
                                DataColumn(
                                  label: _hdr('จำนวน', 60, bodyFontSize),
                                ),
                                DataColumn(
                                  label: _hdr('จัดการ', 55, bodyFontSize),
                                ),
                              ],
                              rows: _equipment
                                  .map(
                                    (e) => DataRow(
                                      cells: [
                                        DataCell(
                                          _cell(
                                            '${e.sequence}',
                                            40,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            e.booktitle ??
                                                _getBooktitle(e.bookingid),
                                            200,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            e.place ?? '-',
                                            70,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            e.roomtypeName ??
                                                _getRoomtypeName(e.roomtypeid),
                                            80,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            Util.formatThaiDateStr(e.startdate),
                                            200,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            Util.formatThaiDateStr(e.stopdate),
                                            200,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          _cell(
                                            '${e.numberperson ?? '-'}',
                                            55,
                                            bodyFontSize,
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () =>
                                                    _showDialog(equipment: e),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.edit,
                                                    size: iconSize - 6,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              InkWell(
                                                onTap: () => _delete(e),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.delete,
                                                    size: iconSize - 6,
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
          ),

          if (_totalPages > 1)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              onPressed: () => _showDialog(),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _hdr(String t, double w, double fontSize) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: w),
    child: Text(
      t,
      style: TextStyle(
        fontSize: fontSize - 1,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _cell(String t, double w, double fontSize) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: w),
    child: Text(
      t,
      style: TextStyle(fontSize: fontSize - 1),
      overflow: TextOverflow.ellipsis,
    ),
  );
}
