// lib/screens/my_bookings_screen.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/bookroom.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/payment_slip_upload_section.dart';
import '../widgets/thaid_login_card.dart';
import 'booking_edit_screen.dart';

const String _font = 'NotoSansThai';

/// ชื่อประเภทผู้จอง ใบที่ไม่ได้ระบุประเภทนับเป็นกองฝึก (เหมือนหน้ารายการการจอง)
String _bookingtypeName(String? t) => switch (t) {
  'B' => 'หน่วยราชการอื่น',
  'C' => 'รายย่อย',
  _ => 'กองฝึก กรมทางหลวง',
};

String _dateRange(Bookroom b) {
  final a = b.startdate;
  final z = b.stopdate;
  if (a == null || a.isEmpty) return '-';
  if (z == null || z.isEmpty || z == a) return Util.formatThaiDateStr(a);
  return '${Util.formatThaiDateStr(a)} - ${Util.formatThaiDateStr(z)}';
}

/// ใบจองของฉัน — ผู้จองที่เข้าสู่ระบบด้วย ThaID เห็นเฉพาะใบจองของตัวเอง
///
/// แทนหน้าตรวจสอบสถานะการจองเดิม (กรอกเลขใบจอง + เลขบัตรโดยไม่ล็อกอิน) ตั้งแต่ พ.ย. 2569
/// รายการมาจาก searchBookings ซึ่ง backend กรองให้เหลือใบที่เลขบัตรตรงกับบัญชีที่ล็อกอิน
/// หน้าเว็บไม่ส่งเลขบัตรเอง และห้าม log เลขบัตร
///
/// บัญชีเจ้าหน้าที่ใช้เมนู "รายการการจอง" แทน (backend คืนใบจองทั้งหมดให้เจ้าหน้าที่
/// หน้านี้จึงไม่แสดงรายการให้ ไม่งั้นจะเห็นใบจองของคนอื่นปนอยู่ในหน้า "ของฉัน")
class MyBookingsScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;

  const MyBookingsScreen({
    super.key,
    required this.apiService,
    required this.authProvider,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Bookroom> _bookings = [];
  int _page = 0;
  int _pageSize = 10;
  int _totalItems = 0;
  int _totalPages = 0;
  bool _loading = false;
  String? _error;

  /// สถานะล็อกอินครั้งก่อน ใช้ดูว่าเพิ่งเข้า/ออกจากระบบ
  bool _wasLoggedIn = false;

  bool get _canList =>
      widget.authProvider.isLoggedIn && !widget.authProvider.isStaff;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = widget.authProvider.isLoggedIn;
    widget.authProvider.addListener(_onAuthChanged);
    if (_canList) _load();
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final now = widget.authProvider.isLoggedIn;
    if (now && !_wasLoggedIn) {
      // เพิ่งเข้าสู่ระบบ: เริ่มโหลดหน้าแรก
      _wasLoggedIn = true;
      _page = 0;
      if (_canList) {
        _load();
        return;
      }
    } else if (!now && _wasLoggedIn) {
      // ออกจากระบบ: ล้างรายการทิ้งทันที ไม่ให้ใบจองของบัญชีเดิมค้างบนจอ
      _wasLoggedIn = false;
      _bookings = [];
      _totalItems = 0;
      _totalPages = 0;
      _error = null;
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.apiService.searchBookings(
        page: _page,
        size: _pageSize,
      );
      if (!mounted) return;
      // ระหว่างรอผลอาจออกจากระบบไปแล้ว ไม่แสดงผลที่ค้างมา
      if (!widget.authProvider.isLoggedIn) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _bookings = ((r['bookings'] as List?) ?? const [])
            .map((j) => Bookroom.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _totalItems = (r['totalItems'] as num?)?.toInt() ?? 0;
        _totalPages = (r['totalPages'] as num?)?.toInt() ?? 0;
        _page = (r['currentPage'] as num?)?.toInt() ?? _page;
        _loading = false;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.w('โหลดใบจองของฉันไม่สำเร็จ: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Bookroom b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MyBookingDetailScreen(
          apiService: widget.apiService,
          authProvider: widget.authProvider,
          booking: b,
        ),
      ),
    );
    // อาจแก้ใบจองมา สถานะ/วันที่เปลี่ยนได้ โหลดหน้าปัจจุบันใหม่
    if (mounted && _canList) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'ใบจองของฉัน',
          style: TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_canList)
            IconButton(
              tooltip: 'โหลดใหม่',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final auth = widget.authProvider;
    if (!auth.isLoggedIn) {
      return SingleChildScrollView(
        child: ThaidLoginCard(
          authProvider: auth,
          title: 'กรุณาเข้าสู่ระบบด้วย ThaID',
          message:
              'ดูใบจองของท่าน สถานะการจอง ออกใบ Pay-in และแนบหลักฐานการชำระเงิน '
              'ได้หลังเข้าสู่ระบบด้วย ThaID ระบบแสดงเฉพาะใบจองที่ใช้เลขบัตรประชาชนของท่าน',
        ),
      );
    }
    if (auth.isStaff) {
      return _messageCard(
        Icons.badge_outlined,
        'บัญชีเจ้าหน้าที่ดูใบจองได้ที่เมนู "รายการการจอง"',
      );
    }
    if (_loading && _bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _bookings.isEmpty) {
      return _messageCard(Icons.error_outline, _error!, retry: true);
    }
    if (_bookings.isEmpty) {
      return _messageCard(
        Icons.inbox_outlined,
        'ยังไม่มีใบจองที่ใช้เลขบัตรประชาชนของท่าน\n'
        'จองห้องได้ที่เมนู "จอง"',
      );
    }

    final from = _page * _pageSize + 1;
    final to = ((_page + 1) * _pageSize).clamp(0, _totalItems);
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _bookings.length,
            itemBuilder: (_, i) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _bookingTile(_bookings[i]),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: AppPagination(
            currentPage: _page,
            totalPages: _totalPages == 0 ? 1 : _totalPages,
            pageSize: _pageSize,
            summary: '$from - $to จาก $_totalItems รายการ',
            onPageChanged: (p) {
              setState(() => _page = p);
              _load();
            },
            onPageSizeChanged: (s) {
              setState(() {
                _pageSize = s;
                _page = 0;
              });
              _load();
            },
          ),
        ),
      ],
    );
  }

  Widget _bookingTile(Bookroom b) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(b),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.assignment, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ใบจองเลขที่ ${b.bookID ?? '-'}',
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_bookingtypeName(b.bookingtype)} · ${_dateRange(b)}',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(b.statusName),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageCard(IconData icon, String text, {bool retry = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: Colors.grey.shade500),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (retry) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'ลองใหม่',
                        style: TextStyle(fontFamily: _font),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _statusChip(String? name) {
  final text = (name == null || name.isEmpty) ? '-' : name;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryPale,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: _font,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryDark,
      ),
    ),
  );
}

/// รายละเอียดใบจองของฉันแบบย่อ: สถานะ + ปุ่มแก้ไข + ส่วนชำระเงิน (รายย่อย)
class _MyBookingDetailScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthProvider authProvider;
  final Bookroom booking;

  const _MyBookingDetailScreen({
    required this.apiService,
    required this.authProvider,
    required this.booking,
  });

  @override
  State<_MyBookingDetailScreen> createState() => _MyBookingDetailScreenState();
}

class _MyBookingDetailScreenState extends State<_MyBookingDetailScreen> {
  late Bookroom _booking = widget.booking;

  /// เปลี่ยนทุกครั้งที่กลับจากหน้าแก้ไข ให้ส่วนชำระเงินโหลดยอดใหม่
  int _reloadSeq = 0;

  @override
  void initState() {
    super.initState();
    widget.authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// ออกจากระบบระหว่างเปิดหน้านี้: ถอดหน้ารายละเอียดทิ้ง ไม่ให้ข้อมูลใบจองค้างบนจอ
  /// ใช้ removeRoute เพราะอาจมีหน้าแก้ไขซ้อนอยู่ข้างบน (pop จะไปปิดหน้านั้นแทน)
  void _onAuthChanged() {
    if (!mounted || widget.authProvider.isLoggedIn) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingEditScreen(
          apiService: widget.apiService,
          booking: _booking,
          authProvider: widget.authProvider,
        ),
      ),
    );
    if (!mounted || !widget.authProvider.isLoggedIn) return;
    await _refresh();
  }

  /// อ่านใบจองนี้ใหม่จาก backend (backend ยังกรองเฉพาะใบของบัญชีนี้)
  Future<void> _refresh() async {
    final id = _booking.bookID;
    if (id == null) return;
    try {
      final r = await widget.apiService.searchBookings(
        bookID: id,
        page: 0,
        size: 1,
      );
      final list = (r['bookings'] as List?) ?? const [];
      if (!mounted || list.isEmpty) return;
      setState(() {
        _booking = Bookroom.fromJson(
          Map<String, dynamic>.from(list.first as Map),
        );
        _reloadSeq++;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.w('โหลดใบจองใหม่ไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final isSmall = b.bookingtype == 'C';
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'ใบจองเลขที่ ${b.bookID ?? '-'}',
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _statusCard(b, isSmall),
                ),
              ),
            ),
            // ส่วนชำระเงินจัดความกว้างและระยะขอบของตัวเองอยู่แล้ว
            if (isSmall && b.bookID != null)
              PaymentSlipUploadSection(
                key: ValueKey('pay-${b.bookID}-$_reloadSeq'),
                apiService: widget.apiService,
                bookId: b.bookID!,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(Bookroom b, bool isSmall) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะปัจจุบัน',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (b.statusName == null || b.statusName!.isEmpty)
                        ? '-'
                        : b.statusName!,
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row('ประเภทผู้จอง', _bookingtypeName(b.bookingtype)),
            _row('ช่วงวันที่', _dateRange(b)),
            if ((b.contractname1 ?? '').isNotEmpty)
              _row('ชื่อผู้จอง', b.contractname1!),
            if (!isSmall) ...[
              const SizedBox(height: 8),
              Text(
                'ใบจองประเภทนี้ชำระค่าใช้จ่ายตามขั้นตอนของหน่วยงาน '
                'สอบถามรายละเอียดได้ที่เจ้าหน้าที่ศูนย์ฯ',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit),
                label: Text(
                  isSmall ? 'แก้ไขใบจอง' : 'แก้ไขใบจอง/รายการอาหาร',
                  style: const TextStyle(fontFamily: _font, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.editColor,
                  foregroundColor: AppTheme.onSecondaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: _font, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
