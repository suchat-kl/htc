// lib/screens/place_permit_report_screen.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:highway_training/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/employee.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/thai_date_picker.dart';
import 'package:highway_training/utils/logger.dart';

/// แบบขออนุญาตใช้สถานที่และบริการ — เมนูเดียวรวมสองแบบฟอร์ม
///
/// ข้อ 7.4 คำขอปรับปรุงรอบ ต.ค. 2569: ผู้ใช้เลือกใบจองแล้วกดพิมพ์
/// ระบบเลือกแบบฟอร์มเองตามประเภทใบจอง
/// - กองฝึก (A) / หน่วยราชการอื่น (B) / ใบเก่าที่ไม่ระบุประเภท → แบบฟอร์มโครงการ (place-project)
/// - รายย่อย (C) → แบบฟอร์มคณะบุคคล/รายย่อย (place-request)
///
/// พิมพ์ทีละใบจองเสมอ แม้ backend ของแบบฟอร์มรายย่อยจะพิมพ์ได้หลายใบตามเงื่อนไขค้นหา
/// เพราะผลค้นหาปนทั้งสองประเภท ถ้าส่งเงื่อนไขไปทั้งชุด ใบโครงการจะถูกพิมพ์ลงแบบรายย่อยไปด้วย
class PlacePermitReportScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService apiService;
  const PlacePermitReportScreen({
    super.key,
    required this.authProvider,
    required this.apiService,
  });

  @override
  State<PlacePermitReportScreen> createState() =>
      _PlacePermitReportScreenState();
}

class _PlacePermitReportScreenState extends State<PlacePermitReportScreen> {
  /// ฟอนต์ไทยของทั้งหน้า ชุดเดียวกับธีม
  static const String _font = 'NotoSansThai';

  // Pagination
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalItems = 0;
  int _totalPages = 0;

  // Data
  List<Bookroom> _bookings = [];
  List<DocumentStatus> _statusList = [];
  bool _isSearching = false;

  /// เลขใบจองที่กำลังออกแบบฟอร์มอยู่ (null = ไม่มี) ใช้ล็อกปุ่มพิมพ์กันกดซ้ำ
  int? _printingId;
  bool get _printing => _printingId != null;

  /// ผู้รับแจ้งท้ายแบบฟอร์ม — ชื่อไทยของผู้ใช้ที่ล็อกอิน ชุดเดียวกับหน้ารับชำระเงิน
  String? _recorderName;
  String? _error;

  // Search Controllers
  final TextEditingController _bookIDCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _stopDateCtrl = TextEditingController();
  final TextEditingController _departmentCtrl = TextEditingController();
  final TextEditingController _booktitleCtrl = TextEditingController();

  // Search State
  int? _selectedStatusId;
  String? _bookingtype;
  DateTime? _startDate;
  DateTime? _stopDate;

  @override
  void initState() {
    super.initState();
    _loadStatusList();
    _loadRecorderName();
    _searchBookings();
  }

  @override
  void dispose() {
    _bookIDCtrl.dispose();
    _startDateCtrl.dispose();
    _stopDateCtrl.dispose();
    _departmentCtrl.dispose();
    _booktitleCtrl.dispose();
    super.dispose();
  }

  // ── ประเภทใบจอง → แบบฟอร์ม ───────────────────────────────────

  /// รายย่อย (C) ใช้แบบฟอร์มรายย่อย ที่เหลือรวมใบที่ไม่ระบุประเภทใช้แบบฟอร์มโครงการ
  /// (ใบเก่าที่ไม่ระบุประเภท ระบบนับเป็นกองฝึกเหมือนหน้าค้นหาการจอง)
  static bool _isIndividual(Bookroom b) => b.bookingtype == 'C';

  static String _typeName(Bookroom b) => switch (b.bookingtype) {
    'B' => 'หน่วยราชการอื่น',
    'C' => 'รายย่อย',
    _ => 'กองฝึก กรมทางหลวง',
  };

  static String _formName(Bookroom b) =>
      _isIndividual(b) ? 'แบบฟอร์มรายย่อย' : 'แบบฟอร์มโครงการ';

  /// ใบที่ยกเลิกการจองแล้วไม่ออกแบบขออนุญาต — backend ของแบบรายย่อยก็ตัดใบยกเลิกทิ้งอยู่แล้ว
  static bool _isCancelled(Bookroom b) =>
      (b.statusName ?? '').contains('ยกเลิก');

  // ── โหลดข้อมูล ───────────────────────────────────────────────

  Future<void> _loadStatusList() async {
    try {
      final statuses = await widget.apiService.getDocumentStatusList();
      if (!mounted) return;
      setState(() => _statusList = statuses);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading status: $e');
    }
  }

  /// ชื่อผู้รับแจ้งท้ายแบบฟอร์ม — เทียบรหัสผู้ใช้กับรายชื่อพนักงานให้ได้ชื่อไทยเต็ม
  /// แบบเดียวกับหน้าแบบขออนุญาตเดิม ไม่ใช่ชื่อผู้ใช้ตอนล็อกอิน
  Future<void> _loadRecorderName() async {
    final empId = widget.authProvider.empID;
    String? name = widget.authProvider.fullName;
    if (empId != null) {
      try {
        final List<Employee> emps = await widget.apiService.getEmployeesList();
        for (final e in emps) {
          if (e.empID == empId) {
            final full = '${e.name ?? ''} ${e.lastname ?? ''}'.trim();
            if (full.isNotEmpty) name = full;
            break;
          }
        }
      } catch (e) {
        if (AppLogger.on) AppLogger.d('Error loading employees: $e');
      }
    }
    if (!mounted) return;
    setState(() => _recorderName = name);
  }

  Future<void> _searchBookings() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final response = await widget.apiService.searchBookings(
        bookID: _bookIDCtrl.text.trim().isNotEmpty
            ? int.tryParse(_bookIDCtrl.text.trim())
            : null,
        startdate: _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        stopdate: _stopDate != null
            ? DateFormat('yyyy-MM-dd').format(_stopDate!)
            : null,
        departmentname: _departmentCtrl.text.isNotEmpty
            ? _departmentCtrl.text
            : null,
        booktitle: _booktitleCtrl.text.isNotEmpty ? _booktitleCtrl.text : null,
        status: _selectedStatusId,
        bookingtype: _bookingtype,
        page: _currentPage,
        size: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _bookings = (response['bookings'] as List)
            .map((j) => Bookroom.fromJson(j))
            .toList();
        _totalItems = response['totalItems'] ?? 0;
        _totalPages = response['totalPages'] ?? 0;
        _currentPage = response['currentPage'] ?? 0;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSearching = false;
      });
      context.showErrorSnackBar(_error!);
    }
  }

  void _clearSearch() {
    setState(() {
      _bookIDCtrl.clear();
      _startDateCtrl.clear();
      _stopDateCtrl.clear();
      _departmentCtrl.clear();
      _booktitleCtrl.clear();
      _selectedStatusId = null;
      _bookingtype = null;
      _startDate = null;
      _stopDate = null;
      _currentPage = 0;
    });
    _searchBookings();
  }

  Future<void> _selectDate(bool isStart) async {
    final initialDate = isStart
        ? _startDate ?? DateTime.now()
        : _stopDate ?? DateTime.now();
    final picked = await showThaiDatePicker(
      context,
      initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2037, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateCtrl.text = Util.formatThaiDate(picked);
      } else {
        _stopDate = picked;
        _stopDateCtrl.text = Util.formatThaiDate(picked);
      }
    });
  }

  // ── พิมพ์ ─────────────────────────────────────────────────────

  /// กรอกเลขที่จองแล้วพิมพ์ได้ทันที ไม่ต้องกดค้นหาก่อน
  /// ดึงใบจองมาดูประเภทก่อน แล้วจึงเลือกแบบฟอร์ม
  Future<void> _printByBookId() async {
    final id = int.tryParse(_bookIDCtrl.text.trim());
    if (id == null) {
      context.showErrorSnackBar('กรุณากรอกเลขที่จองเป็นตัวเลข');
      return;
    }

    setState(() => _printingId = id);
    Bookroom? booking;
    try {
      final response = await widget.apiService.searchBookings(
        bookID: id,
        page: 0,
        size: 1,
      );
      final list = response['bookings'] as List? ?? const [];
      if (list.isNotEmpty) booking = Bookroom.fromJson(list.first);
    } catch (e) {
      if (!mounted) return;
      setState(() => _printingId = null);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      return;
    }
    if (!mounted) return;
    setState(() => _printingId = null);

    if (booking == null) {
      context.showErrorSnackBar('ไม่พบใบจองเลขที่ $id');
      return;
    }
    await _printOne(booking);
  }

  /// ถามรูปแบบไฟล์แล้วออกแบบขออนุญาตของใบจองนั้น เลือกแบบฟอร์มตามประเภทใบจอง
  Future<void> _printOne(Bookroom b) async {
    final bookId = b.bookID;
    if (bookId == null) return;
    if (_isCancelled(b)) {
      context.showErrorSnackBar(
        'ใบจองเลขที่ $bookId ยกเลิกการจองแล้ว ออกแบบขออนุญาตไม่ได้',
      );
      return;
    }

    final format = await _askFormat(b);
    if (format == null || !mounted) return;

    final individual = _isIndividual(b);
    final signer = _recorderName ?? widget.authProvider.fullName;

    setState(() => _printingId = bookId);
    try {
      final bytes = individual
          // ส่งแค่เลขใบจอง เงื่อนไขอื่นต้องว่าง ไม่งั้น backend จะกรองตามช่องค้นหาด้วย
          ? await widget.apiService.downloadPlaceRequestReport(
              bookID: bookId,
              format: format,
              signerName: signer,
            )
          : await widget.apiService.downloadPlaceProjectReport(
              bookId: bookId,
              format: format,
              signerName: signer,
            );

      final isPdf = format == 'pdf';
      _saveFile(
        bytes,
        isPdf: isPdf,
        fileName:
            '${individual ? 'แบบขออนุญาตรายย่อย' : 'แบบขออนุญาตโครงการ'}'
            '_$bookId.${isPdf ? 'pdf' : 'xlsx'}',
      );

      if (!mounted) return;
      setState(() => _printingId = null);
      context.showSuccessSnackBar(
        'ออกแบบขออนุญาตใบจองเลขที่ $bookId เรียบร้อย',
      );
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error printing place permit $bookId: $e');
      if (!mounted) return;
      setState(() => _printingId = null);
      final msg = e is DioException
          ? 'ออกแบบขออนุญาตไม่สำเร็จ'
                '${e.response?.statusCode != null ? ' (${e.response!.statusCode})' : ''}'
          : e.toString().replaceAll('Exception: ', '');
      context.showErrorSnackBar(msg);
    }
  }

  void _saveFile(
    List<int> bytes, {
    required bool isPdf,
    required String fileName,
  }) {
    final mime = isPdf
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    final blob = html.Blob([Uint8List.fromList(bytes)], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);
    anchor.click();
    Future.delayed(const Duration(seconds: 1), () {
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    });
  }

  /// เลือกรูปแบบไฟล์ พร้อมบอกว่าใบจองนี้จะออกเป็นแบบฟอร์มใด
  Future<String?> _askFormat(Bookroom b) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'พิมพ์แบบขออนุญาต ใบจองเลขที่ ${b.bookID}',
          style: const TextStyle(fontFamily: _font, fontSize: 18),
        ),
        content: Text(
          'ใบจองประเภท ${_typeName(b)} จะออกเป็น${_formName(b)}\n'
          'ต้องการไฟล์แบบใด',
          style: const TextStyle(fontFamily: _font, fontSize: 15),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(fontFamily: _font)),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'xlsx'),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Excel', style: TextStyle(fontFamily: _font)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.addColor,
              side: const BorderSide(color: AppTheme.addColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'pdf'),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF', style: TextStyle(fontFamily: _font)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.printColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── หน้าจอ ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'แบบขออนุญาตใช้สถานที่และบริการ',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Column(
        children: [
          _buildSearchPanel(isDesktop),
          const Divider(height: 1),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildResultTable(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _searchBookings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'ลองอีกครั้ง',
              style: TextStyle(fontFamily: _font),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      color: AppTheme.fieldFillColor,
      child: Column(
        children: [
          const Text(
            'กรอกเลขที่จองแล้วกด "พิมพ์ตามเลขที่จอง" หรือค้นหาแล้วกดพิมพ์ท้ายแถว '
            'ระบบเลือกแบบฟอร์มให้เอง: กองฝึก/หน่วยราชการอื่น = แบบฟอร์มโครงการ, '
            'รายย่อย = แบบฟอร์มรายย่อย',
            style: TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildSearchField(
                label: 'เลขที่จอง',
                controller: _bookIDCtrl,
                width: isDesktop ? 150 : 120,
                isNumber: true,
                onSubmitted: (_) => _printByBookId(),
              ),
              ElevatedButton.icon(
                onPressed: _printing ? null : _printByBookId,
                icon: _printing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print, size: 18),
                label: const Text(
                  'พิมพ์ตามเลขที่จอง',
                  style: TextStyle(fontFamily: _font),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.printColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              _buildSearchDateField(
                label: 'วันที่เริ่มต้น',
                controller: _startDateCtrl,
                onTap: () => _selectDate(true),
                width: isDesktop ? 160 : 130,
              ),
              _buildSearchDateField(
                label: 'วันที่สิ้นสุด',
                controller: _stopDateCtrl,
                onTap: () => _selectDate(false),
                width: isDesktop ? 160 : 130,
              ),
              _buildSearchField(
                label: 'ชื่อหน่วยงาน',
                controller: _departmentCtrl,
                width: isDesktop ? 180 : 140,
              ),
              _buildSearchField(
                label: 'ชื่อหลักสูตร/โครงการ',
                controller: _booktitleCtrl,
                width: isDesktop ? 200 : 150,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTypeDropdown(),
              _buildStatusDropdown(),
              ElevatedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('ล้าง', style: TextStyle(fontFamily: _font)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neutralColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _currentPage = 0);
                  _searchBookings();
                },
                icon: const Icon(Icons.search, size: 18),
                label: const Text('ค้นหา', style: TextStyle(fontFamily: _font)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.searchColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: _font, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildSearchField({
    required String label,
    required TextEditingController controller,
    double width = 150,
    bool isNumber = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onSubmitted: onSubmitted,
        decoration: _decoration(label),
        style: const TextStyle(fontFamily: _font, fontSize: 14),
      ),
    );
  }

  Widget _buildSearchDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    double width = 160,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: _decoration(
            label,
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
          ),
          child: Text(
            controller.text.isEmpty ? 'เลือกวันที่' : controller.text,
            style: TextStyle(
              fontFamily: _font,
              fontSize: 14,
              color: controller.text.isEmpty
                  ? Colors.grey.shade500
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    const style = TextStyle(fontFamily: _font, fontSize: 14);
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: _bookingtype,
        isExpanded: true,
        decoration: _decoration('ประเภทการจอง'),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('ทั้งหมด', style: style),
          ),
          DropdownMenuItem<String?>(
            value: 'A',
            child: Text(
              'กองฝึก กรมทางหลวง',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<String?>(
            value: 'B',
            child: Text(
              'หน่วยราชการอื่น',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<String?>(
            value: 'C',
            child: Text('รายย่อย', style: style),
          ),
        ],
        onChanged: (value) => setState(() => _bookingtype = value),
        style: style.copyWith(color: Colors.black87),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    const style = TextStyle(fontFamily: _font, fontSize: 14);
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedStatusId,
        isExpanded: true,
        decoration: _decoration('สถานะการจอง'),
        hint: const Text('ทั้งหมด', style: style),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('ทั้งหมด', style: style),
          ),
          ..._statusList.map(
            (status) => DropdownMenuItem<int>(
              value: status.statusId,
              child: Text(
                status.statusName ?? '',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedStatusId = value),
        style: style.copyWith(color: Colors.black87),
      ),
    );
  }

  /// ความกว้างคอลัมน์ปุ่มพิมพ์ ใช้ทั้งหัวตารางและแถว ให้เส้นตรงกัน
  static const double _printColWidth = 150;

  Widget _buildResultTable(bool isDesktop) {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'ไม่พบข้อมูลการจอง',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // จอแคบเลื่อนตารางแนวนอนได้ ไม่บีบคอลัมน์จนอ่านไม่ออก
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 1000
            ? 1000.0
            : constraints.maxWidth;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _buildHeaderRow(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) =>
                              _buildRow(_bookings[index]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildPagination(),
          ],
        );
      },
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor,
      child: Row(
        children: [
          _headerCell('เลขที่', flex: 1),
          _headerCell('ประเภท', flex: 2),
          _headerCell('เรื่อง/ผู้จอง', flex: 4),
          _headerCell('ชื่อหน่วยงาน', flex: 3),
          _headerCell('วันที่เริ่มต้น', flex: 2),
          _headerCell('วันที่สิ้นสุด', flex: 2),
          _headerCell('สถานะ', flex: 2),
          const SizedBox(
            width: _printColWidth,
            child: Text(
              'พิมพ์แบบฟอร์ม',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _font,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Bookroom item) {
    final individual = _isIndividual(item);
    final cancelled = _isCancelled(item);
    final busy = _printingId == item.bookID;
    // รายย่อยมักไม่มีชื่อเรื่อง แสดงชื่อผู้จองแทน
    final title = (item.booktitle ?? '').trim().isNotEmpty
        ? item.booktitle!
        : (item.contractname1 ?? '-');

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell('${item.bookID ?? '-'}', flex: 1),
          _cell(_typeName(item), flex: 2, maxLines: 2),
          _cell(title, flex: 4, maxLines: 3),
          _cell(item.departmentname ?? '-', flex: 3, maxLines: 3),
          _cell(
            item.startdate != null
                ? Util.formatThaiDateStr(item.startdate)
                : '-',
            flex: 2,
          ),
          _cell(
            item.stopdate != null ? Util.formatThaiDateStr(item.stopdate) : '-',
            flex: 2,
          ),
          _cell(item.statusName ?? '-', flex: 2, maxLines: 2),
          SizedBox(
            width: _printColWidth,
            child: Center(
              child: Tooltip(
                message: cancelled
                    ? 'ใบจองยกเลิกแล้ว'
                    : 'ออกเป็น${_formName(item)}',
                child: ElevatedButton.icon(
                  onPressed: _printing || cancelled
                      ? null
                      : () => _printOne(item),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print, size: 16),
                  label: Text(
                    individual ? 'รายย่อย' : 'โครงการ',
                    style: const TextStyle(fontFamily: _font, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.printColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(50, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: _font,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _cell(String text, {required int flex, int maxLines = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          text,
          style: const TextStyle(fontFamily: _font, fontSize: 14),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// แถบแบ่งหน้ามาตรฐาน — ดึงข้อมูลทีละหน้าจาก API จึงต้องค้นหาใหม่ทุกครั้ง
  Widget _buildPagination() {
    if (_totalItems == 0) return const SizedBox();

    final from = _currentPage * _pageSize + 1;
    final to = ((_currentPage + 1) * _pageSize).clamp(0, _totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: AppPagination(
        currentPage: _currentPage,
        totalPages: _totalPages == 0 ? 1 : _totalPages,
        pageSize: _pageSize,
        summary: '$from - $to จาก $_totalItems รายการ',
        onPageChanged: (p) {
          setState(() => _currentPage = p);
          _searchBookings();
        },
        onPageSizeChanged: (s) {
          setState(() {
            _pageSize = s;
            _currentPage = 0;
          });
          _searchBookings();
        },
      ),
    );
  }
}
