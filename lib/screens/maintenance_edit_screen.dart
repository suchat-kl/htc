import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/maintenance.dart';
import '../models/employee.dart';
import '../models/room.dart';
import '../models/tpart.dart';
import '../models/part.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/tpart_dialog.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class MaintenanceEditScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  final Maintenance? maintenance;
  const MaintenanceEditScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
    this.maintenance,
  });

  @override
  State<MaintenanceEditScreen> createState() => _MaintenanceEditScreenState();
}

class _MaintenanceEditScreenState extends State<MaintenanceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  // Column 1 controllers
  final _reportnameCtrl = TextEditingController(),
      _placeCtrl = TextEditingController(),
      _positionCtrl = TextEditingController(),
      _reporttelCtrl = TextEditingController(),
      _reportremarkCtrl = TextEditingController();
  // Column 2 controllers
  final _workdetailCtrl = TextEditingController(),
      _priceCtrl = TextEditingController(),
      _workremarkCtrl = TextEditingController();

  int? _selectedEmp1, _selectedEmp2, _selectedRoomid;
  // ค่าตั้งต้นเป็นอาคารพัก ตามลำดับตัวเลือกที่ผู้ใช้กำหนด (พัก, เรียน, อำนวยการ)
  String _placetype = RoomBuilding.lodging.placetype,
      _workstatus = '0',
      _worktype = 'E',
      _resolutiontype = 'C';
  // วันรับงานกับวันปิดงานตั้งต้นเป็นวันเดียวกัน (วันนี้)
  DateTime _reportDate = DateTime.now(),
      _startDate = DateTime.now(),
      _stopDate = DateTime.now();
  // bool _isLoading = false,
  bool _isSaving = false;
  String? _error;
  bool get isEdit => widget.maintenance != null;

  // Dropdown data
  List<Employee> _employees = [];
  List<Room> _rooms = [];
  bool _roomsLoaded = false;
  List<Tpart> _tparts = [];
  List<Part> _parts = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (isEdit) {
      _loadExistingData();
      _loadTparts();
    } else {
      // ใบใหม่ ผู้แจ้งคือคนที่ล็อกอินอยู่เสมอ แก้ไม่ได้
      _selectedEmp1 = _myEmpId;
      _reportnameCtrl.text = widget.authProvider.displayName;
      // งานซ่อมบำรุงเปิดใบเองก็เป็นผู้รับงานไปด้วย
      if (_isService) _acceptJob();
    }
  }

  /// ผู้ใช้เป็นงานซ่อมบำรุง (role SERVICE) ผู้รับงานต้องเป็นคนกลุ่มนี้เท่านั้น
  bool get _isService => widget.authProvider.hasRole('SERVICE');

  /// ตั้งคนที่ล็อกอินเป็นผู้รับงาน และวันรับงาน = วันปิดงาน = วันนี้
  ///
  /// เรียกเมื่อเจ้าหน้าที่งานซ่อมบำรุงเปิดใบที่ยังไม่มีผู้รับงาน
  /// (ตามคำขอปรับปรุง 5.3 "วันรับงาน/วันปิดงาน auto เป็นวันเดียวกัน
  /// = วันที่ user service เปิดเข้ามาดูรายละเอียด") ค่าจะบันทึกจริงเมื่อกดบันทึก
  void _acceptJob() {
    _selectedEmp2 = _myEmpId;
    final today = DateUtils.dateOnly(DateTime.now());
    _startDate = today;
    _stopDate = today;
    if (_workstatus == '0') _workstatus = '1';
  }

  /// รหัสพนักงานของบัญชีที่ล็อกอิน ใช้เป็นค่าตั้งต้นของช่องผู้แจ้ง/ผู้รับงาน
  ///
  /// ตอนล็อกอิน backend ส่ง empID = 0 มาให้เมื่อบัญชีนั้นยังไม่ผูกกับพนักงาน
  /// ต้องกรองทิ้ง ไม่งั้น dropdown จะได้ค่าที่ไม่มีในรายการแล้ว assert
  int? get _myEmpId {
    final id = widget.authProvider.empID;
    return (id == null || id == 0) ? null : id;
  }

  void _loadExistingData() {
    final m = widget.maintenance!;
    _reportnameCtrl.text = m.reportname ?? '';
    _placeCtrl.text = m.place ?? '';
    _positionCtrl.text = m.position ?? '';
    _reporttelCtrl.text = m.reporttel ?? '';
    _reportremarkCtrl.text = m.reportremark ?? '';
    _workdetailCtrl.text = m.workdetail ?? '';
    _priceCtrl.text = m.price?.toString() ?? '';
    _workremarkCtrl.text = m.workremark ?? '';
    _selectedEmp1 = m.employeeid1?.toInt();
    _selectedRoomid = m.roomid;
    _placetype = m.placetype ?? RoomBuilding.lodging.placetype;
    _workstatus = m.workstatus ?? '0';
    _worktype = m.worktype ?? 'E';
    _resolutiontype = m.resolutiontype ?? 'C';

    // ✅ Parse date strings from API
    _reportDate = _parseDate(m.reportdate) ?? DateTime.now();
    _startDate = _parseDate(m.startdate) ?? DateTime.now();
    _stopDate = _parseDate(m.stopdate) ?? _startDate;

    // ผู้รับงาน = เจ้าหน้าที่งานซ่อมบำรุงที่ล็อกอินอยู่ (คำขอปรับปรุง 5.3)
    // ใบที่ยังไม่มีผู้รับงาน เมื่อ SERVICE เปิดดูให้รับงานอัตโนมัติ
    // ใบที่มีผู้รับงานแล้วไม่แตะ เพราะผู้รับงานเดิมเป็นข้อมูลของใบนั้น
    final emp2 = m.employeeid2?.toInt();
    if (emp2 == null || emp2 == 0) {
      if (_isService) _acceptJob();
    } else {
      _selectedEmp2 = emp2;
    }
  }

  // ✅ Helper method to parse date string
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      // Try parsing "2026-07-23 00:00:00" format
      return DateTime.parse(dateStr);
    } catch (e) {
      try {
        // Try parsing "2026-07-23" format
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (e) {
        if (AppLogger.on) AppLogger.d('Error parsing date: $dateStr');
        return null;
      }
    }
  }

  Future<void> _loadDropdowns() async {
    try {
      final emps = await widget.apiService.getEmployeesList();
      // ใช้ /rooms (ไม่ใช่ /rooms/list) เพราะต้องได้เลขอาคารมากรองห้องตามอาคาร
      // GET ของ /rooms ไม่ถูกคุมสิทธิ์หน้าจอ ทุกคนที่ล็อกอินเรียกได้ เรียงตามลำดับห้อง
      final roomResult = await widget.apiService.getRooms(page: 0, size: 10000);
      final rooms = (roomResult['rooms'] as List? ?? const [])
          .map((j) => Room.fromJson(j as Map<String, dynamic>))
          .where((r) => r.roomID != null)
          .toList();
      final parts = await widget.apiService.getPartsList();
      if (mounted) {
        setState(() {
          _employees = emps;
          _rooms = rooms;
          _roomsLoaded = true;
          _parts = parts;
          // ใบเดิมที่ไม่มีชื่อผู้แจ้งเป็นข้อความ เติมจากรายชื่อพนักงานไว้แสดง
          if (_reportnameCtrl.text.trim().isEmpty) {
            _reportnameCtrl.text = _empName(_selectedEmp1) ?? '';
          }
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading dropdowns: $e');
    }
  }

  Future<void> _loadTparts() async {
    if (widget.maintenance?.maintenanceID == null) return;
    try {
      final tparts = await widget.apiService.getTpartsByMaintenanceId(
        widget.maintenance!.maintenanceID!,
      );
      if (mounted) setState(() => _tparts = tparts);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading tparts: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final d = Maintenance(
        maintenanceID: widget.maintenance?.maintenanceID,
        reportname: _reportnameCtrl.text,
        placetype: _placetype,
        place: _placeCtrl.text,
        position: _positionCtrl.text,
        reporttel: _reporttelCtrl.text,
        reportremark: _reportremarkCtrl.text,
        workdetail: _workdetailCtrl.text,
        price: double.tryParse(_priceCtrl.text),
        resolutiontype: _resolutiontype,
        workremark: _workremarkCtrl.text,
        workstatus: _workstatus,
        worktype: _worktype,
        roomid: _selectedRoomid,
        employeeid1: _selectedEmp1,
        employeeid2: _selectedEmp2,
        // ✅ Format dates for API
        reportdate: _reportDate.toIso8601String(),
        startdate: _startDate.toIso8601String(),
        // DateFormat('yyyy-MM-dd').format(_startDate),
        stopdate: _stopDate.toIso8601String(),
        // DateFormat('yyyy-MM-dd').format(_stopDate),
      );

      if (isEdit) {
        await widget.apiService.updateMaintenance(
          widget.maintenance!.maintenanceID!,
          d,
        );
      } else {
        await widget.apiService.createMaintenance(d);
      }
      if (mounted) {
        context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  void _tpartDialog({Tpart? transaction}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => TpartDialog(
        transaction: transaction,
        apiService: widget.apiService,
        parts: _parts,
        employees: _employees,
        maintenances: widget.maintenance != null ? [widget.maintenance!] : [],
        authProvider: widget.authProvider,
        preselectedMaintenanceId: widget.maintenance?.maintenanceID,
        // preselectedMaintenanceId:
        //     widget.maintenance?.maintenanceID, // ✅ Add this
      ),
    ).then((_) => _loadTparts());
  }

  @override
  Widget build(BuildContext context) {
    final isD = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit
              ? 'แจ้งซ่อม #${widget.maintenance?.maintenanceID}'
              : 'แจ้งซ่อม (ใหม่)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        // ไม่มีปุ่มลบ — ห้ามลบใบแจ้งซ่อม (คำขอปรับปรุง 5.3)
        // งานที่ไม่ได้ซ่อมให้เปลี่ยนสถานะงานเป็น "ยกเลิกงาน" แทน
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saveColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isD ? 24 : 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              // Two columns
              isD
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildColumn1()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildColumn2()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildColumn1(),
                        const SizedBox(height: 24),
                        _buildColumn2(),
                      ],
                    ),
              // Tpart section
              if (isEdit) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'บันทึกรับจ่ายวัสดุซ่อมบำรุง',
                      style: TextStyle(
                        fontSize: isD ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _tpartDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('เพิ่มรายการ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.addColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_tparts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.fieldFillColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'ยังไม่มีรายการวัสดุซ่อมบำรุง',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ..._tparts.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          //ID: ${t.tpartID} |
                          Expanded(
                            child: Text(
                              ' ${t.partName ?? '-'} | ${t.typeName} | จำนวน: ${t.qty} | ${Util.formatThaiDateStr(t.date)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _tpartDialog(transaction: t),
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEdit)
          _readOnlyField('ID', '${widget.maintenance?.maintenanceID}'),

        // _dateField('วันที่แจ้ง', _reportDate, () async {
        //   final p = await showDatePicker(
        //     context: context,
        //     initialDate: _reportDate,
        //     firstDate: DateTime(2020),
        //     lastDate: DateTime(2037),
        //     locale: const Locale('th'),
        //   );
        //   if (p != null) setState(() => _reportDate = p);
        // }),
        _dateField('วันที่แจ้ง', _reportDate, () async {
          final DateTime? picked = await Util.dateFieldPickerNullable(
            context, // ✅ Pass context
            _reportDate, // Christian year DateTime
          );

          if (picked != null && picked != _reportDate) {
            setState(() => _reportDate = picked);
          }
        }),
        /*
        () async {
          int y = _reportDate.year + 543;
          int m = _reportDate.month;
          int d = _reportDate.day;
          DateTime selectedDate = DateTime(
            y,
            m,
            d,
          ); // ✅ Buddhist year 2569 = 2026
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate, // _reportDate,
            firstDate: DateTime(2560, 1, 1), // Buddhist year 2565
            lastDate: DateTime(2580, 12, 31), // Buddhist year 2580
            helpText: 'เลือกวันที่',
            cancelText: 'ยกเลิก',
            confirmText: 'ตกลง',
            locale: const Locale('th'),
            // Custom builder to show Buddhist year
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                  dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                ),
                child: Localizations.override(
                  context: context,
                  locale: const Locale('th'),
                  child: child!,
                ),
              );
            },
          );
          // if (p != null) setState(() => _reportDate = p);
           if (picked != null && picked != selectedDate) {
            setState(() {
              _reportDate = picked;
              y = _reportDate.year - 543;
              m = _reportDate.month;
              d = _reportDate.day;
              _reportDate = DateTime(y, m, d);
            });
          }
        }
        ),
*/
        // ชื่อผู้แจ้ง = ชื่อที่ล็อกอิน แก้ไม่ได้ (ใบเดิมแสดงชื่อที่บันทึกไว้)
        _readOnlyField('ชื่อผู้แจ้ง', _reporterName),
        // เรียงตามที่ผู้ใช้กำหนด: อาคารพัก, อาคารเรียน, อาคารอำนวยการ
        _dd(
          'ประเภทของสถานที่',
          _placetype,
          [
            for (final b in RoomBuilding.all)
              DropdownMenuItem(value: b.placetype, child: Text(b.name)),
            // รหัสที่ไม่รู้จักจากข้อมูลเดิม ใส่ไว้ไม่ให้ dropdown assert
            if (RoomBuilding.ofPlacetype(_placetype) == null)
              DropdownMenuItem(value: _placetype, child: Text(_placetype)),
          ],
          (v) => setState(() {
            _placetype = v!;
            // ห้องที่เลือกไว้ไม่อยู่ในอาคารใหม่ ต้องล้างทิ้ง
            if (!_roomsInPlace.any((r) => r.roomID == _selectedRoomid)) {
              _selectedRoomid = null;
            }
          }),
        ),
        _dd(
          'ห้อง',
          _selectedRoomid,
          _roomItems(),
          (v) => setState(() => _selectedRoomid = v),
          // สร้าง dropdown ใหม่เมื่อเปลี่ยนอาคาร/โหลดห้องเสร็จ ให้ค่าที่แสดงตรงกับ state
          key: ValueKey('room-$_placetype-$_roomsLoaded'),
          helper: _roomFallbackNote,
        ),
        _fld('สถานที่', _placeCtrl, multiline: true),
        _fld('บริเวณหรือตำแหน่ง', _positionCtrl, multiline: true),
        _fld('หมายเลขติดต่อ', _reporttelCtrl),
        _fld('รายละเอียด', _reportremarkCtrl, multiline: true, minLines: 4),
      ],
    );
  }

  /// ชื่อผู้แจ้งที่แสดง — ข้อความในใบ ถ้าไม่มีใช้ชื่อพนักงาน ถ้าไม่มีอีกใช้ชื่อที่ล็อกอิน
  String get _reporterName {
    final t = _reportnameCtrl.text.trim();
    if (t.isNotEmpty) return t;
    final n = _empName(_selectedEmp1);
    if (n != null) return n;
    return isEdit ? '-' : widget.authProvider.displayName;
  }

  /// ชื่อผู้รับงานที่แสดง
  String get _receiverName {
    final n = _empName(_selectedEmp2);
    if (n != null) return n;
    // SERVICE ที่บัญชียังไม่ผูกกับพนักงาน บันทึกเป็นผู้รับงานไม่ได้ ต้องแจ้งให้รู้
    if (_selectedEmp2 == null && _isService && _myEmpId == null) {
      return '${widget.authProvider.displayName} '
          '(บัญชียังไม่ผูกกับรายชื่อพนักงาน บันทึกเป็นผู้รับงานไม่ได้)';
    }
    if (_selectedEmp2 != null && _employees.isEmpty) return 'กำลังโหลด...';
    return 'ยังไม่มีผู้รับงาน';
  }

  /// ชื่อ-สกุลของพนักงาน ไม่พบ = null
  String? _empName(int? id) {
    if (id == null) return null;
    for (final e in _employees) {
      if (e.empID == id) {
        final n = '${e.name ?? ''} ${e.lastname ?? ''}'.trim();
        return n.isEmpty ? null : n;
      }
    }
    return null;
  }

  /// ห้องในอาคารที่เลือก (เทียบ placetype ของใบกับ m_room.building ผ่าน [RoomBuilding])
  ///
  /// ถ้ายังไม่มีห้องไหนกำหนดอาคารนี้ไว้เลย (ข้อมูลห้องยังไม่ได้ตั้งตึก)
  /// ให้แสดงทุกห้องแทน ไม่งั้นแจ้งซ่อมไม่ได้เลย และแสดงหมายเหตุใต้ช่อง
  List<Room> get _roomsInPlace {
    final b = RoomBuilding.ofPlacetype(_placetype);
    if (b == null) return _rooms;
    final inBuilding = _rooms.where((r) => r.building == b.code).toList();
    return inBuilding.isEmpty ? _rooms : inBuilding;
  }

  /// หมายเหตุใต้ช่องห้อง เมื่อกรองตามอาคารไม่ได้และต้องแสดงทุกห้อง
  String? get _roomFallbackNote {
    final b = RoomBuilding.ofPlacetype(_placetype);
    if (!_roomsLoaded || b == null || _rooms.isEmpty) return null;
    if (_rooms.any((r) => r.building == b.code)) return null;
    return 'ยังไม่มีห้องที่กำหนดตึกเป็น${b.name} จึงแสดงทุกห้อง '
        '(กำหนดได้ที่เมนูห้อง)';
  }

  List<DropdownMenuItem<int>> _roomItems() {
    final rooms = _roomsInPlace;
    final items = rooms
        .map(
          (r) => DropdownMenuItem<int>(value: r.roomID, child: Text(r.roomNO)),
        )
        .toList();
    // ใบเดิมที่ห้องไม่อยู่ในอาคารที่เลือก (หรือห้องถูกลบ) ยังต้องแสดงห้องเดิมไว้
    // ไม่งั้น DropdownButtonFormField จะ assert เพราะค่าไม่มีในรายการ
    final cur = _selectedRoomid;
    if (cur != null && _roomsLoaded && !rooms.any((r) => r.roomID == cur)) {
      final old = _rooms.where((r) => r.roomID == cur);
      items.add(
        DropdownMenuItem<int>(
          value: cur,
          child: Text(old.isNotEmpty ? old.first.roomNO : 'ห้องรหัส $cur'),
        ),
      );
    }
    return items;
  }

  Widget _buildColumn2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dd('สถานะงาน', _workstatus, [
          const DropdownMenuItem(value: '0', child: Text('ยังไม่มีผู้รับงาน')),
          const DropdownMenuItem(value: '1', child: Text('รับงาน')),
          const DropdownMenuItem(
            value: '2',
            child: Text('รออุปกรณ์หรือจ้างซ่อม'),
          ),
          const DropdownMenuItem(value: '3', child: Text('ปิดงาน')),
          const DropdownMenuItem(value: '4', child: Text('ยกเลิกงาน')),
          const DropdownMenuItem(value: '5', child: Text('ไม่ระบุ')),
        ], (v) => setState(() => _workstatus = v!)),

        _dateField('วันที่รับงาน', _startDate, () async {
          final DateTime? picked = await Util.dateFieldPickerNullable(
            context, // ✅ Pass context
            _startDate, // Christian year DateTime
          );

          if (picked != null && picked != _startDate) {
            setState(() => _startDate = picked);
          }
        }),

        _dateField('วันที่ปิดงาน', _stopDate, () async {
          final DateTime? picked = await Util.dateFieldPickerNullable(
            context, // ✅ Pass context
            _stopDate, // Christian year DateTime
          );

          if (picked != null && picked != _stopDate) {
            setState(() => _stopDate = picked);
          }
        }),

        /*
        _dateField('วันที่รับงาน', _startDate, () async {
          int y = _startDate.year + 543;
          int m = _startDate.month;
          int d = _startDate.day;
          DateTime selectedDate = DateTime(
            y,
            m,
            d,
          ); // ✅ Buddhist year 2569 = 2026
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate, // _reportDate,
            firstDate: DateTime(2560, 1, 1), // Buddhist year 2565
            lastDate: DateTime(2580, 12, 31), // Buddhist year 2580
            helpText: 'เลือกวันที่',
            cancelText: 'ยกเลิก',
            confirmText: 'ตกลง',
            locale: const Locale('th'),
            // Custom builder to show Buddhist year
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                  dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                ),
                child: Localizations.override(
                  context: context,
                  locale: const Locale('th'),
                  child: child!,
                ),
              );
            },
          );
          // if (p != null) setState(() => _reportDate = p);
          if (picked != null && picked != selectedDate) {
            setState(() {
              _startDate = picked;

              y = _startDate.year - 543;
              m = _startDate.month;
              d = _startDate.day;
              _startDate = DateTime(y, m, d);
            });
          }
        }),
        _dateField('วันที่ปิดงาน', _stopDate, () async {
          int y = _stopDate.year + 543;
          int m = _stopDate.month;
          int d = _stopDate.day;
          DateTime selectedDate = DateTime(
            y,
            m,
            d,
          ); // ✅ Buddhist year 2569 = 2026
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate, // _reportDate,
            firstDate: DateTime(2560, 1, 1), // Buddhist year 2565
            lastDate: DateTime(2580, 12, 31), // Buddhist year 2580
            helpText: 'เลือกวันที่',
            cancelText: 'ยกเลิก',
            confirmText: 'ตกลง',
            locale: const Locale('th'),
            // Custom builder to show Buddhist year
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                  dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                ),
                child: Localizations.override(
                  context: context,
                  locale: const Locale('th'),
                  child: child!,
                ),
              );
            },
          );
          // if (p != null) setState(() => _reportDate = p);
          // AppLogger.d("picked*********");
          // AppLogger.d(picked.toString());
          // AppLogger.d("selectedDate*********");
          // AppLogger.d(selectedDate.toString());
          if (picked != null && picked != selectedDate) {
            setState(() {
              _stopDate = picked;

              y = _stopDate.year - 543;
              m = _stopDate.month;
              d = _stopDate.day;
              _stopDate = DateTime(y, m, d);
            });
          }
        }),

        */
        // ผู้รับงาน = เจ้าหน้าที่งานซ่อมบำรุง (SERVICE) ที่ล็อกอิน แก้ไม่ได้
        // ตั้งให้อัตโนมัติตอนเปิดใบ ดู _acceptJob
        _readOnlyField('ผู้รับงาน', _receiverName),
        _dd('ประเภทของงาน', _worktype, [
          const DropdownMenuItem(value: 'E', child: Text('ไฟฟ้า')),
          const DropdownMenuItem(value: 'A', child: Text('เครื่องปรับอากาศ')),
          const DropdownMenuItem(value: 'P', child: Text('ประปา')),
          const DropdownMenuItem(value: 'TV', child: Text('โทรทัศน์')),
          const DropdownMenuItem(value: 'TP', child: Text('โทรศัพท์')),
          const DropdownMenuItem(value: 'B', child: Text('อาคารสถานที่')),
        ], (v) => setState(() => _worktype = v!)),
        _fld('การแก้ไข', _workdetailCtrl, multiline: true, minLines: 3),
        _dd('ลักษณะการดำเนินงาน', _resolutiontype, [
          const DropdownMenuItem(value: 'C', child: Text('ซ่อม')),
          const DropdownMenuItem(value: 'O', child: Text('จ้างซ่อม')),
        ], (v) => setState(() => _resolutiontype = v!)),
        _fld('ราคา', _priceCtrl, inputType: TextInputType.number),
        _fld('อื่นๆ', _workremarkCtrl, multiline: true, minLines: 3),
      ],
    );
  }

  /// ช่องกรอกข้อความ
  ///
  /// [multiline] = ช่องข้อความยาว ขยายความสูงตามข้อความให้เห็นครบ ไม่ตัดทิ้ง
  /// (คำขอปรับปรุง 5.3 "แสดงให้ครบ หรือให้ช่องกว้างกว่านี้") เริ่มที่ [minLines] บรรทัด
  Widget _fld(
    String l,
    TextEditingController c, {
    bool multiline = false,
    int minLines = 2,
    TextInputType? inputType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: c,
          keyboardType: multiline ? TextInputType.multiline : inputType,
          minLines: multiline ? minLines : 1,
          maxLines: multiline ? null : 1,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppTheme.fieldFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
  Widget _dd<T>(
    String l,
    T? v,
    List<DropdownMenuItem<T>> items,
    Function(T?) oc, {
    Key? key,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          key: key,
          initialValue: v,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppTheme.fieldFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: TextStyle(color: AppTheme.warningColor),
          ),
          items: items,
          onChanged: oc,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
  Widget _dateField(String l, DateTime d, VoidCallback ot) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: ot,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.fieldFillColor,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  Util.formatThaiDate(d), // ✅ Shows selected date in Thai
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                // Text(
                //   DateFormat('dd/MM/yyyy').format(d),
                //   style: const TextStyle(fontSize: 14),
                // ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget _readOnlyField(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: Text(
            v,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      ],
    ),
  );
}
