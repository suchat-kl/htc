import 'package:flutter/material.dart';
import 'package:highway_training/utils/dialog.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/tfood.dart';
import '../models/foodtype.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/thaid.dart';
import '../utils/util.dart';
import '../widgets/thaid_login_card.dart';
import 'package:highway_training/utils/logger.dart';

/// หน้าจอง (เพิ่ม/แก้ไขใบจอง และรายการอาหาร)
///
/// ต้องเข้าสู่ระบบก่อนเสมอ (พ.ย. 2569): ยังไม่เข้าสู่ระบบแสดงการ์ดให้เข้าด้วย ThaID แทนฟอร์ม
/// ผู้จองที่ไม่ใช่เจ้าหน้าที่ ([ApiService.isStaff] = false): เลขบัตรเติมจากบัญชีและแก้ไม่ได้
/// backend บังคับเลขบัตรของใบจองเป็นเลขบัตรของบัญชีอีกชั้น เจ้าหน้าที่ใช้ฟอร์มแบบเดิม
class BookingEditScreen extends StatefulWidget {
  final ApiService apiService;
  final Bookroom? booking;

  /// ใช้ฟังสถานะล็อกอินและเรียกเข้าสู่ระบบด้วย ThaID จากการ์ดในหน้านี้
  /// ไม่ส่งมา = หน้าจอยังกันคนไม่ล็อกอินได้ แต่ต้องกดปุ่ม ThaID ที่แถบบนเอง
  final AuthProvider? authProvider;

  const BookingEditScreen({
    super.key,
    required this.apiService,
    this.booking,
    this.authProvider,
  });

  @override
  State<BookingEditScreen> createState() => _BookingEditScreenState();
}

class _BookingEditScreenState extends State<BookingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  // ✅ ตัวแปรสำหรับเก็บข้อมูลการจองที่สามารถเปลี่ยนแปลงได้
  Bookroom? _currentBooking;
  // Controllers
  final _booktitleCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _contractNameCtrl = TextEditingController();
  final _contractNumberCtrl = TextEditingController();
  final _numberMemberCtrl = TextEditingController();
  final _idcardCtrl = TextEditingController();
  final _numberStaffCtrl = TextEditingController();
  final _bookRemarkCtrl = TextEditingController();

  // State
  String _bookingtype = 'A';
  bool _requestRoom = false;
  bool _requestConference = false;

  /// เลขบัตรที่ได้จากการยืนยันตัวตนด้วย ThaID ถ้าผู้ใช้แก้เลขบัตรเองป้ายยืนยันจะหายไป
  String? _thaidPid;
  String? _thaidAddress;
  bool _thaidBusy = false;

  bool get _thaidVerified =>
      _thaidPid != null && _idcardCtrl.text.replaceAll(' ', '') == _thaidPid;

  /// ยืนยันตัวตนผู้จองรายย่อยด้วย ThaID แล้วเติมเลขบัตรและชื่อ-สกุลให้
  Future<void> _verifyWithThaid() async {
    setState(() => _thaidBusy = true);
    try {
      final id = await verifyWithThaid(widget.apiService);
      if (!mounted) return;
      if (id == null) {
        context.showInfoSnackBar(thaidCancelledMessage);
        return;
      }
      setState(() {
        _thaidPid = id.pid;
        _thaidAddress = id.address;
        _idcardCtrl.text = id.pid;
        if (id.fullName.isNotEmpty) _contractNameCtrl.text = id.fullName;
      });
      context.showSuccessSnackBar(
        'ยืนยันตัวตนด้วย ThaID แล้ว เติมเลขบัตรและชื่อให้เรียบร้อย',
      );
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _thaidBusy = false);
    }
  }

  Widget _thaidPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryPale,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _thaidBusy ? null : _verifyWithThaid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: _thaidBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user, size: 18),
                label: const Text(
                  'ยืนยันตัวตนด้วย ThaID',
                  style: TextStyle(fontFamily: 'NotoSansThai'),
                ),
              ),
              if (_thaidVerified)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'ยืนยันตัวตนแล้ว',
                      style: TextStyle(
                        fontFamily: 'NotoSansThai',
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // คู่มือ ThaID ข้อ 2.3 ให้แจ้งวัตถุประสงค์การใช้ข้อมูลกับผู้ใช้ให้ชัดเจน
          const Text(
            'สแกน QR ด้วยแอป ThaID เพื่อเติมเลขบัตรประชาชนและชื่อ-สกุลให้อัตโนมัติ '
            'ระบบใช้เลขบัตร ชื่อ-สกุล และที่อยู่ตามหน้าบัตร เฉพาะในใบจอง '
            'ใบแจ้งการชำระเงิน (Pay-in) และใบเสร็จเท่านั้น หรือจะกรอกเองก็ได้',
            style: TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ป้ายแทนแผงยืนยัน ThaID สำหรับผู้จองที่ไม่ใช่เจ้าหน้าที่ ซึ่งเข้าสู่ระบบมาแล้ว
  /// เลขบัตรมาจากบัญชีที่เข้าสู่ระบบ จึงไม่ต้องสแกน ThaID ซ้ำในฟอร์ม
  Widget _bookerVerifiedBadge() {
    final viaThaid = widget.apiService.isThaidLogin;
    final hasId = _idcardCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            viaThaid ? Icons.verified_user : Icons.badge_outlined,
            color: AppTheme.successColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viaThaid
                      ? 'ยืนยันตัวตนด้วย ThaID แล้ว'
                      : 'ใช้ข้อมูลผู้จองตามบัญชีที่เข้าสู่ระบบ',
                  style: const TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasId
                      ? 'เลขบัตรประชาชนของใบจองใช้เลขบัตรของบัญชีที่เข้าสู่ระบบ แก้ไขไม่ได้ '
                            'ชื่อ-สกุลผู้จองแก้ไขได้'
                      : 'บัญชีนี้ยังไม่มีเลขบัตรประชาชน '
                            'กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่ด้วย ThaID ก่อนจอง',
                  style: const TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ใบจองรายย่อย (C) ขอใช้ได้เฉพาะห้องพัก
  /// ติ๊กห้องพักไว้ให้ตั้งแต่ต้น และล้างห้องกิจกรรมที่อาจติ๊กค้างไว้จากประเภทเดิม
  void _applyLodgingOnly() {
    _requestRoom = true;
    _requestConference = false;
  }

  DateTime _startDate = DateTime.now();
  DateTime _stopDate = DateTime.now().add(const Duration(days: 1));

  // Tfood related
  List<Tfood> _tfoods = [];
  List<Foodtype> _foodtypes = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // bool get isEdit => widget.booking != null;
  bool get isEdit =>
      _currentBooking != null; // ใช้ _currentBooking แทน widget.booking

  /// ล็อกอินอยู่หรือไม่ (ApiService เป็นตัวเดียวทั้งแอป ค่าตรงกับ AuthProvider)
  bool get _loggedIn => widget.apiService.isLoggedIn;

  /// เจ้าหน้าที่ใช้ฟอร์มแบบเดิม (แก้เลขบัตรได้ ยืนยัน ThaID แทนผู้จองได้)
  bool get _isStaff => widget.apiService.isStaff;

  /// สถานะล็อกอินครั้งก่อน ใช้ดูว่าเพิ่งเข้าสู่ระบบจากการ์ดในหน้านี้
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    // แก้เลขบัตรหลังยืนยันด้วย ThaID แล้ว ป้าย "ยืนยันตัวตนแล้ว" ต้องหายตาม
    _idcardCtrl.addListener(() {
      if (_thaidPid != null && mounted) setState(() {});
    });
    _currentBooking = widget.booking; // เก็บข้อมูลเริ่มต้น
    _wasLoggedIn = _loggedIn;
    widget.authProvider?.addListener(_onAuthChanged);
    _loadFoodtypes();
    if (isEdit) {
      _loadExistingData();
      if (_loggedIn) _loadTfoods();
    } else if (_loggedIn) {
      _fillBookerFromLogin();
    }
  }

  /// สถานะล็อกอินเปลี่ยน: เพิ่งเข้าสู่ระบบ = เติมข้อมูลผู้จอง/โหลดรายการอาหาร
  /// ออกจากระบบ = ฟอร์มถูกแทนด้วยการ์ดเข้าสู่ระบบ (build ตัดสินเอง)
  void _onAuthChanged() {
    if (!mounted) return;
    final now = _loggedIn;
    if (now && !_wasLoggedIn) {
      if (isEdit) {
        _loadTfoods();
      } else {
        _fillBookerFromLogin();
      }
    } else if (!now && _wasLoggedIn) {
      // ล้างข้อมูลผู้จองของบัญชีเดิมทิ้ง ไม่ให้ค้างไปถึงบัญชีถัดไปที่เข้าในหน้านี้
      _thaidPid = null;
      _thaidAddress = null;
      _tfoods = [];
      if (!isEdit) {
        _idcardCtrl.clear();
        _contractNameCtrl.clear();
      }
    }
    _wasLoggedIn = now;
    setState(() {});
  }

  /// ใบจองใหม่ของผู้ที่เข้าสู่ระบบแล้ว (ทั้ง ThaID และรหัสผ่าน): เติมชื่อ-สกุลผู้จองและเลขบัตรให้
  ///
  /// ชื่อ-สกุล: พนักงานที่ผูกกับบัญชี (empID) ไม่มีพนักงานใช้ชื่อในตาราง users
  ///           (บัญชีที่ ThaID สร้างให้ ชื่อในตาราง users คือชื่อตามบัตร)
  /// เลขบัตร:   users.idcard ของบัญชี บัญชีที่ยังไม่ผูกเลขบัตรช่องนี้ว่างไว้
  /// ป้าย "ยืนยันตัวตนแล้ว" ขึ้นเฉพาะเข้าด้วย ThaID เพราะเลขบัตรผ่านการยืนยันตอนเข้าสู่ระบบ
  /// เข้าด้วยรหัสผ่านเลขบัตรมาจากที่ผู้ดูแลกรอกไว้ ยังไม่ได้ยืนยัน
  /// เติมเฉพาะช่องที่ยังว่าง จองแทนคนอื่นก็แก้ทับได้
  ///
  /// ผู้จองที่ไม่ใช่เจ้าหน้าที่: เลขบัตรใช้ของบัญชีเสมอ (ทับค่าเดิม ช่องนี้แก้ไม่ได้)
  Future<void> _fillBookerFromLogin() async {
    try {
      final b = await widget.apiService.getMyBooker();
      if (!mounted || b == null || isEdit || !_loggedIn) return;
      setState(() {
        if (_contractNameCtrl.text.trim().isEmpty && b.name.isNotEmpty) {
          _contractNameCtrl.text = b.name;
        }
        if (!_isStaff) {
          _thaidPid = widget.apiService.isThaidLogin && b.idcard.isNotEmpty
              ? b.idcard
              : null;
          _idcardCtrl.text = b.idcard;
        } else if (_idcardCtrl.text.trim().isEmpty && b.idcard.isNotEmpty) {
          if (widget.apiService.isThaidLogin) _thaidPid = b.idcard;
          _idcardCtrl.text = b.idcard;
        }
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.w('เติมข้อมูลผู้จองไม่สำเร็จ: $e');
    }
  }

  @override
  void dispose() {
    widget.authProvider?.removeListener(_onAuthChanged);
    _booktitleCtrl.dispose();
    _departmentCtrl.dispose();
    _contractNameCtrl.dispose();
    _contractNumberCtrl.dispose();
    _numberMemberCtrl.dispose();
    _idcardCtrl.dispose();
    _numberStaffCtrl.dispose();
    _bookRemarkCtrl.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    final b = _currentBooking!; // ใช้ _currentBooking แทน widget.booking
    // final b = widget.booking!;
    _booktitleCtrl.text = b.booktitle ?? '';
    _departmentCtrl.text = b.departmentname ?? '';
    _contractNameCtrl.text = b.contractname1 ?? '';
    _contractNumberCtrl.text = b.contractnumber1 ?? '';
    _numberMemberCtrl.text = '${b.numbermember ?? 0}';
    _idcardCtrl.text = b.idcard ?? '';
    _numberStaffCtrl.text = '${b.numberstaff ?? 0}';
    _bookRemarkCtrl.text = b.bookremark ?? '';
    _bookingtype = b.bookingtype ?? 'A';
    _requestRoom = b.requestroom == 'T';
    _requestConference = b.requestconference == 'T';
    if (_bookingtype == 'C') _applyLodgingOnly();
    if (b.startdate != null) {
      _startDate = DateTime.tryParse(b.startdate!) ?? DateTime.now();
    }
    if (b.stopdate != null) {
      _stopDate = DateTime.tryParse(b.stopdate!) ?? DateTime.now();
    }
  }

  Future<void> _loadFoodtypes() async {
    setState(() => _isLoading = true); // ✅ เพิ่มบรรทัดนี้
    try {
      final types = await widget.apiService.getFoodtypeList();
      if (mounted) setState(() => _foodtypes = types);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading foodtypes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false); // ✅ เพิ่มบรรทัดนี้
    }
  }

  /// โหลดรายการอาหารของใบจองใหม่
  ///
  /// ห้ามตั้ง _isLoading ตรงนี้: _isLoading สลับ body ทั้งหน้าเป็นวงหมุน
  /// SingleChildScrollView ของฟอร์มจึงถูกทิ้งแล้วสร้างใหม่ที่ตำแหน่งบนสุด
  /// ทำให้กด +เพิ่ม / ลบรายการอาหารแล้วหน้าจอเด้งขึ้นไปบนสุดทุกครั้ง
  /// ตารางอาหารแทนที่ของเดิมเมื่อโหลดเสร็จ ตำแหน่งเลื่อนจอจึงคงเดิม
  Future<void> _loadTfoods() async {
    // if (widget.booking?.bookID == null) return;
    if (_currentBooking?.bookID == null) return; // ใช้ _currentBooking
    try {
      // final r = await widget.apiService.getTfoods(
      //   bookID: widget.booking!.bookID,
      // );
      final r = await widget.apiService.getTfoods(
        bookID: _currentBooking!.bookID, // ใช้ _currentBooking
      );
      if (mounted) {
        final l = r['tfoods'] as List?;
        setState(
          () => _tfoods = l?.map((j) => Tfood.fromJson(j)).toList() ?? [],
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading tfoods: $e');
    }
  }

  // ===== กำหนดการจองล่วงหน้า =====
  // กองฝึก (A) + หน่วยราชการอื่น (B) จองล่วงหน้าได้ไม่เกิน 2 เดือน
  // รายย่อย (C) จองล่วงหน้าได้ไม่เกิน 15 วัน นับจากวันนี้ถึงวันที่เริ่มต้น

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// วันที่เริ่มต้นช้าที่สุดที่ประเภทผู้จองปัจจุบันจองได้
  DateTime _latestStartDate() {
    final today = _dateOnly(DateTime.now());
    if (_bookingtype == 'C') {
      return DateTime(today.year, today.month, today.day + 15);
    }
    // บวก 2 เดือน ถ้าเดือนปลายทางไม่มีวันที่นี้ (เช่น 31) ใช้วันสุดท้ายของเดือนนั้น
    final lastDay = DateTime(today.year, today.month + 3, 0).day;
    return DateTime(
      today.year,
      today.month + 2,
      today.day < lastDay ? today.day : lastDay,
    );
  }

  String get _advanceRuleText => _bookingtype == 'C'
      ? 'รายย่อยจองล่วงหน้าได้ไม่เกิน 15 วัน'
      : 'กองฝึกและหน่วยราชการอื่นจองล่วงหน้าได้ไม่เกิน 2 เดือน';

  /// ข้อความเตือนถ้าวันที่เริ่มต้น [start] เกินกำหนดจองล่วงหน้า ไม่เกิน = null
  String? _advanceLimitError(DateTime start) {
    final latest = _latestStartDate();
    if (!_dateOnly(start).isAfter(latest)) return null;
    return '$_advanceRuleText '
        '(วันที่เริ่มต้นเลือกได้ถึง ${Util.formatThaiDate(latest)})';
  }

  /// ส่งใบจอง ใช้ทั้งปุ่ม Booking บนแถบหัวและปุ่มท้ายฟอร์ม
  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) {
      context.showErrorSnackBar(
        'กรุณากรอกข้อมูลที่จำเป็น (มีเครื่องหมาย *) ให้ครบ',
      );
      return;
    }
    final advanceError = _advanceLimitError(_startDate);
    if (advanceError != null) {
      context.showErrorSnackBar(advanceError);
      return;
    }
    if (_dateOnly(_stopDate).isBefore(_dateOnly(_startDate))) {
      context.showErrorSnackBar('วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่มต้น');
      return;
    }
    // ✅ เพิ่มการตรวจสอบเบื้องต้น
    if (_currentBooking == null && !isEdit) {
      // โหมดเพิ่มใหม่ ไม่ต้องมี _currentBooking
    } else if (isEdit && _currentBooking?.bookID == null) {
      if (mounted) {
        context.showErrorSnackBar('ไม่พบข้อมูลการจองที่ต้องการแก้ไข');
      }
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      // รายย่อยไม่มีช่องชื่อโครงการและจำนวนเจ้าหน้าที่ (ซ่อนไว้)
      // ใบจองใหม่ส่งค่าว่าง/0 กันค่าที่พิมพ์ค้างไว้ตอนเลือกประเภทอื่นหลุดไปด้วย
      // ใบจองที่บันทึกแล้วส่งค่าเดิมกลับไป backend จะได้ไม่ล้างข้อมูลเก่าทิ้ง
      final isSmall = _bookingtype == 'C';
      final booktitle = isSmall && !isEdit ? '' : _booktitleCtrl.text.trim();
      final numberstaff = isSmall && !isEdit
          ? 0
          : int.tryParse(_numberStaffCtrl.text.trim());
      final d = Bookroom(
        // bookID: widget.booking?.bookID,
        bookID: _currentBooking?.bookID, // ← เปลี่ยนตรงนี้
        startdate: DateFormat('yyyy-MM-dd').format(_startDate),
        stopdate: DateFormat('yyyy-MM-dd').format(_stopDate),
        numbermember: int.tryParse(_numberMemberCtrl.text),
        idcard: _idcardCtrl.text,
        numberstaff: numberstaff,
        departmentname: _departmentCtrl.text,
        booktitle: booktitle,
        contractname1: _contractNameCtrl.text,
        contractnumber1: _contractNumberCtrl.text,
        // ที่อยู่จาก ThaID ส่งไปเฉพาะเมื่อยืนยันตัวตนแล้ว ไม่ส่ง = backend คงค่าเดิม
        address: _thaidVerified ? _thaidAddress : null,
        bookingtype: _bookingtype,
        requestroom: _requestRoom ? 'T' : 'F',
        requestconference: _bookingtype != 'C' && _requestConference
            ? 'T'
            : 'F',
        bookremark: _bookRemarkCtrl.text,
      );

      // ignore: unused_local_variable
      Bookroom saved;
      if (AppLogger.on) AppLogger.d("isEdit $isEdit");
      if (isEdit) {
        saved = await widget.apiService.updateBooking(
          // widget.booking!.bookID!,
          _currentBooking!.bookID!, // ← เปลี่ยนตรงนี้

          d,
        );
        // อัปเดต _currentBooking หลังจากแก้ไข
        setState(() {
          _currentBooking = saved;
        });
      } else {
        saved = await widget.apiService.createBooking(d);
        // ✅ อัปเดต widget.booking ด้วยข้อมูลที่สร้างใหม่
        setState(() => _currentBooking = saved);
        _loadTfoods();
        // List<Bookroom> m= await ApiService().getBookingID(bookingID:  widget.booking?.bookID);

        //          BookingEditScreen(apiService: ApiService(),
        //          booking:m[0]);
      }

      if (mounted) {
        // ✅ ใช้ AppDialog แทน SnackBar
        await AppDialog.showSuccess(
          context,
          'บันทึกการจองเรียบร้อยแล้ว\nเลขที่การจอง: ${_currentBooking?.bookID}'
          // ผู้จองที่ไม่ใช่เจ้าหน้าที่ดูใบจองย้อนหลังได้ที่เมนู "ใบจองของฉัน" (ต้องเข้าด้วย ThaID)
          '${!_isStaff ? '\n\nดูสถานะการจอง แก้ไขใบจอง '
                    'และออกใบ Pay-in ได้ที่เมนู "ใบจองของฉัน"' : ''}',
          onPressed: () {
            // หลังจากกด OK ให้กลับไปหน้าก่อนหน้า
            // Navigator.pop(context, true);
          },
        );
        // Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        if (AppLogger.on) {
          AppLogger.d('Error: $e');
        }
        _error = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
      if (mounted) {
        context.showErrorSnackBar(_error ?? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false); // ✅ เพิ่ม
    }
  }

  Future<void> _addTfood() async {
    // ข้อ 16 ของความต้องการปรับปรุง เพิ่มรายการใหม่ได้เฉพาะที่ยังให้บริการ
    // รายการที่ปิดไปแล้วยังแสดงในตารางของใบจองเก่าตามปกติ เพราะตารางใช้ _foodtypes เต็ม
    final active = _foodtypes.where((f) => f.isActive).toList();
    if (active.isEmpty) {
      context.showInfoSnackBar('ไม่พบรายการอาหารที่เปิดให้บริการ');
      return;
    }

    if (_currentBooking == null || _currentBooking!.bookID == null) {
      context.showErrorSnackBar('กรุณาบันทึกการจองก่อนเพิ่มรายการอาหาร');
      return;
    }

    // จำนวนคนตั้งต้น = ผู้เข้าพัก + เจ้าหน้าที่ ในฟอร์ม ผู้จองแก้ในหน้าต่างได้
    final headcount =
        (int.tryParse(_numberMemberCtrl.text.trim()) ?? 0) +
        (int.tryParse(_numberStaffCtrl.text.trim()) ?? 0);

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddTfoodDialog(
        foodtypes: active,
        startDate: _startDate,
        stopDate: _stopDate,
        defaultAmount: headcount > 0 ? headcount : 1,
      ),
    );

    if (selected != null && _currentBooking != null) {
      try {
        final tfood = Tfood(
          bookID: _currentBooking!.bookID,
          foodtypeid: selected['foodtypeid'] as int,
          price: selected['price'] as int,
          amount: selected['amount'] as int,
          times: selected['times'] as int,
          sequence: selected['sequence'] as int,
          // ✅ ใช้ startdate และ stopdate จาก dialog
          startdate: selected['startdate'] as String,
          stopdate: selected['stopdate'] as String,
        );
        await widget.apiService.createTfood(tfood);
        await _loadTfoods();
        if (mounted) context.showSuccessSnackBar('เพิ่มรายการอาหารสำเร็จ');
      } catch (e) {
        if (mounted) {
          context.showErrorSnackBar('เพิ่มรายการอาหารไม่สำเร็จ: $e');
        }
      }
    }
  }

  /*
 Future<void> _addTfood() async {
    if (_foodtypes.isEmpty) {
      context.showInfoSnackBar('ไม่พบข้อมูลรายการอาหาร');
      return;
    }

    // ✅ ตรวจสอบว่ามีการจองแล้วหรือยัง
    if (_currentBooking == null || _currentBooking!.bookID == null) {
      context.showErrorSnackBar('กรุณาบันทึกการจองก่อนเพิ่มรายการอาหาร');
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddTfoodDialog(
        foodtypes: _foodtypes,
        startDate: _startDate,
        stopDate: _stopDate,
      ),
    );

    if (selected != null && _currentBooking != null) {
      try {
        final tfood = Tfood(
          bookID: _currentBooking!.bookID,
          foodtypeid: selected['foodtypeid'] as int,
          price: selected['price'] as int,
          amount: selected['amount'] as int,
          // times: selected['times'] as int,
          sequence: selected['sequence'] as int,
          startdate: DateFormat('yyyy-MM-dd').format(_startDate),
          stopdate: DateFormat('yyyy-MM-dd').format(_stopDate),
        );
        await widget.apiService.createTfood(tfood);
        await _loadTfoods();
        if (mounted) context.showSuccessSnackBar('เพิ่มรายการอาหารสำเร็จ');
      } catch (e) {
        if (mounted) context.showErrorSnackBar('เพิ่มรายการอาหารไม่สำเร็จ');
      }
    }
  }
*/
  /*
  Future<void> _deleteTfood(Tfood t) async {
    if (t.id == null || _currentBooking == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ ${t.foodtypeName} รายการอาหารนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor), child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteColor),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.apiService.deleteTfood(t.id!);
        await _loadTfoods();
        if (mounted) context.showSuccessSnackBar('ลบรายการอาหารสำเร็จ');
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }
*/
  Future<void> _deleteTfood(Tfood t) async {
    if (t.id == null || _currentBooking == null) return;

    // ✅ ใช้ Confirm Dialog
    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบรายการอาหาร "${t.foodtypeName}" นี้?',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
    );

    if (confirmed == true) {
      try {
        await widget.apiService.deleteTfood(t.id!);
        await _loadTfoods();
        if (mounted) {
          // await AppDialog.showSuccess(context, 'ลบรายการอาหารสำเร็จ');
          context.showSuccessSnackBar('ลบรายการอาหารสำเร็จ');
        }
      } catch (e) {
        if (mounted) {
          // await AppDialog.showError(context, 'ลบรายการอาหารไม่สำเร็จ: $e');
          context.showErrorSnackBar('ลบรายการอาหารไม่สำเร็จ: $e');
        }
      }
    }
  }

  /// ความกว้างสูงสุดของฟอร์ม — กันไม่ให้ช่องกรอกยืดเต็มจอ 1920px
  /// ซึ่งอ่านยากเพราะสายตาต้องกวาดไกลระหว่าง label กับค่าที่กรอก
  static const double _maxFormWidth = 1040;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isD = sw > 1024;

    // จุดตัดสำหรับสลับ 2 คอลัมน์ -> ซ้อนกัน (ต่ำกว่า isD เพราะแค่ 2 ช่องยังพอวางคู่ได้)
    final isWide = sw > 720;

    // ยังไม่เข้าสู่ระบบ: ไม่แสดงฟอร์ม ให้เข้าด้วย ThaID ก่อน (รายย่อยจองผ่าน ThaID เท่านั้น)
    if (!_loggedIn) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEdit ? 'แก้ไขการจอง' : 'เพิ่มการจอง',
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        body: SingleChildScrollView(
          child: ThaidLoginCard(
            authProvider: widget.authProvider,
            title: 'กรุณาเข้าสู่ระบบด้วย ThaID ก่อนจอง',
            message:
                'ระบบใช้เลขบัตรประชาชนและชื่อ-สกุลจาก ThaID เป็นข้อมูลผู้จอง '
                'เข้าสู่ระบบแล้วจะแสดงแบบฟอร์มการจอง '
                'และดูใบจองของท่านได้ที่เมนู "ใบจองของฉัน"',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'แก้ไขการจอง' : 'เพิ่มการจอง',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MouseRegion(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveBooking,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 20),
                label: const Text('Booking', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.editColor,
                  foregroundColor: AppTheme.onSecondaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxFormWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isD ? 24 : 14,
                    vertical: isD ? 20 : 14,
                  ),
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
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ===== การ์ดที่ 1: ข้อมูลการจอง =====
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSectionHeader(
                                'ข้อมูลการจอง',
                                Icons.calendar_today,
                              ),
                              const SizedBox(height: 18),

                              // ประเภทผู้จองอยู่บนสุด เพราะกำหนดว่าต้องกรอกช่องไหน
                              // และจองล่วงหน้าได้นานเท่าไร
                              _fieldLabel('ประเภทผู้จอง'),
                              const SizedBox(height: 2),
                              RadioGroup<String>(
                                groupValue: _bookingtype,
                                onChanged: (String? value) {
                                  setState(() {
                                    _bookingtype = value!;
                                    if (value == 'C') _applyLodgingOnly();
                                  });
                                },
                                // Wrap แทน Row เพื่อไม่ให้ overflow บนจอแคบ
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: const [
                                    _RadioOption(
                                      value: 'A',
                                      label: 'กองฝึก กรมทางหลวง',
                                    ),
                                    _RadioOption(
                                      value: 'B',
                                      label: 'หน่วยราชการอื่น',
                                    ),
                                    _RadioOption(
                                      value: 'C',
                                      label: 'รายย่อย (ไม่เกิน 10 ห้อง)',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _advanceRuleNote(),

                              // เลือกรายย่อย: แจ้งให้ชัดว่ารายย่อยต้องเข้าด้วย ThaID
                              if (_bookingtype == 'C') ...[
                                const SizedBox(height: 10),
                                RetailThaidNotice(
                                  extra: _isStaff
                                      ? 'ใบจองรายย่อยใช้เลขบัตรของผู้จองที่ยืนยันด้วย ThaID'
                                      : null,
                                ),
                              ],

                              // เจ้าหน้าที่ + รายย่อย: ยืนยันตัวตนผู้จองด้วย ThaID ก่อนกรอกรายละเอียด
                              // ผู้ใช้มักกรอกเลยโดยไม่ได้ยืนยัน จึงวางไว้ก่อนช่องอื่นทั้งหมด
                              // ผู้จองที่ไม่ใช่เจ้าหน้าที่เข้าด้วย ThaID มาแล้ว แสดงป้ายแทนแผงสแกน
                              if (!_isStaff) ...[
                                const SizedBox(height: 14),
                                _bookerVerifiedBadge(),
                              ] else if (_bookingtype == 'C') ...[
                                const SizedBox(height: 14),
                                _thaidPanel(),
                              ],
                              const SizedBox(height: 18),

                              // วันที่เริ่มต้น / วันที่สิ้นสุด — จำกัดความกว้าง
                              // เพราะช่องวันที่ยาวเกินความจำเป็นแล้วดูโหว่
                              _twoCol(
                                isWide,
                                _dateField('วันที่เริ่มต้น', _startDate, () async {
                                  final p = await Util.dateFieldPickerNullable(
                                    context,
                                    _startDate,
                                  );
                                  if (!context.mounted ||
                                      p == null ||
                                      p == _startDate) {
                                    return;
                                  }
                                  // เกินกำหนดจองล่วงหน้าของประเภทนี้ ไม่รับวันที่
                                  final err = _advanceLimitError(p);
                                  if (err != null) {
                                    context.showErrorSnackBar(err);
                                    return;
                                  }
                                  setState(() {
                                    _startDate = p;
                                    // เลื่อนวันเริ่มเลยวันสิ้นสุด ดันวันสิ้นสุดตามไป
                                    if (_dateOnly(
                                      _stopDate,
                                    ).isBefore(_dateOnly(p))) {
                                      _stopDate = p;
                                    }
                                  });
                                }),
                                _dateField(
                                  'วันที่สิ้นสุด',
                                  _stopDate,
                                  () async {
                                    final p =
                                        await Util.dateFieldPickerNullable(
                                          context,
                                          _stopDate,
                                        );
                                    if (p != null && p != _stopDate) {
                                      setState(() => _stopDate = p);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),

                              // รายย่อยไม่มีชื่อโครงการ
                              if (_bookingtype != 'C') ...[
                                _fld(
                                  'ชื่อหลักสูตร/โครงการ/เรื่อง',
                                  _booktitleCtrl,
                                  requiredField: true,
                                ),
                                const SizedBox(height: 18),
                              ],

                              _twoCol(
                                isWide,
                                _fld(
                                  'ชื่อหน่วยงาน',
                                  _departmentCtrl,
                                  requiredField: true,
                                ),
                                _fld(
                                  'ชื่อ-สกุล ผู้จอง',
                                  _contractNameCtrl,
                                  requiredField: true,
                                ),
                              ),
                              const SizedBox(height: 18),

                              _twoCol(
                                isWide,
                                _fld(
                                  'เบอร์ติดต่อ',
                                  _contractNumberCtrl,
                                  kb: TextInputType.phone,
                                  requiredField: true,
                                ),
                                _fld(
                                  // บังคับเฉพาะรายย่อย (ใช้เป็น Ref.1 ของใบ Pay-in)
                                  _bookingtype == 'C'
                                      ? 'เลขบัตรประชาชน *'
                                      : 'เลขบัตรประชาชน',
                                  _idcardCtrl,
                                  kb: TextInputType.number,
                                  // ผู้จองที่ไม่ใช่เจ้าหน้าที่ใช้เลขบัตรของบัญชี แก้เองไม่ได้
                                  readOnly: !_isStaff,
                                  validator: (value) {
                                    final cleaned = (value ?? '').replaceAll(
                                      ' ',
                                      '',
                                    );
                                    if (cleaned.isEmpty) {
                                      if (_bookingtype != 'C') return null;
                                      return _isStaff
                                          ? 'กรุณากรอกเลขบัตรประชาชน'
                                          : 'บัญชีนี้ไม่มีเลขบัตรประชาชน กรุณาเข้าสู่ระบบด้วย ThaID';
                                    }
                                    if (cleaned.length != 13) {
                                      return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                                    }
                                    if (!RegExp(
                                      r'^[0-9]+$',
                                    ).hasMatch(cleaned)) {
                                      return 'กรุณากรอกเฉพาะตัวเลขเท่านั้น';
                                    }
                                    // รายย่อยใช้เลขนี้เป็น Ref.1 ของใบ Pay-in ต้องเป็นเลขที่ถูกต้องจริง
                                    if (_bookingtype == 'C' &&
                                        !Util.isValidThaiId(cleaned)) {
                                      return 'เลขบัตรประชาชนไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
                                    }
                                    return null; // ผ่านการตรวจสอบ
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ช่องตัวเลขไม่ต้องกว้าง — ให้แค่ช่องละหนึ่งในสี่
                              // แล้วปล่อยครึ่งขวาว่าง อ่านง่ายกว่าช่องยาวๆ
                              // รายย่อยไม่มีจำนวนเจ้าหน้าที่
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _fld(
                                        'จำนวนผู้เข้าพัก',
                                        _numberMemberCtrl,
                                        kb: TextInputType.number,
                                        suffix: 'คน',
                                      ),
                                    ),
                                    if (_bookingtype != 'C') ...[
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: _fld(
                                          'จำนวนเจ้าหน้าที่',
                                          _numberStaffCtrl,
                                          kb: TextInputType.number,
                                          suffix: 'คน',
                                        ),
                                      ),
                                    ],
                                    // เว้นครึ่งขวาไว้ ไม่ยืดช่องตัวเลขจนเวิ้งว้าง
                                    Spacer(flex: _bookingtype == 'C' ? 3 : 2),
                                  ],
                                )
                              else ...[
                                _fld(
                                  'จำนวนผู้เข้าพัก',
                                  _numberMemberCtrl,
                                  kb: TextInputType.number,
                                  suffix: 'คน',
                                ),
                                if (_bookingtype != 'C') ...[
                                  const SizedBox(height: 18),
                                  _fld(
                                    'จำนวนเจ้าหน้าที่',
                                    _numberStaffCtrl,
                                    kb: TextInputType.number,
                                    suffix: 'คน',
                                  ),
                                ],
                              ],
                              const SizedBox(height: 18),

                              _fieldLabel('ประเภทห้องที่ขอใช้'),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 12,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _CheckOption(
                                    value: _requestRoom,
                                    label: 'ห้องพัก',
                                    onChanged: (v) =>
                                        setState(() => _requestRoom = v),
                                  ),
                                  // รายย่อยขอได้เฉพาะห้องพัก
                                  if (_bookingtype != 'C')
                                    _CheckOption(
                                      value: _requestConference,
                                      label: 'ห้องกิจกรรม',
                                      onChanged: (v) => setState(
                                        () => _requestConference = v,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ===== การ์ดที่ 2: รายการอาหาร =====
                        if (_bookingtype != 'C') ...[
                          const SizedBox(height: 16),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _buildSectionHeader(
                                      'รายการอาหาร',
                                      Icons.restaurant,
                                    ),
                                    const Spacer(),
                                    if (isEdit || _currentBooking != null)
                                      ElevatedButton.icon(
                                        onPressed: _addTfood,
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('เพิ่ม'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.addColor,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (_tfoods.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.fieldFillColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.no_meals_outlined,
                                            color: Colors.grey.shade400,
                                            size: 28,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'ยังไม่มีรายการอาหาร',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ..._tfoods.map(
                                  (t) => Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'ลำดับ: ${t.sequence} | ${t.foodtypeName ?? '-'} | ${t.amount} คน |เริ่ม ${Util.formatThaiDateStr(t.startdate)} |สิ้นสุด ${Util.formatThaiDateStr(t.stopdate)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteTfood(t),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'ลบรายการนี้',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ===== การ์ดที่ 3: หมายเหตุ =====
                        const SizedBox(height: 16),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSectionHeader(
                                'หมายเหตุ',
                                Icons.sticky_note_2_outlined,
                              ),
                              const SizedBox(height: 14),
                              _fld('', _bookRemarkCtrl, maxLines: 3),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _bottomBookingBar(),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// หมายเหตุกำหนดการจองล่วงหน้า แสดงทั้งสองกติกา เน้นตัวหนาข้อที่ตรงกับประเภทที่เลือก
  Widget _advanceRuleNote() {
    final isSmall = _bookingtype == 'C';
    TextStyle line(bool active) => TextStyle(
      fontFamily: 'NotoSansThai',
      fontSize: 13,
      color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.warningColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'หมายเหตุ กำหนดการจอง',
                  style: TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '• กองฝึก กรมทางหลวง และหน่วยราชการอื่น '
                  'จองล่วงหน้าได้ไม่เกิน 2 เดือน',
                  style: line(!isSmall),
                ),
                Text(
                  '• รายย่อย จองล่วงหน้าได้ไม่เกิน 15 วัน',
                  style: line(isSmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ปุ่มส่งการจองท้ายฟอร์ม (ซ้ำกับปุ่ม Booking บนแถบหัว)
  /// ผู้จองกรอกไล่ลงมาจนจบแล้วมักมองหาปุ่มยืนยันด้านล่างสุด
  Widget _bottomBookingBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryPale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'การจองจะสมบูรณ์เมื่อได้รับการเปลี่ยนสถานะเป็น '
                  '“รับจองแล้ว” เท่านั้น',
                  style: TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveBooking,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.onSecondaryColor,
                    ),
                  )
                : const Icon(Icons.check, size: 20),
            label: const Text('Booking', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.editColor,
              foregroundColor: AppTheme.onSecondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// กล่องขาวมีขอบมนสำหรับแบ่งฟอร์มเป็นส่วนๆ ให้อ่านง่ายขึ้น
  Widget _card({required Widget child}) => Container(
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

  /// วางสองช่องคู่กันบนจอกว้าง แต่ซ้อนกันบนจอแคบ
  Widget _twoCol(bool isWide, Widget a, Widget b) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, const SizedBox(height: 18), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 18),
        Expanded(child: b),
      ],
    );
  }

  Widget _fieldLabel(String l) => Text(
    l,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _fld(
    String l,
    TextEditingController c, {
    int maxLines = 1,
    TextInputType? kb,
    String? Function(String?)? validator, // ✅ เพิ่มพารามิเตอร์ validator
    String? suffix, // หน่วยท้ายช่อง เช่น 'คน'
    // ช่องบังคับกรอก: ต่อ * ท้ายชื่อช่อง และเตือนเมื่อเว้นว่าง (ใช้เมื่อไม่ได้ส่ง validator มาเอง)
    bool requiredField = false,
    // แสดงค่าแต่แก้ไม่ได้ (เช่นเลขบัตรของผู้จองที่มาจากบัญชี)
    bool readOnly = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (l.isNotEmpty) ...[
        _fieldLabel(requiredField ? '$l *' : l),
        const SizedBox(height: 6),
      ],
      TextFormField(
        controller: c,
        keyboardType: kb,
        maxLines: maxLines,
        readOnly: readOnly,
        validator:
            validator ??
            (requiredField
                ? (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณากรอก${l.isEmpty ? 'ข้อมูล' : l}'
                      : null
                : null),
        decoration: InputDecoration(
          // ข้อความเตือนยาวอย่างเลขบัตรไม่ถูกต้อง ให้ขึ้นบรรทัดใหม่แทนการตัดทิ้ง
          errorMaxLines: 3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.6),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade200 : AppTheme.fieldFillColor,
          suffixText: suffix,
          suffixIcon: readOnly
              ? Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade600)
              : null,
          suffixStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    ],
  );
  /*
  Widget _dd<T>(
    String l,
    T v,
    List<DropdownMenuItem<T>> items,
    Function(T?) oc,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      DropdownButtonFormField<T>(
        initialValue: v,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: AppTheme.fieldFillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        items: items,
        onChanged: oc,
        style: const TextStyle(fontSize: 14),
      ),
    ],
  );
*/
  Widget _dateField(String l, DateTime d, VoidCallback ot) {
    return Column(
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
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.fieldFillColor,
            ),
            child: Text(
              Util.formatThaiDate(d), // ✅ แสดงวันที่ไทย
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// Dialog for adding Tfood
// class _AddTfoodDialog extends StatefulWidget {
//   final List<Foodtype> foodtypes;
//    final DateTime startDate;
//    final DateTime stopDate;
//    const _AddTfoodDialog({
//     required this.foodtypes,
//     required this.startDate,
//     required this.stopDate,
//   });

//   @override
//   State<_AddTfoodDialog> createState() => _AddTfoodDialogState();
// }

// class _AddTfoodDialogState extends State<_AddTfoodDialog> {
//   int? _selectedFoodtypeID;
//   int _amount = 1;
//   int _sequence=1;
//   // int _times = 1;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.foodtypes.isNotEmpty) {
//       _selectedFoodtypeID = widget.foodtypes.first.id;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedType = widget.foodtypes.firstWhere(
//       (f) => f.id == _selectedFoodtypeID,
//       orElse: () => widget.foodtypes.first,
//     );
//     return AlertDialog(
//       title: const Text('เพิ่มรายการอาหาร'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//            TextField(
//             keyboardType: TextInputType.number,
//             decoration: const InputDecoration(labelText: 'ลำดับ'),
//             onChanged: (v) => _sequence = int.tryParse(v) ?? 1,
//           ),
//            const SizedBox(height: 10),
//           DropdownButtonFormField<int>(
//             initialValue: _selectedFoodtypeID,
//             isExpanded: true,
//             items: widget.foodtypes
//                 .map(
//                   (f) => DropdownMenuItem<int>(
//                     value: f.id,
//                     child: Text('${f.name} (${f.price})'),
//                   ),
//                 )
//                 .toList(),
//             onChanged: (v) => setState(() => _selectedFoodtypeID = v),
//           ),
//           const SizedBox(height: 10),
//           TextField(
//             keyboardType: TextInputType.number,
//             decoration: const InputDecoration(labelText: 'จำนวน (คน)'),
//             onChanged: (v) => _amount = int.tryParse(v) ?? 1,
//           ),
//           const SizedBox(height: 10),
//          _dateField('วันที่เริ่มต้น', widget.startDate, () async {
//             final p = await Util.dateFieldPickerNullable(context, widget.startDate);
//             if (p != null && p != widget.startDate) setState(() => widget.startDate = p);
//           }),
//        const SizedBox(height: 10),
// _dateField('วันที่สิ้นสุด', widget.startDate, () async {
//             final p = await Util.dateFieldPickerNullable(context, widget.startDate);
//             if (p != null && p != widget.startDate) setState(() => widget.startDate = p);
//           }),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor), child: const Text('ยกเลิก'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             Navigator.pop(context, {
//               'foodtypeid': _selectedFoodtypeID,
//               'price': selectedType.price,
//               'amount': _amount,
//               'sequence': _sequence,
//             });
//           },
//           child: const Text('เพิ่ม'),
//         ),
//       ],
//     );
//   }

// Dialog for adding Tfood
class _AddTfoodDialog extends StatefulWidget {
  final List<Foodtype> foodtypes;
  final DateTime startDate;
  final DateTime stopDate;

  /// จำนวนคนตั้งต้น (ผู้เข้าพัก + เจ้าหน้าที่ ของใบจอง)
  final int defaultAmount;
  const _AddTfoodDialog({
    required this.foodtypes,
    required this.startDate,
    required this.stopDate,
    this.defaultAmount = 1,
  });

  @override
  State<_AddTfoodDialog> createState() => _AddTfoodDialogState();
}

class _AddTfoodDialogState extends State<_AddTfoodDialog> {
  int? _selectedFoodtypeID;
  late int _amount;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _timesCtrl;
  int _sequence = 1;
  // ✅ เพิ่มตัวแปรสำหรับเก็บวันที่ที่สามารถเปลี่ยนแปลงได้
  late DateTime _startDate;
  late DateTime _stopDate;

  /// ผู้จองพิมพ์จำนวนมื้อเองแล้ว — หลังจากนี้เปลี่ยนวันที่ก็ไม่คำนวณทับค่าที่พิมพ์
  /// (แบบเดียวกับหน้าต่างรายการอาหารฝั่งเจ้าหน้าที่ใน tfood_dialog.dart)
  bool _timesEditedByUser = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _stopDate = widget.stopDate;
    _amount = widget.defaultAmount;
    _amountCtrl = TextEditingController(text: '$_amount');
    // จำนวนมื้อตั้งต้น = จำนวนวันจากวันเริ่มถึงวันสิ้นสุด นับรวมหัวท้าย (แก้ได้)
    _timesCtrl = TextEditingController(
      text: '${_dayCount(_startDate, _stopDate)}',
    );
    if (widget.foodtypes.isNotEmpty) {
      _selectedFoodtypeID = widget.foodtypes.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _timesCtrl.dispose();
    super.dispose();
  }

  /// จำนวนวันแบบนับรวมวันเริ่มและวันสิ้นสุด เช่น วันที่ 1 ถึง 3 ได้ 3
  /// ตัดเวลาทิ้งก่อนเทียบ ไม่งั้นเศษชั่วโมงจะทำให้ผลคลาดไปหนึ่งวัน
  static int _dayCount(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    final n = b.difference(a).inDays + 1;
    return n < 1 ? 1 : n;
  }

  /// เปลี่ยนวันที่แล้วคำนวณจำนวนมื้อใหม่ เว้นแต่ผู้จองพิมพ์เองไปแล้ว
  /// (ช่องว่างอยู่ = ถือว่ายังไม่ได้แก้ คำนวณใหม่ได้)
  void _syncTimesWithDates() {
    if (_timesEditedByUser && _timesCtrl.text.trim().isNotEmpty) return;
    _timesEditedByUser = false;
    _timesCtrl.text = '${_dayCount(_startDate, _stopDate)}';
  }

  // ✅ สร้างเมธอด _dateField ภายในคลาสนี้โดยตรง
  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.fieldFillColor,
            ),
            child: Text(
              Util.formatThaiDate(date),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = widget.foodtypes.firstWhere(
      (f) => f.id == _selectedFoodtypeID,
      orElse: () => widget.foodtypes.first,
    );

    return AlertDialog(
      title: const Text('เพิ่มรายการอาหาร'),
      // เลื่อนได้ จอเตี้ยช่องจะได้ไม่ล้นหน้าต่าง
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ลำดับ'),
              onChanged: (v) => _sequence = int.tryParse(v) ?? 1,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _selectedFoodtypeID,
              isExpanded: true,
              items: widget.foodtypes
                  .map(
                    (f) => DropdownMenuItem<int>(
                      value: f.id,
                      child: Text('${f.name} (${f.price})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedFoodtypeID = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวน (คน)',
                helperText: 'ตั้งต้นตามจำนวนผู้เข้าพัก + เจ้าหน้าที่ แก้ได้',
              ),
              onChanged: (v) => _amount = int.tryParse(v.trim()) ?? 1,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _timesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'จำนวน (มื้อ)',
                helperText: 'ตั้งต้นตามจำนวนวันจากวันเริ่มถึงวันสิ้นสุด แก้ได้',
              ),
              onChanged: (_) => _timesEditedByUser = true,
            ),
            const SizedBox(height: 10),
            // ✅ ใช้ _dateField ที่สร้างในคลาสนี้
            _dateField('วันที่เริ่มต้น', _startDate, () async {
              final p = await Util.dateFieldPickerNullable(context, _startDate);
              if (p != null && p != _startDate) {
                setState(() {
                  _startDate = p;
                  _syncTimesWithDates();
                });
              }
            }),
            const SizedBox(height: 10),
            _dateField('วันที่สิ้นสุด', _stopDate, () async {
              final p = await Util.dateFieldPickerNullable(context, _stopDate);
              if (p != null && p != _stopDate) {
                setState(() {
                  _stopDate = p;
                  _syncTimesWithDates();
                });
              }
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'foodtypeid': _selectedFoodtypeID,
              'price': selectedType.price,
              'amount': _amount,
              // ช่องว่าง = ใช้จำนวนวันของช่วงที่เลือก ไม่ส่ง 0 มื้อไปให้ยอดเงินเป็นศูนย์
              'times':
                  int.tryParse(_timesCtrl.text.trim()) ??
                  _dayCount(_startDate, _stopDate),
              'sequence': _sequence,
              'startdate': DateFormat('yyyy-MM-dd').format(_startDate),
              'stopdate': DateFormat('yyyy-MM-dd').format(_stopDate),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.addColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}

/// ตัวเลือก radio พร้อม label ที่กดได้ทั้งแถว
///
/// แยกเป็น widget เพื่อให้ใช้ใน Wrap ได้ (ไม่ overflow บนจอแคบ)
/// และให้พื้นที่กดครอบคลุมข้อความด้วย ไม่ใช่แค่วงกลมเล็กๆ
class _RadioOption extends StatelessWidget {
  final String value;
  final String label;

  const _RadioOption({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final group = RadioGroup.maybeOf<String>(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => group?.onChanged(value),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(value: value),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// checkbox พร้อม label ที่กดได้ทั้งแถว
class _CheckOption extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _CheckOption({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
