// lib/screens/booking_list_screen.dart
import 'package:flutter/material.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/screens/no_auth_booking_detail_screen.dart';
import 'package:highway_training/screens/booking_detail_screen.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class BookingListScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService apiService;
  const BookingListScreen({
    super.key,
    required this.authProvider,
    required this.apiService,
  });

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  // Pagination
  int _currentPage = 0;
  int _pageSize = 5;
  int _totalItems = 0;
  int _totalPages = 0;

  // Data
  List<Bookroom> _bookings = [];
  List<DocumentStatus> _statusList = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  // Search Controllers
  final TextEditingController _bookIDCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _stopDateCtrl = TextEditingController();
  final TextEditingController _departmentCtrl = TextEditingController();
  final TextEditingController _booktitleCtrl = TextEditingController();

  // Search State
  int? _selectedStatusId;
  DateTime? _startDate;
  DateTime? _stopDate;

  @override
  void initState() {
    super.initState();
    _loadStatusList();
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

  Future<void> _loadStatusList() async {
    setState(() => _isLoading = true);
    try {
      final statuses = await widget.apiService.getDocumentStatusList();
      setState(() {
        _statusList = statuses;
        _isLoading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading status: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchBookings() async {
    setState(() {
      _isLoading = true;
      _isSearching = true;
      _error = null;
    });

    try {
      final response = await widget.apiService.searchBookings(
        bookID: _bookIDCtrl.text.isNotEmpty
            ? int.tryParse(_bookIDCtrl.text)
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
        page: _currentPage,
        size: _pageSize,
      );

      if (mounted) {
        setState(() {
          _bookings = (response['bookings'] as List)
              .map((j) => Bookroom.fromJson(j))
              .toList();
          _totalItems = response['totalItems'] ?? 0;
          _totalPages = response['totalPages'] ?? 0;
          _currentPage = response['currentPage'] ?? 0;
          _isSearching = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isSearching = false;
          _isLoading = false;
        });
        context.showErrorSnackBar(_error!);
      }
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
      _startDate = null;
      _stopDate = null;
      _currentPage = 0;
    });
    _searchBookings();
  }

  Future<void> _selectDate(
    TextEditingController controller,
    bool isStart,
  ) async {
    final initialDate = isStart
        ? _startDate ?? DateTime.now()
        : _stopDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('th', 'TH'),
    );
    if (picked != null) {
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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    // ✅ ปรับ maxContentWidth ให้กว้างขึ้น
    final maxContentWidth = isDesktop ? double.infinity : double.infinity;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายการการจอง',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  children: [
                    // Search Panel
                    _buildSearchPanel(isDesktop),
                    const Divider(height: 1),
                    // Result Panel
                    Expanded(
                      child: _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 64,
                                    color: Colors.red.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _searchBookings,
                                    child: const Text('ลองอีกครั้ง'),
                                  ),
                                ],
                              ),
                            )
                          : _buildResultTable(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSearchPanel(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Row 1
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSearchField(
                label: 'เลขที่จอง',
                controller: _bookIDCtrl,
                width: isDesktop ? 150 : 120,
                isNumber: true,
              ),
              _buildSearchDateField(
                label: 'วันที่เริ่มต้น',
                controller: _startDateCtrl,
                onTap: () => _selectDate(_startDateCtrl, true),
                width: isDesktop ? 160 : 130,
              ),
              _buildSearchDateField(
                label: 'วันที่สิ้นสุด',
                controller: _stopDateCtrl,
                onTap: () => _selectDate(_stopDateCtrl, false),
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
          // Row 2 - Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(child: _buildStatusDropdown()),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('ล้าง'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentPage = 0;
                  });
                  _searchBookings();
                },
                icon: const Icon(Icons.search, size: 18),
                label: const Text('ค้นหา'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required String label,
    required TextEditingController controller,
    double width = 150,
    bool isNumber = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        style: const TextStyle(fontSize: 14),
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
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            suffixIcon: const Icon(Icons.calendar_today, size: 16),
          ),
          child: Text(
            controller.text.isEmpty ? 'เลือกวันที่' : controller.text,
            style: TextStyle(
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

  Widget _buildStatusDropdown() {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedStatusId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'สถานะการจอง',
          labelStyle: const TextStyle(fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
        ),
        hint: const Text('ทั้งหมด'),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('ทั้งหมด')),
          ..._statusList.map((status) {
            return DropdownMenuItem<int>(
              value: status.statusId,
              child: Text(
                status.statusName ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedStatusId = value;
          });
        },
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildResultTable() {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'ไม่พบข้อมูลการจอง',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // ✅ ปรับความกว้างตามขนาดหน้าจอ
    final double tableWidth = isDesktop
        ? screenWidth *
              0.95 // 95% ของหน้าจอ
        : screenWidth * 0.98;

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: SizedBox(
            width: tableWidth,
            child: Row(
              children: [
                _buildHeader('เลขที่', flex: 1),
                _buildHeader('เรื่อง', flex: 3),
                _buildHeader('ชื่อหน่วยงาน', flex: 3),
                _buildHeader('วันที่เริ่มต้น', flex: 2),
                _buildHeader('วันที่สิ้นสุด', flex: 2),
                _buildHeader('ห้องกิจกรรม', flex: 1),
                _buildHeader('ห้องพัก', flex: 1),
                _buildHeader('สถานะ', flex: 1),
                _buildHeader('รายละเอียด', flex: 1),
              ],
            ),
          ),
        ),

        // Table Body
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: ListView.builder(
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final item = _bookings[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCell('${item.bookID}', flex: 1),
                          _buildMultiLineCell(item.booktitle ?? '-', flex: 3),
                          SizedBox(width: 10,),
                          _buildMultiLineCell(
                            item.departmentname ?? '-',
                            flex: 3,
                          ),
                          _buildCell(
                            item.startdate != null
                                ? Util.formatThaiDateStr(item.startdate)
                                : '-',
                            flex: 2,
                          ),
                          _buildCell(
                            item.stopdate != null
                                ? Util.formatThaiDateStr(item.stopdate)
                                : '-',
                            flex: 2,
                          ),
                          _buildColorCell(
                            item.c ?? '0',
                            flex: 1,
                            color: item.c_color == 'G'
                                ? Colors.green
                                : Colors.red,
                          ),
                          _buildColorCell(
                            item.r ?? '0',
                            flex: 1,
                            color: item.r_color == 'G'
                                ? Colors.green
                                : Colors.red,
                          ),
                          _buildMultiLineCell(item.statusName ?? '-', flex: 1),
                          SizedBox(
                            width: 70,
                            child: ElevatedButton(
                              onPressed: () {
                                _showBookingDetail(item.bookID!);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(50, 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.hotel, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Pagination
        _buildPagination(),
      ],
    );
  }

  // ✅ Header แบบ Flexible
  Widget _buildHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ✅ Cell แบบ Flexible
  Widget _buildCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ✅ Multi-line Cell แบบ Flexible
  Widget _buildMultiLineCell(
    String text, {
    required int flex,
    int maxLines = 3,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ✅ Color Cell แบบ Flexible
  Widget _buildColorCell(
    String text, {
    required int flex,
    required Color color,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalItems == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Size
          Row(
            children: [
              const Text('แสดง '),
              DropdownButton<int>(
                value: _pageSize,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _pageSize = value;
                      _currentPage = 0;
                    });
                    _searchBookings();
                  }
                },
              ),
              const Text(' รายการ'),
            ],
          ),

          // Page Info
          Text(
            '${_currentPage * _pageSize + 1} - '
            '${((_currentPage + 1) * _pageSize).clamp(0, _totalItems)} '
            'จาก $_totalItems รายการ',
            style: const TextStyle(fontSize: 13),
          ),

          // Page Controls
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                        _searchBookings();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${_currentPage + 1} / ${_totalPages == 0 ? 1 : _totalPages}',
                style: const TextStyle(fontSize: 13),
              ),
              IconButton(
                onPressed: _currentPage < _totalPages - 1
                    ? () {
                        setState(() => _currentPage++);
                        _searchBookings();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          } else {
            return NoAuthBookingDetailScreen(
              apiService: widget.apiService,
              bookId: bookId,
            );
          }
        },
      ),
    );

    // หน้ารายละเอียดส่ง true กลับมาเมื่อลบหรือบันทึกสำเร็จ (ปิดเฉยๆ จะได้ null)
    if (result != true || !mounted) return;

    await _searchBookings();

    // ถ้าหน้าปัจจุบันว่างเพราะเพิ่งลบรายการสุดท้ายไป ให้ถอยไปหน้าก่อนหน้า
    // เช็คจากผลลัพธ์จริงหลังโหลด จึงไม่ถอยหน้าผิดตอนที่แค่กดบันทึก
    if (mounted && _bookings.isEmpty && _currentPage > 0) {
      setState(() => _currentPage--);
      await _searchBookings();
    }
  }
}
