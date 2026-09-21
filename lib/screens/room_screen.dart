import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../utils/dialog.dart';
import '../widgets/app_pagination.dart';
import '../models/room.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../widgets/room_dialog.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class RoomScreen extends StatefulWidget {
  final ApiService apiService;
  const RoomScreen({super.key, required this.apiService});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  List<Room> _rooms = [];
  List<Roomtype> _roomtypes = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 5;
  String? _searchRoomNO;
  int? _filterRoomTypeID;
  int? _filterBuilding;
  int? _filterFloor;
  String? _filterStatus;

  // ช่องกรอกของตัวกรอง — เก็บเป็น controller เพราะค้นหาเมื่อกดปุ่มเท่านั้น
  final TextEditingController _searchRoomNOCtrl = TextEditingController();
  final TextEditingController _filterBuildingCtrl = TextEditingController();
  final TextEditingController _filterFloorCtrl = TextEditingController();

  /// ตัวนับสำหรับสร้าง dropdown ตัวกรองใหม่
  ///
  /// DropdownButtonFormField เก็บค่าที่เลือกไว้ในตัวเอง ถ้าผู้ใช้กดยกเลิก
  /// การยืนยันแล้วเราไม่ทำอะไรต่อ ช่องจะยังแสดงค่าที่เพิ่งเลือก
  /// จึงเพิ่มตัวนับนี้เพื่อเปลี่ยน key ให้ widget ถูกสร้างใหม่ด้วยค่าเดิม
  int _filterEpoch = 0;

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสห้องที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  static const List<Map<String, String>> _statuses = [
    {'code': '1', 'name': 'ใช้งาน'},
    {'code': '2', 'name': 'ไม่ใช้งาน'},
  ];

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันทั้งหัวตารางและแถวข้อมูล
  // ตารางกว้างกว่าจอเล็ก จึงห่อด้วยตัวเลื่อนแนวนอนแล้วตรึงความกว้างไว้
  static const double _wCheck = 44;
  static const double _wCode = 60;
  static const double _wSeq = 70;
  static const double _wRoomNO = 130;
  static const double _wType = 170;
  static const double _wBuilding = 80;
  static const double _wFloor = 80;
  static const double _wStatus = 130;
  static const double _wAction = 100;
  static const double _colGap = 8;
  static const double _tableWidth =
      _wCheck +
      _wCode +
      _wSeq +
      _wRoomNO +
      _wType +
      _wBuilding +
      _wFloor +
      _wStatus +
      _wAction +
      _colGap * 8 +
      32;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadRoomtypes();
  }

  @override
  void dispose() {
    _searchRoomNOCtrl.dispose();
    _filterBuildingCtrl.dispose();
    _filterFloorCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRoomtypes() async {
    try {
      final types = await widget.apiService.getRoomtypeList();
      if (mounted) {
        setState(
          () => _roomtypes = types
              .where((t) => t.roomtypeID != null && t.name.isNotEmpty)
              .toList(),
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading roomtypes: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.getRooms(
        page: _currentPage,
        size: _pageSize,
        roomNO: _searchRoomNO,
        roomTypeID: _filterRoomTypeID,
        building: _filterBuilding,
        floor: _filterFloor,
        status: _filterStatus,
      );
      if (mounted) {
        final List<dynamic>? list = result['rooms'] as List?;
        setState(() {
          _rooms = list?.map((j) => Room.fromJson(j)).toList() ?? [];
          _totalPages = result['totalPages'] as int? ?? 0;
          // สร้างแถวแก้ไขใหม่ทุกครั้งที่โหลด การแก้ไขค้างจะถูกทิ้งไปพร้อมกัน
          _rebuildRows();
          _deletedIds.clear();
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

  String _getRoomTypeName(int? roomTypeID) {
    if (roomTypeID == null) return '-';
    final type = _roomtypes.firstWhere(
      (t) => t.roomtypeID == roomTypeID,
      orElse: () => Roomtype(roomtypeID: roomTypeID, name: 'ไม่พบ'),
    );
    return type.name;
  }

  void _showAddEditDialog({Room? room}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RoomDialog(
        room: room,
        apiService: widget.apiService,
        roomtypes: _roomtypes,
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteRoom(Room room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบห้อง "${room.roomNO}" ใช่หรือไม่?',
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
        await widget.apiService.deleteRoom(room.roomID!);
        if (mounted) {
          context.showSuccessSnackBar('ลบข้อมูลสำเร็จ');
          _loadData();
        }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // แก้ไขในตาราง — แก้หลายแถวแล้วกดบันทึกทีเดียว
  // ---------------------------------------------------------------------------

  /// สร้างแถวแก้ไขจากข้อมูลที่โหลดมา ทิ้งของเดิมเพื่อไม่ให้ controller ค้าง
  void _rebuildRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(_rooms.map(_EditRow.from));
  }

  /// มีการแก้ไขที่ยังไม่ได้บันทึกหรือไม่
  bool get _dirty =>
      _rows.any((r) => r.isNew || r.changed) || _deletedIds.isNotEmpty;

  Widget _headerCheckbox() {
    final selected = _rows.where((r) => r.selected).length;
    final value = _rows.isEmpty || selected == 0
        ? false
        : (selected == _rows.length ? true : null);
    // หัวตารางพื้นอ่อน จึงใช้สีมาตรฐานของธีมได้เลย
    return Checkbox(
      tristate: true,
      value: value,
      activeColor: AppTheme.primaryColor,
      onChanged: _rows.isEmpty ? null : (_) => _selectAll(),
    );
  }

  void _selectAll() {
    final all = _rows.isNotEmpty && _rows.every((r) => r.selected);
    setState(() {
      for (final r in _rows) {
        r.selected = !all;
      }
    });
  }

  /// เพิ่มแถวว่างท้ายตาราง ประเภทห้องตั้งค่าเริ่มต้นเป็นตัวแรกของรายการ
  void _addRow() {
    setState(
      () => _rows.add(
        _EditRow.empty(
          _roomtypes.isNotEmpty ? _roomtypes.first.roomtypeID : null,
        ),
      ),
    );
  }

  /// ลบออกจากหน้าจอ แถวที่มีอยู่แล้วจะถูกลบจริงตอนกดบันทึก
  void _deleteSelectedRows() {
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      context.showInfoSnackBar('ยังไม่ได้เลือกรายการที่จะลบ');
      return;
    }
    setState(() {
      for (final r in selected) {
        if (!r.isNew) _deletedIds.add(r.originalRoomID!);
        r.dispose();
        _rows.remove(r);
      }
    });
    context.showInfoSnackBar(
      'ลบ ${selected.length} รายการออกจากหน้าจอแล้ว กดบันทึกเพื่อยืนยัน',
    );
  }

  /// ข้อความแจ้งเตือนเมื่อยังบันทึกไม่ได้ — null แปลว่าผ่าน
  String? _validateRows() {
    final roomNOs = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final roomNO = r.roomNOCtrl.text.trim();
      if (roomNO.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกเลขห้อง';
      if (r.roomTypeID == null) return 'แถวที่ $no ยังไม่ได้เลือกประเภทห้อง';
      final seq = r.sequenceCtrl.text.trim();
      if (seq.isNotEmpty && int.tryParse(seq) == null) {
        return 'แถวที่ $no ลำดับต้องเป็นตัวเลข';
      }
      final building = r.buildingCtrl.text.trim();
      if (building.isNotEmpty && int.tryParse(building) == null) {
        return 'แถวที่ $no ตึกต้องเป็นตัวเลข';
      }
      final floor = r.floorCtrl.text.trim();
      if (floor.isNotEmpty && int.tryParse(floor) == null) {
        return 'แถวที่ $no ชั้นต้องเป็นตัวเลข';
      }
      if (roomNOs.containsKey(roomNO)) {
        return 'เลขห้อง $roomNO ซ้ำกัน (แถวที่ ${roomNOs[roomNO]! + 1} และ $no)';
      }
      roomNOs[roomNO] = i;
    }
    return null;
  }

  /// บันทึกทุกแถวที่แก้ไขในครั้งเดียว
  ///
  /// ลบแถวที่เอาออก สร้างแถวใหม่ และอัปเดตแถวที่ค่าเปลี่ยน แล้วโหลดข้อมูลใหม่
  Future<void> _saveRows() async {
    if (_isSaving) return;
    final problem = _validateRows();
    if (problem != null) {
      context.showErrorSnackBar(problem);
      return;
    }
    if (!_dirty) {
      context.showInfoSnackBar('ไม่มีการแก้ไขที่ต้องบันทึก');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final id in _deletedIds) {
        await widget.apiService.deleteRoom(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        if (r.isNew) {
          await widget.apiService.createRoom(r.toRoom());
        } else if (r.changed) {
          await widget.apiService.updateRoom(r.originalRoomID!, r.toRoom());
        }
      }

      if (!mounted) return;
      context.showSuccessSnackBar('บันทึกเรียบร้อยแล้ว');
      setState(() => _isSaving = false);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar(
        'บันทึกไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}',
      );
      // อาจบันทึกสำเร็จไปแล้วบางส่วน จึงโหลดใหม่ให้ตรงของจริง
      await _loadData();
    }
  }

  /// ปิดหน้าจอ ถามก่อนถ้ายังมีการแก้ไขค้าง
  Future<void> _closeScreen() async {
    if (!await _confirmDiscard()) return;
    if (mounted) Navigator.pop(context);
  }

  /// ถามยืนยันเมื่อยังมีการแก้ไขค้างอยู่ — true = ไปต่อได้
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?',
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  /// ค้นหาตามค่าที่กรอกไว้ในช่องกรอง — ถามก่อนถ้ายังมีการแก้ไขค้าง
  ///
  /// เรียกเมื่อกดปุ่มค้นหา หรือกด Enter ในช่องกรอกเท่านั้น
  /// ไม่ได้ค้นหาทุกตัวอักษรที่พิมพ์ เพราะจะโหลดทับการแก้ไขที่ยังไม่ได้บันทึก
  Future<void> _runSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchRoomNO = _searchRoomNOCtrl.text.trim();
      _filterBuilding = int.tryParse(_filterBuildingCtrl.text.trim());
      _filterFloor = int.tryParse(_filterFloorCtrl.text.trim());
      _currentPage = 0;
    });
    _loadData();
  }

  /// ผู้ใช้กดยกเลิกการยืนยัน — สร้าง dropdown ตัวกรองใหม่ให้กลับเป็นค่าเดิม
  void _cancelFilterChange() {
    setState(() => _filterEpoch++);
  }

  /// รายการประเภทห้องของ dropdown ในแถว
  ///
  /// ถ้าค่าปัจจุบันไม่มีในรายการ (ประเภทถูกลบ หรือรายการยังโหลดไม่เสร็จ)
  /// ให้ใส่รายการนั้นเพิ่มไว้ ไม่งั้น DropdownButtonFormField จะ assert
  List<DropdownMenuItem<int>> _roomTypeItems(int? current) {
    final items = _roomtypes
        .where((t) => t.roomtypeID != null)
        .map(
          (t) => DropdownMenuItem<int>(
            value: t.roomtypeID,
            child: Text(t.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
    if (current != null && !_roomtypes.any((t) => t.roomtypeID == current)) {
      items.add(
        DropdownMenuItem<int>(
          value: current,
          child: Text(
            _getRoomTypeName(current),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  /// หัวตารางที่แก้ไขได้
  Widget _tableHeader(double fontSize) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryColor,
    );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(width: _wCheck, child: _headerCheckbox()),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wCode,
            child: Text('รหัส', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wSeq,
            child: Text('ลำดับ', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wRoomNO,
            child: Text('เลขห้อง', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wType,
            child: Text('ประเภท', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wBuilding,
            child: Text('ตึก', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wFloor,
            child: Text('ชั้น', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wStatus,
            child: Text('สถานะ', style: style),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wAction,
            child: Text('จัดการ', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัสห้อง (roomID) เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแสดงอย่างเดียว
  /// แถวที่เพิ่งเพิ่มยังไม่มีรหัส จึงแสดงขีดและปิดปุ่มรายแถวไว้
  Widget _editableRow(_EditRow row, int index, double fontSize, double icon) {
    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : AppTheme.fieldFillColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: _wCheck,
            child: Checkbox(
              value: row.selected,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => row.selected = v ?? false),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wCode,
            child: Text(
              row.isNew ? '-' : '${row.originalRoomID}',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wSeq,
            child: TextField(
              controller: row.sequenceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wRoomNO,
            child: TextField(
              controller: row.roomNOCtrl,
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wType,
            child: DropdownButtonFormField<int>(
              // ผูก key กับแถว เพื่อให้ค่าที่แสดงตรงกับข้อมูลเสมอหลังโหลดใหม่
              key: ValueKey('type-${row.uid}'),
              initialValue: row.roomTypeID,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _roomTypeItems(row.roomTypeID),
              onChanged: (v) => setState(() => row.roomTypeID = v),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wBuilding,
            child: TextField(
              controller: row.buildingCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wFloor,
            child: TextField(
              controller: row.floorCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: fontSize),
              decoration: _rowInput(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wStatus,
            child: DropdownButtonFormField<String>(
              key: ValueKey('status-${row.uid}'),
              initialValue: row.status,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
              decoration: _rowInput(),
              items: _statuses
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['code'],
                      child: Text(s['name']!, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => row.status = v ?? '1'),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: _wAction,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: row.isNew
                      ? null
                      : () => _showAddEditDialog(room: row.toRoom()),
                  icon: Icon(Icons.edit, size: icon, color: Colors.blue),
                  tooltip: 'แก้ไขในหน้าต่าง',
                ),
                IconButton(
                  onPressed: row.isNew ? null : () => _deleteRoom(row.toRoom()),
                  icon: Icon(Icons.delete, size: icon, color: Colors.red),
                  tooltip: 'ลบทันที',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (_dirty)
            Text(
              'มีการแก้ไขที่ยังไม่ได้บันทึก',
              style: TextStyle(fontSize: 13, color: AppTheme.warningColor),
            ),
          _rowButton('ลบที่เลือก', _deleteSelectedRows),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          _rowButton('เพิ่ม', _addRow),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.saveColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF43A047,
              ).withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);

    return PopScope(
      // ปิดด้วยปุ่มย้อนกลับของเบราว์เซอร์ก็ต้องถามก่อนเหมือนกัน
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: _closeScreen,
            tooltip: 'กลับหน้าหลัก',
          ),
          title: Text(
            'ห้อง (Room)',
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
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 170 : double.infinity),
                      child: TextField(
                        controller: _searchRoomNOCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาเลขห้อง...',
                          prefixIcon: Icon(Icons.search, size: iconSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // ค้นหาเมื่อกด Enter เท่านั้น
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 200
                          : (isDesktop ? 170 : (screenWidth - 56) / 2 - 6),
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('filter-type-$_filterEpoch'),
                        initialValue: _filterRoomTypeID,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'ประเภท',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'ทั้งหมด',
                              style: TextStyle(fontSize: bodyFontSize),
                            ),
                          ),
                          ..._roomtypes.map(
                            (t) => DropdownMenuItem<int?>(
                              value: t.roomtypeID,
                              child: Text(
                                t.name,
                                style: TextStyle(fontSize: bodyFontSize),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) async {
                          // ถามก่อนทิ้งการแก้ไข ถ้ายกเลิกต้องไม่เปลี่ยนค่าในช่อง
                          if (!await _confirmDiscard()) {
                            _cancelFilterChange();
                            return;
                          }
                          setState(() {
                            _filterRoomTypeID = v;
                            _currentPage = 0;
                          });
                          _loadData();
                        },
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 120
                          : (isDesktop ? 100 : (screenWidth - 56) / 2 - 6),
                      child: TextField(
                        controller: _filterBuildingCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'ตึก',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // ค้นหาเมื่อกด Enter เท่านั้น
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 120
                          : (isDesktop ? 100 : (screenWidth - 56) / 2 - 6),
                      child: TextField(
                        controller: _filterFloorCtrl,
                        style: TextStyle(fontSize: bodyFontSize),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'ชั้น',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
                          ),
                        ),
                        // ค้นหาเมื่อกด Enter เท่านั้น
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    SizedBox(
                      width: isLargeScreen
                          ? 150
                          : (isDesktop ? 130 : (screenWidth - 56) / 2 - 6),
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey('filter-status-$_filterEpoch'),
                        initialValue: _filterStatus,
                        style: TextStyle(fontSize: bodyFontSize),
                        decoration: InputDecoration(
                          hintText: 'สถานะ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: isDesktop ? 12 : 8,
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
                        onChanged: (v) async {
                          // ถามก่อนทิ้งการแก้ไข ถ้ายกเลิกต้องไม่เปลี่ยนค่าในช่อง
                          if (!await _confirmDiscard()) {
                            _cancelFilterChange();
                            return;
                          }
                          setState(() {
                            _filterStatus = v;
                            _currentPage = 0;
                          });
                          _loadData();
                        },
                      ),
                    ),
                    // ปุ่มค้นหา — ทางเดียวที่โหลดข้อมูลใหม่จากช่องกรอก
                    ElevatedButton(
                      onPressed: _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 20,
                          vertical: isDesktop ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ค้นหา',
                        style: TextStyle(fontSize: bodyFontSize),
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
                  : _rows.isEmpty
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
                          // ตารางกว้างกว่าจอ จึงเลื่อนแนวนอนได้
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: _tableWidth,
                              child: Column(
                                children: [
                                  _tableHeader(bodyFontSize),
                                  for (var i = 0; i < _rows.length; i++)
                                    _editableRow(
                                      _rows[i],
                                      i,
                                      bodyFontSize,
                                      iconSize,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            // แถวปุ่มของการแก้ไขในตาราง แสดงตลอดเพื่อให้กดเพิ่มแถวแรกได้
            _rowActionBar(),
            // Pagination
            // แถบแบ่งหน้ามาตรฐาน แสดงตลอดแม้มีหน้าเดียว เพราะตัวเลือกแถวต่อหน้า
            // ย้ายมาอยู่ในนี้แล้ว ถ้าซ่อนไว้จะเปลี่ยนจำนวนแถวไม่ได้
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: AppPagination(
                currentPage: _currentPage,
                totalPages: _totalPages,
                pageSize: _pageSize,
                onPageChanged: (p) async {
                  if (!await _confirmDiscard()) return;
                  _currentPage = p;
                  _loadData();
                },
                onPageSizeChanged: (size) async {
                  if (!await _confirmDiscard()) return;
                  _pageSize = size;
                  _currentPage = 0;
                  _loadData();
                },
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
      ),
    );
  }
}

/// หนึ่งแถวที่แก้ไขได้ในตารางห้อง
class _EditRow {
  /// รหัสห้องเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalRoomID;
  final Room? original;

  /// ตัวเลขประจำแถว ใช้เป็น key ของ dropdown ไม่ให้ค่าค้างข้ามการโหลดใหม่
  final int uid;
  static int _uidSeq = 0;

  final TextEditingController sequenceCtrl;
  final TextEditingController roomNOCtrl;
  final TextEditingController buildingCtrl;
  final TextEditingController floorCtrl;

  int? roomTypeID;
  String status;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalRoomID,
    this.original,
    required this.sequenceCtrl,
    required this.roomNOCtrl,
    required this.buildingCtrl,
    required this.floorCtrl,
    this.roomTypeID,
    this.status = '1',
  }) : uid = ++_uidSeq;

  factory _EditRow.from(Room r) => _EditRow(
    originalRoomID: r.roomID,
    original: r,
    sequenceCtrl: TextEditingController(text: '${r.sequence}'),
    roomNOCtrl: TextEditingController(text: r.roomNO),
    buildingCtrl: TextEditingController(text: r.building?.toString() ?? ''),
    floorCtrl: TextEditingController(text: r.floor?.toString() ?? ''),
    roomTypeID: r.roomTypeID,
    status: r.status,
  );

  factory _EditRow.empty(int? defaultRoomTypeID) => _EditRow(
    sequenceCtrl: TextEditingController(),
    roomNOCtrl: TextEditingController(),
    buildingCtrl: TextEditingController(),
    floorCtrl: TextEditingController(),
    roomTypeID: defaultRoomTypeID,
  );

  bool get isNew => originalRoomID == null;

  /// แถวเดิมที่มีค่าอย่างน้อยหนึ่งช่องเปลี่ยนไป
  bool get changed {
    if (isNew || original == null) return false;
    final o = original!;
    return roomNOCtrl.text.trim() != o.roomNO.trim() ||
        (int.tryParse(sequenceCtrl.text.trim()) ?? 0) != o.sequence ||
        int.tryParse(buildingCtrl.text.trim()) != o.building ||
        int.tryParse(floorCtrl.text.trim()) != o.floor ||
        roomTypeID != o.roomTypeID ||
        status != o.status;
  }

  Room toRoom() => Room(
    roomID: originalRoomID,
    roomNO: roomNOCtrl.text.trim(),
    roomTypeID: roomTypeID,
    building: int.tryParse(buildingCtrl.text.trim()),
    floor: int.tryParse(floorCtrl.text.trim()),
    sequence: int.tryParse(sequenceCtrl.text.trim()) ?? 0,
    status: status,
  );

  void dispose() {
    sequenceCtrl.dispose();
    roomNOCtrl.dispose();
    buildingCtrl.dispose();
    floorCtrl.dispose();
  }
}
