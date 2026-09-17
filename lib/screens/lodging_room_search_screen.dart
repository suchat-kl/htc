// lib/screens/lodging_room_search_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/room_search_result.dart';
import '../models/room_type_option.dart';
import '../models/statuscheck.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/util.dart';
import '../widgets/app_autocomplete_field.dart';
import '../widgets/app_pagination.dart';
import 'booking_detail_screen.dart';
import 'no_auth_booking_detail_screen.dart';

/// เมนูห้องพัก/ห้องกิจกรรม > ค้นหาห้องพัก
///
/// ส่วนบนเป็นเงื่อนไขค้นหา 9 ช่อง กรอกบางช่องหรือไม่กรอกเลยก็ได้
/// ส่วนล่างแสดงผลเป็นตารางแบ่งหน้า ค่าทั้งหมดแก้ไขไม่ได้ ปุ่มรายละเอียด
/// เปิดหน้ารายละเอียดการจองด้วย bookId แบบเดียวกับหน้ารายการการจอง
///
/// ต่างจากหน้าค้นหาห้องกิจกรรมตรงที่มีประเภทห้องพักและเบอร์โทรศัพท์
/// และ backend ใส่ % ที่ชื่อผู้เข้าพัก ชื่อหน่วยงาน ชื่อหลักสูตร และโทรศัพท์
class LodgingRoomSearchScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;

  const LodgingRoomSearchScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
  });

  @override
  State<LodgingRoomSearchScreen> createState() =>
      _LodgingRoomSearchScreenState();
}

class _LodgingRoomSearchScreenState extends State<LodgingRoomSearchScreen> {
  /// m_roomtype.type ของห้องพัก
  static const String _roomType = 'R';

  static final _apiDate = DateFormat('yyyy-MM-dd');

  // ---------- เงื่อนไขค้นหา ----------
  final _roomNoCtrl = TextEditingController();
  final _roomTypeCtrl = TextEditingController();
  final _contractNameCtrl = TextEditingController();
  final _contractNumberCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _bookTitleCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _stopDate;
  int? _status;

  List<String> _roomNos = [];
  bool _loadingRoomNos = true;
  List<RoomTypeOption> _roomTypes = [];
  bool _loadingRoomTypes = true;
  List<StatusCheck> _statuses = [];

  // ---------- ผลค้นหา ----------
  /// กดค้นหาไปแล้วอย่างน้อยหนึ่งครั้ง — ก่อนนั้นยังไม่แสดงส่วนผลลัพธ์
  bool _searched = false;
  bool _loading = false;
  String? _error;
  List<RoomSearchResult> _results = [];
  int _page = 0;
  int _size = 5;
  int _totalPages = 0;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadRoomNos();
    _loadRoomTypes();
    _loadStatuses();
  }

  @override
  void dispose() {
    _roomNoCtrl.dispose();
    _roomTypeCtrl.dispose();
    _contractNameCtrl.dispose();
    _contractNumberCtrl.dispose();
    _departmentCtrl.dispose();
    _bookTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoomNos() async {
    try {
      final list = await widget.apiService.getSearchRoomNos(type: _roomType);
      if (!mounted) return;
      setState(() {
        _roomNos = list;
        _loadingRoomNos = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading room nos: $e');
      // ไม่มีรายการแนะนำก็ยังพิมพ์ค้นหาเองได้ จึงไม่ขึ้น error
      if (mounted) setState(() => _loadingRoomNos = false);
    }
  }

  Future<void> _loadRoomTypes() async {
    try {
      final list = await widget.apiService.getSearchRoomTypes(type: _roomType);
      if (!mounted) return;
      setState(() {
        _roomTypes = list;
        _loadingRoomTypes = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading room types: $e');
      if (mounted) setState(() => _loadingRoomTypes = false);
    }
  }

  /// รายการสถานะ ดึงทีเดียว 100 รายการ ไม่ส่ง keyword
  Future<void> _loadStatuses() async {
    try {
      final res = await widget.apiService.getStatusChecks(size: 100);
      final list = (res['statuschecks'] as List? ?? const [])
          .map((j) => StatusCheck.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _statuses = list);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading statuses: $e');
    }
  }

  /// รหัสประเภทห้องจากข้อความในช่อง
  ///
  /// หาจากชื่อที่ตรงกันทั้งคำ แทนการจำค่าตอนเลือก เพราะผู้ใช้อาจเลือกแล้ว
  /// แก้ข้อความต่อ ค่าที่จำไว้จะไม่ตรงกับที่เห็นในช่อง
  /// คืน (null, true) เมื่อช่องว่าง = ไม่กรอง และ (null, false) เมื่อพิมพ์ชื่อที่ไม่มี
  ({int? id, bool valid}) _resolveRoomTypeId() {
    final text = _roomTypeCtrl.text.trim();
    if (text.isEmpty) return (id: null, valid: true);
    for (final t in _roomTypes) {
      if (t.name.trim() == text) return (id: t.roomTypeId, valid: true);
    }
    return (id: null, valid: false);
  }

  Future<void> _search({int page = 0}) async {
    FocusScope.of(context).unfocus();

    final roomType = _resolveRoomTypeId();
    if (!roomType.valid) {
      setState(() {
        _searched = true;
        _results = [];
        _totalItems = 0;
        _totalPages = 0;
        _error =
            'ไม่พบประเภทห้องพัก "${_roomTypeCtrl.text.trim()}" '
            'กรุณาเลือกจากรายการ';
      });
      return;
    }

    setState(() {
      _searched = true;
      _loading = true;
      _error = null;
      _page = page;
    });
    try {
      final res = await widget.apiService.searchLodgingRooms(
        type: _roomType,
        roomNo: _roomNoCtrl.text,
        roomTypeId: roomType.id,
        contractName: _contractNameCtrl.text,
        departmentName: _departmentCtrl.text,
        bookTitle: _bookTitleCtrl.text,
        contractNumber: _contractNumberCtrl.text,
        startDate: _startDate == null ? null : _apiDate.format(_startDate!),
        stopDate: _stopDate == null ? null : _apiDate.format(_stopDate!),
        status: _status,
        page: page,
        size: _size,
      );
      if (!mounted) return;
      setState(() {
        _results = res['results'] as List<RoomSearchResult>;
        _totalItems = res['totalItems'] as int;
        _totalPages = res['totalPages'] as int;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error searching lodging rooms: $e');
      if (!mounted) return;
      setState(() {
        _error = _describeApiError(e, 'ค้นหา');
        _loading = false;
      });
    }
  }

  void _clear() {
    setState(() {
      _roomNoCtrl.clear();
      _roomTypeCtrl.clear();
      _contractNameCtrl.clear();
      _contractNumberCtrl.clear();
      _departmentCtrl.clear();
      _bookTitleCtrl.clear();
      _startDate = null;
      _stopDate = null;
      _status = null;
      _searched = false;
      _results = [];
      _error = null;
    });
  }

  static String _describeApiError(Object e, String what) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      String detail = '';
      if (data is Map) {
        detail = (data['message'] ?? data['error'] ?? '').toString();
      } else if (data is String && data.trim().isNotEmpty) {
        detail = data.trim();
      }
      if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
      return '$what ไม่สำเร็จ (HTTP ${code ?? '-'})'
          '${detail.isEmpty ? '' : '\n$detail'}';
    }
    return '$what ไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}';
  }

  /// เลือกวันที่ด้วยปฏิทินกลางของระบบ
  ///
  /// ใช้ [Util.dateFieldPickerNullable] เพราะช่องค้นหาว่างได้ — กดยกเลิกแล้ว
  /// ต้องไม่กลายเป็นกรองวันนี้โดยไม่ตั้งใจ ซึ่งจะเกิดถ้าใช้ dateFieldPicker ตรงๆ
  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _startDate : _stopDate;
    final picked = await Util.dateFieldPickerNullable(context, current);
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _stopDate = picked;
      }
    });
  }

  /// เปิดหน้ารายละเอียดการจอง — ทำงานเหมือนปุ่มรายละเอียดในหน้ารายการการจอง
  Future<void> _showBookingDetail(int bookId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (widget.authProvider.isLoggedIn) {
            return BookingDetailScreen(
              authProvider: widget.authProvider,
              apiService: widget.apiService,
              bookId: bookId,
            );
          }
          return NoAuthBookingDetailScreen(
            apiService: widget.apiService,
            bookId: bookId,
          );
        },
      ),
    );

    // หน้ารายละเอียดส่ง true กลับมาเมื่อลบหรือบันทึกสำเร็จ ผลค้นหาอาจเปลี่ยน
    if (result != true || !mounted) return;
    await _search(page: _page);
    // หน้าปัจจุบันว่างเพราะเพิ่งลบรายการสุดท้ายไป ถอยไปหน้าก่อนหน้า
    if (mounted && _results.isEmpty && _page > 0) {
      await _search(page: _page - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ค้นหาห้องพัก',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(_searchForm()),
                if (_searched) ...[
                  const SizedBox(height: 16),
                  _card(_resultSection()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // เงื่อนไขค้นหา
  // ---------------------------------------------------------------------------

  Widget _searchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            AppAutocompleteField<String>(
              label: 'หมายเลขห้อง',
              controller: _roomNoCtrl,
              options: _roomNos,
              loading: _loadingRoomNos,
              width: 240,
            ),
            _dateField('วันที่เริ่มต้น', _startDate, true),
            _dateField('วันที่สิ้นสุด', _stopDate, false),
            AppAutocompleteField<RoomTypeOption>(
              label: 'ประเภทห้องพัก',
              controller: _roomTypeCtrl,
              options: _roomTypes,
              displayStringForOption: (t) => t.name,
              loading: _loadingRoomTypes,
              width: 240,
            ),
            _textField('ชื่อผู้เข้าพัก', _contractNameCtrl, 240),
            _textField('โทรศัพท์', _contractNumberCtrl, 200),
            _textField('ชื่อหน่วยงาน', _departmentCtrl, 240),
            _textField('ชื่อหลักสูตร/โครงการ/เรื่อง', _bookTitleCtrl, 300),
            _statusField(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _clear,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('ล้าง'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : () => _search(),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('ค้นหา'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14),
        decoration: _input(label),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  /// ช่องวันที่ — กดเพื่อเลือก มีปุ่มกากบาทล้างค่าเมื่อเลือกไว้แล้ว
  Widget _dateField(String label, DateTime? value, bool isStart) {
    return SizedBox(
      width: 200,
      child: InkWell(
        onTap: () => _pickDate(isStart),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: _input(label).copyWith(
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today, size: 16)
                : IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    tooltip: 'ล้างวันที่',
                    onPressed: () => setState(() {
                      if (isStart) {
                        _startDate = null;
                      } else {
                        _stopDate = null;
                      }
                    }),
                  ),
          ),
          child: Text(
            value == null ? 'เลือกวันที่' : Util.formatThaiDate(value),
            style: TextStyle(
              fontSize: 14,
              color: value == null ? Colors.grey.shade500 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  /// สถานะ — ตัวเลือกแรกเป็นช่องว่างค่า null เพื่อให้เลือกกลับเป็น "ไม่กรอง" ได้
  Widget _statusField() {
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<int?>(
        initialValue: _status,
        key: ValueKey('status-$_status-${_statuses.length}'),
        isExpanded: true,
        decoration: _input('สถานะ'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('')),
          for (final s in _statuses)
            if (s.status != null)
              DropdownMenuItem<int?>(
                value: s.status,
                child: Text(
                  s.name ?? '-',
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
        onChanged: (v) => setState(() => _status = v),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ผลค้นหา
  // ---------------------------------------------------------------------------

  Widget _resultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.list_alt,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'ผลการค้นหา',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          _errorBanner(_error!)
        else if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_results.isEmpty)
          _empty()
        else
          _table(),
        const SizedBox(height: 12),
        AppPagination(
          currentPage: _page,
          totalPages: _totalPages,
          pageSize: _size,
          summary: 'ทั้งหมด $_totalItems รายการ',
          onPageChanged: (p) => _search(page: p),
          onPageSizeChanged: (s) {
            _size = s;
            _search();
          },
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: Colors.red.shade700)),
          ),
          TextButton(
            onPressed: () => _search(page: _page),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 34, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'ไม่พบข้อมูลตามเงื่อนไขที่ค้นหา',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  static String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v;

  Widget _table() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        // ตารางกว้างกว่าจอบนมือถือ ให้เลื่อนแนวนอนในกล่องตัวเอง
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            headingRowHeight: 52,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            columnSpacing: 22,
            horizontalMargin: 18,
            columns: const [
              DataColumn(label: _ColHead('หมายเลขห้อง')),
              DataColumn(label: _ColHead('ประเภทห้อง')),
              DataColumn(label: _ColHead('ชื่อ-สกุล')),
              DataColumn(label: _ColHead('เบอร์ติดต่อ')),
              DataColumn(label: _ColHead('วันที่เริ่มต้น')),
              DataColumn(label: _ColHead('วันที่สิ้นสุด')),
              DataColumn(label: _ColHead('สถานะ')),
              DataColumn(label: _ColHead('รายละเอียด')),
            ],
            rows: _results.map((r) {
              return DataRow(
                cells: [
                  DataCell(_cellText(_orDash(r.roomNo))),
                  DataCell(_cellText(_orDash(r.roomTypeName))),
                  DataCell(_cellText(_orDash(r.contractName1))),
                  DataCell(_cellText(_orDash(r.contractNumber1))),
                  DataCell(_cellText(Util.formatThaiDateStr(r.startDate))),
                  DataCell(_cellText(Util.formatThaiDateStr(r.stopDate))),
                  DataCell(_cellText(_orDash(r.statusName))),
                  DataCell(_detailButton(r)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String v) => Text(v, style: const TextStyle(fontSize: 14));

  /// ปุ่มรายละเอียด หน้าตาเดียวกับหน้ารายการการจอง
  Widget _detailButton(RoomSearchResult r) {
    final bookId = r.bookId;
    return Tooltip(
      message: 'รายละเอียดการจอง',
      child: ElevatedButton(
        onPressed: bookId == null ? null : () => _showBookingDetail(bookId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(50, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Icon(Icons.hotel, size: 20),
      ),
    );
  }
}

/// หัวคอลัมน์ของตารางผลค้นหา
class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
