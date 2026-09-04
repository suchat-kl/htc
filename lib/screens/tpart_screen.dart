import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/tpart.dart';
import '../models/part.dart';
import '../models/employee.dart';
import '../models/maintenance.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/tpart_dialog.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class TpartScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  const TpartScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
  });

  @override
  State<TpartScreen> createState() => _TpartScreenState();
}

class _TpartScreenState extends State<TpartScreen> {
  List<Tpart> _list = [];
  List<Part> _parts = [];
  List<Employee> _employees = [];
  List<Maintenance> _maintenances = [];
  bool _isLoading = true;
  int _cp = 0, _tp = 0, _ps = 5;
  int? _fPartid;
  String? _fType;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final parts = await widget.apiService.getPartsList();
      final emps = await widget.apiService.getEmployeesList();
      final mts = await widget.apiService.getMaintenanceList();
      if (mounted) {
        setState(() {
          _parts = parts;
          _employees = emps;
          _maintenances = mts;
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading dropdowns: $e');
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r = await widget.apiService.getTparts(
        page: _cp,
        size: _ps,
        partid: _fPartid,
        type: _fType,
      );
      if (mounted) {
        final l = r['transactions'] as List?;
        setState(() {
          _list = l?.map((j) => Tpart.fromJson(j)).toList() ?? [];
          _tp = r['totalPages'] as int? ?? 0;
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

  String _partName(int? id) => id == null
      ? '-'
      : _parts
                .firstWhere(
                  (p) => p.partID == id,
                  orElse: () => Part(partID: id, name: 'ไม่พบ'),
                )
                .name ??
            '-';
  String _empName(int? id) => id == null
      ? '-'
      : _employees
                .firstWhere(
                  (e) => e.empID == id,
                  orElse: () => Employee(empID: id, name: 'ไม่พบ'),
                )
                .name ??
            '-';
  // ignore: unused_element
  String _mtInfo(int? id) => id == null
      ? '-'
      : _maintenances
                .firstWhere(
                  (m) => m.maintenanceID == id,
                  orElse: () => Maintenance(maintenanceID: id, place: ''),
                )
                .maintenanceInfo;

  // ❌ Wrong
// void _dialog({Tpart? t, required Tpart transaction}) {

// ✅ Fix - remove required and make t optional
void dialog({Tpart? transaction}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => TpartDialog(
        transaction: transaction,  // Can be null for new, Tpart for edit
        apiService: widget.apiService,
        parts: _parts,
        employees: _employees,
        maintenances: _maintenances,
        authProvider: widget.authProvider,
        
      ),
    ).then((_) => _load());
  }

  Future<void> _del(Tpart t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ ${t.partName} รายการนี้?',
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
    if (ok == true && t.tpartID != null) {
      try {
        await widget.apiService.deleteTpart(t.tpartID!);
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
          'บันทึกรับจ่ายวัสดุซ่อมบำรุง',
          style: TextStyle(fontSize: hf, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => dialog(),
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
                    width: isL ? 250 : (isD ? 200 : double.infinity),//200  170
                    child: DropdownButtonFormField<int?>(
                      initialValue: _fPartid,
                      isExpanded: true,
                      
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'รายการ',
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
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bf - 1),
                          ),
                        ),
                        ..._parts.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.partID,
                            child: Text(
                              p.name ?? '',
                              style: TextStyle(fontSize: bf - 1),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 6,
                              
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _fPartid = v;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isL ? 120 : (isD ? 100 : 90),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _fType,
                      isExpanded: true,
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'เบิก/จ่าย',
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
                        const DropdownMenuItem(value: 'D', child: Text('รับ')),
                        const DropdownMenuItem(value: 'C', child: Text('จ่าย')),
                      ],
                      onChanged: (v) {
                        _fType = v;
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
                    padding: EdgeInsets.all(isD ? 14 : 6),
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
                            headingRowHeight: 44,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            columnSpacing: isL ? 10 : (isD ? 8 : 4),
                            columns: [
                              // DataColumn(label: _hdr('ID', 35, bf)),
                              DataColumn(label: _hdr('รายการ', 150, bf)),//100
                              DataColumn(label: _hdr('รับ/จ่าย', 50, bf)),
                              DataColumn(label: _hdr('จำนวน', 50, bf)),
                              DataColumn(label: _hdr('คงเหลือ', 50, bf)),
                              DataColumn(label: _hdr('วันที่', 100, bf)),//70
                              DataColumn(label: _hdr('พื้นที่', 130, bf)),//60
                              DataColumn(label: _hdr('ผู้เบิก', 120, bf)),//70
                              DataColumn(label: _hdr('PO', 100, bf)),//60
                              DataColumn(label: _hdr('ราคา', 50, bf)),
                              DataColumn(label: _hdr('ใบแจ้งซ่อม', 90, bf)),
                              // DataColumn(label: _hdr('บันทึกเมื่อ', 70, bf)),
                              DataColumn(label: _hdr('จัดการ', 60, bf)),
                            ],

                            rows: _list
                                .map(
                                  (t) => DataRow(
                                    cells: [
                                      // DataCell(_cell('${t.tpartID}', 35, bf)),
                                      DataCell(
                                        _cellWrap(
                                          t.partName ?? _partName(t.partid),
                                          150,
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
                                            color: t.type == 'D'
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.orange.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            t.typeName,
                                            style: TextStyle(
                                              fontSize: bf - 3,
                                              fontWeight: FontWeight.w600,
                                              color: t.type == 'D'
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(_cell('${t.qty ?? ''}', 50, bf)),
                                      DataCell(
                                        _cell('${t.balance ?? ''}', 50, bf),
                                      ),
                                      DataCell(
                                        _cellWrap(
                                          Util.formatThaiDateStr(t.date),
                                          100,
                                          bf,
                                        ),
                                      ),
                                      DataCell(_cellWrap(t.place ?? '-', 130, bf)),
                                      DataCell(
                                        _cellWrap(
                                          t.employeeName ??
                                              _empName(t.employeeid),
                                          120,
                                          bf,
                                        ),
                                      ),
                                      DataCell(_cellWrap(t.po ?? '-', 100, bf)),
                                      DataCell(
                                        _cell('${t.price ?? ''}', 50, bf),
                                      ),
                                      DataCell(
                                        _cell(
                                          // t.maintenanceInfo ??
                                          //     _mtInfo(t.maintenanceid),
                                          t.maintenanceid.toString(),
                                          90,
                                          bf,
                                        ),
                                      ),
                                      // DataCell(
                                      //   _cell(
                                      //     Util.formatThaiDateStr(t.timestamp),
                                      //     70,
                                      //     bf,
                                      //   ),
                                      // ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  dialog(transaction: t),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                              onTap: () => _del(t),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                .toList(), // ✅ .toList() here!
                          
                        ),
                      ),
                    ),
                  ),
          ),
          ),
          if (_tp > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    onPressed: _cp > 0
                        ? () {
                            _cp = 0;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.first_page, size: ic),
                  ),
                  IconButton(
                    onPressed: _cp > 0
                        ? () {
                            _cp--;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.chevron_left, size: ic),
                  ),
                  Text(
                    'หน้า ${_cp + 1} จาก $_tp',
                    style: TextStyle(fontSize: bf),
                  ),
                  IconButton(
                    onPressed: _cp < _tp - 1
                        ? () {
                            _cp++;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.chevron_right, size: ic),
                  ),
                  IconButton(
                    onPressed: _cp < _tp - 1
                        ? () {
                            _cp = _tp - 1;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.last_page, size: ic),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
 // ✅ For columns that need wrapping (like รายการ, ใบแจ้งซ่อม)
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

  // ✅ For columns that should stay single line (like ID, จำนวน)
  Widget _cell(String t, double w, double fs) => SizedBox(
    width: w,
    child: Text(
      t,
      style: TextStyle(fontSize: fs - 1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
