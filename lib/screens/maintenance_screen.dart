import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/maintenance.dart';
// import '../models/room.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../screens/maintenance_edit_screen.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class MaintenanceScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  const MaintenanceScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<Maintenance> _list = [];
  bool _isLoading = true;
  // ignore: unused_field
  int _cp = 0, _tp = 0, _ps = 5;
  String? _fReportname, _fWorkstatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r = await widget.apiService.getMaintenance(
        page: _cp,
        size: _ps,
        reportname: _fReportname,
        workstatus: _fWorkstatus,
      );

      if (AppLogger.on) AppLogger.d('Maintenance response keys: ${r.keys}'); // ✅ Debug

      if (mounted) {
        // ✅ Try both possible keys
        final l = (r['maintenance'] ?? r['maintenances']) as List?;

        if (AppLogger.on) AppLogger.d('Maintenance list length: ${l?.length}'); // ✅ Debug

        setState(() {
          _list =
              l?.map((j) {
                if (AppLogger.on) AppLogger.d('Parsing: $j'); // ✅ Debug each item
                return Maintenance.fromJson(j as Map<String, dynamic>);
              }).toList() ??
              [];
          // _tp = r['totalPages'] as int? ?? 0;
          _tp =
              r['totalPages'] as int? ?? 0; // ✅ Must be > 1 to show pagination
          _isLoading = false;
        });
// ✅ Debug
        if (AppLogger.on) AppLogger.d('Total pages: $_tp');
        if (AppLogger.on) AppLogger.d('Current page: $_cp');
        if (AppLogger.on) AppLogger.d('Page size: $_ps');
        if (AppLogger.on) AppLogger.d('List length: ${_list.length}');
        if (AppLogger.on) AppLogger.d('Parsed ${_list.length} items'); // ✅ Debug
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading maintenance: $e'); // ✅ Debug error
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้: $e');
      }
    }
  }

  void _edit(Maintenance m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceEditScreen(
          apiService: widget.apiService,
          authProvider: widget.authProvider,
          maintenance: m,
        ),
      ),
    ).then((_) => _load());
  }

  void _add() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceEditScreen(
          apiService: widget.apiService,
          authProvider: widget.authProvider,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _del(Maintenance m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบใบแจ้งซ่อม ID:${m.maintenanceID}?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && m.maintenanceID != null) {
      try {
        await widget.apiService.deleteMaintenance(m.maintenanceID!);
        if (mounted) {
          context.showSuccessSnackBar('ลบสำเร็จ');
          _load();
        }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isD = sw > 1024;
    final isL = sw > 1400;
    final hf = isL ? 22.0 : (isD ? 20.0 : 18.0);
    final bf = isL ? 16.0 : (isD ? 15.0 : 14.0);
    final ic = isL ? 22.0 : (isD ? 20.0 : 18.0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'แจ้งซ่อม',
          style: TextStyle(fontSize: hf, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _add,
              icon: Icon(Icons.add, size: ic),
              label: Text('เพิ่มรายการ', style: TextStyle(fontSize: bf)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isD ? 20 : 14,
                  vertical: isD ? 14 : 10,
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
            padding: EdgeInsets.all(isD ? 14 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: isL ? 200 : (isD ? 170 : double.infinity),
                    child: TextField(
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาผู้แจ้ง...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (v) {
                        _fReportname = v;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isL ? 140 : (isD ? 120 : 110),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _fWorkstatus,
                      isExpanded: true,
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'สถานะ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bf - 1),
                          ),
                        ),
                        ...['0', '1', '2', '3', '4', '5'].map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(
                              [
                                'ยังไม่มีผู้รับงาน',
                                'รับงาน',
                                'รออุปกรณ์หรือจ้างซ่อม',
                                'ปิดงาน',
                                'ยกเลิกงาน',
                                'ไม่ระบุ',
                              ][int.parse(s)],
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _fWorkstatus = v;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isL ? 90 : (isD ? 80 : 70),
                    child: DropdownButtonFormField<int>(
                      initialValue: _ps,
                      isExpanded: true,
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      items: [5, 10, 15, 20]
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s,
                              child: Text(
                                '$s',
                                style: TextStyle(fontSize: bf - 1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        _ps = v!;
                        _cp = 0;
                        _load();
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
                : _list.isEmpty
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
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.primaryColor.withValues(alpha: 0.05),
                      ),
                      headingRowHeight: 44,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 48,
                      columnSpacing: isL ? 10 : (isD ? 8 : 4),
                      columns: [
                        DataColumn(label: _hdr('ID', 50, bf)),
                        DataColumn(label: _hdr('ห้อง', 50, bf)),
                        DataColumn(label: _hdr('สถานที่', 130, bf)),
                        DataColumn(label: _hdr('รายละเอียด', 150, bf)),
                        DataColumn(label: _hdr('วันที่แจ้ง', 100, bf)),
                        DataColumn(label: _hdr('วันที่รับงาน', 100, bf)),
                        DataColumn(label: _hdr('วันที่ปิดงาน', 100, bf)),
                        DataColumn(label: _hdr('สถานะ', 80, bf)),
                        DataColumn(label: _hdr('จัดการ', 55, bf)),
                      ],
                      rows: _list
                          .map(
                            (m) => DataRow(
                              cells: [
                                DataCell(_cell('${m.maintenanceID}', 50, bf)),
                                DataCell(
                                  _cell(m.roomid?.toString() ?? '-', 50, bf),
                                ),
                                DataCell(_cellWrap(m.place ?? '-', 130, bf)),
                                DataCell(
                                  _cellWrap(m.reportremark ?? '-', 150, bf),
                                ),
                                DataCell(
                                  _cellWrap(
                                    Util.formatThaiDateStr(
                                      m.reportdate?.toString(),
                                    ),
                                    100,
                                    bf,
                                  ),
                                ),
                                DataCell(
                                  _cellWrap(
                                    Util.formatThaiDateStr(
                                      m.startdate?.toString(),
                                    ),
                                    100,
                                    bf,
                                  ),
                                ),
                                DataCell(
                                  _cellWrap(
                                    Util.formatThaiDateStr(
                                      m.stopdate?.toString(),
                                    ),
                                    100,
                                    bf,
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(m.workstatus),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      m.workstatusName,
                                      style: TextStyle(
                                        fontSize: bf - 4,
                                        fontWeight: FontWeight.w600,
                                        color: _statusTextColor(m.workstatus),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _edit(m),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            size: ic - 6,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      InkWell(
                                        onTap: () => _del(m),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            size: ic - 6,
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
                          .toList(), // ✅ .toList() is HERE, closing the .map()
                    ),
                  ),
          ),
// ✅ Pagination - OUTSIDE Expanded, inside Column
    if (_tp > 1)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _cp > 0 ? () { _cp = 0; _load(); } : null,
              icon: Icon(Icons.first_page, size: ic),
            ),
            IconButton(
              onPressed: _cp > 0 ? () { _cp--; _load(); } : null,
              icon: Icon(Icons.chevron_left, size: ic),
            ),
            ...List.generate(_tp.clamp(0, 5), (i) {
              int p = _tp <= 5 ? i : (_cp < 3 ? i : (_cp > _tp - 3 ? _tp - 5 + i : _cp - 2 + i));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () { _cp = p; _load(); },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _cp == p ? AppTheme.primaryColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${p + 1}', style: TextStyle(fontSize: bf, fontWeight: FontWeight.bold, color: _cp == p ? Colors.white : AppTheme.textPrimary)),
                    ),
                  ),
                ),
              );
            }),
            IconButton(
              onPressed: _cp < _tp - 1 ? () { _cp++; _load(); } : null,
              icon: Icon(Icons.chevron_right, size: ic),
            ),
            IconButton(
              onPressed: _cp < _tp - 1 ? () { _cp = _tp - 1; _load(); } : null,
              icon: Icon(Icons.last_page, size: ic),
            ),
            const SizedBox(width: 12),
            Text('หน้า ${_cp + 1} จาก $_tp', style: TextStyle(fontSize: bf, color: Colors.grey.shade600)),
          ],
        ),
      ),
  ],  // ✅ Closes Column children
),  // ✅ Closes Column


      
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case '0':
        return Colors.grey.withValues(alpha: 0.1);
      case '1':
        return Colors.blue.withValues(alpha: 0.1);
      case '2':
        return Colors.orange.withValues(alpha: 0.1);
      case '3':
        return Colors.green.withValues(alpha: 0.1);
      case '4':
        return Colors.red.withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color _statusTextColor(String? s) {
    switch (s) {
      case '0':
        return Colors.grey;
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.green;
      case '4':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _hdr(String t, double w, double fs) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: w),
    child: Text(
      t,
      style: TextStyle(
        fontSize: fs - 1,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
  Widget _cell(String t, double w, double fs) => SizedBox(
    width: w,
    child: Text(
      t,
      style: TextStyle(fontSize: fs - 1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
  Widget _cellWrap(String t, double w, double fs) => Container(
    width: w,
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      t,
      style: TextStyle(fontSize: fs - 1, height: 1.2),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
    ),
  );
}
