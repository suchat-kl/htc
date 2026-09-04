import 'package:flutter/material.dart';
import 'package:highway_training/utils/dialog.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/bookroom.dart';
import '../models/tfood.dart';
import '../models/foodtype.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class BookingEditScreen extends StatefulWidget {
  final ApiService apiService;
  final Bookroom? booking;
  const BookingEditScreen({super.key, required this.apiService, this.booking});

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

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking; // เก็บข้อมูลเริ่มต้น
    _loadFoodtypes();
    if (isEdit) {
      _loadExistingData();
      _loadTfoods();
    }
  }

  @override
  void dispose() {
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
      AppLogger.d('Error loading foodtypes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false); // ✅ เพิ่มบรรทัดนี้
    }
  }

  Future<void> _loadTfoods() async {
    setState(() => _isLoading = true);
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
      AppLogger.d('Error loading tfoods: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
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
      final d = Bookroom(
        // bookID: widget.booking?.bookID,
        bookID: _currentBooking?.bookID, // ← เปลี่ยนตรงนี้
        startdate: DateFormat('yyyy-MM-dd').format(_startDate),
        stopdate: DateFormat('yyyy-MM-dd').format(_stopDate),
        numbermember: int.tryParse(_numberMemberCtrl.text),
        idcard: _idcardCtrl.text,
        numberstaff: int.tryParse(_numberStaffCtrl.text),
        departmentname: _departmentCtrl.text,
        booktitle: _booktitleCtrl.text,
        contractname1: _contractNameCtrl.text,
        contractnumber1: _contractNumberCtrl.text,
        bookingtype: _bookingtype,
        requestroom: _requestRoom ? 'T' : 'F',
        requestconference: _requestConference ? 'T' : 'F',
        bookremark: _bookRemarkCtrl.text,
      );

      // ignore: unused_local_variable
      Bookroom saved;
      AppLogger.d("isEdit $isEdit");
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
        setState(() {
          _currentBooking = saved; // อัปเดต _currentBooking
          _loadTfoods();
        });
        // List<Bookroom> m= await ApiService().getBookingID(bookingID:  widget.booking?.bookID);

        //          BookingEditScreen(apiService: ApiService(),
        //          booking:m[0]);
      }

      if (mounted) {
        // ✅ ใช้ AppDialog แทน SnackBar
        await AppDialog.showSuccess(
          context,
          'บันทึกการจองเรียบร้อยแล้ว\nเลขที่การจอง: ${_currentBooking?.bookID}',
          onPressed: () {
            // หลังจากกด OK ให้กลับไปหน้าก่อนหน้า
            // Navigator.pop(context, true);
          },
        );
        // Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        AppLogger.d('Error: $e'); // ← เปลี่ยนจาก AppLogger.d(e.toString())
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
    if (_foodtypes.isEmpty) {
      context.showInfoSnackBar('ไม่พบข้อมูลรายการอาหาร');
      return;
    }

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
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isD = sw > 1024;

    return Scaffold(
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
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
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
          : SingleChildScrollView(
              padding: EdgeInsets.all(isD ? 24 : 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),

                    // Booking Information Section
                    _buildSectionHeader('ข้อมูลการจอง', Icons.calendar_today),
                    const SizedBox(height: 14),
                    _buildDateRow(isD),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        RadioGroup<String>(
                          groupValue: _bookingtype,
                          onChanged: (String? value) {
                            setState(() {
                              _bookingtype = value!;
                            });
                          },
                          child: Row(
                            children: [
                              Radio<String>(value: 'A'),
                              const Text(
                                'กองฝึก กรมทางหลวง',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 20),
                              Radio<String>(value: 'B'),
                              const Text(
                                'หน่วยราชการอื่น',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 20),
                              Radio<String>(value: 'C'),
                              const Text(
                                'รายย่อย (ไม่เกิน10ห้อง)',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    /*   _dd('หน่วยงาน', _bookingtype, [
                const DropdownMenuItem(
                  value: 'A',
                  child: Text('กองฝึก กรมทางหลวง'),
                ),
                const DropdownMenuItem(
                  value: 'B',
                  child: Text('หน่วยราชการอื่น'),
                ),
                const DropdownMenuItem(
                  value: 'C',
                  child: Text('รายย่อย (ไม่เกิน10ห้อง)'),
                ),
              ], (v) => setState(() => _bookingtype = v!)),
*/
                    const SizedBox(height: 14),
                    _fld('ชื่อหลักสูตร/โครงการ/เรื่อง', _booktitleCtrl),
                    const SizedBox(height: 14),
                    _fld('ชื่อหน่วยงาน', _departmentCtrl),
                    const SizedBox(height: 14),
                    _fld('ชื่อ-สกุล ผู้จอง', _contractNameCtrl),
                    const SizedBox(height: 14),
                    // _fld('เบอร์ติดต่อ', _contractNumberCtrl),
                    Row(
                      children: [
                        Expanded(
                          child: _fld(
                            'เบอร์ติดต่อ',
                            _contractNumberCtrl,
                            // kb: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _fld(
                            'เลขบัตรประชาชน',
                            _idcardCtrl,
                            kb: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'กรุณากรอกเลขบัตรประชาชน';
                              }
                              // ลบช่องว่างออกก่อนตรวจสอบ
                              final cleaned = value.replaceAll(' ', '');
                              if (cleaned.length != 13) {
                                return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                              }
                              if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
                                return 'กรุณากรอกเฉพาะตัวเลขเท่านั้น';
                              }
                              return null; // ผ่านการตรวจสอบ
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _fld(
                            'จำนวนผู้เข้าพัก',
                            _numberMemberCtrl,
                            kb: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _fld(
                            'จำนวนเจ้าหน้าที่',
                            _numberStaffCtrl,
                            kb: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Text(
                      'ประเภท',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Checkbox(
                          value: _requestRoom,
                          onChanged: (v) =>
                              setState(() => _requestRoom = v ?? false),
                        ),
                        const Text('ห้องพัก', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 20),
                        Checkbox(
                          value: _requestConference,
                          onChanged: (v) =>
                              setState(() => _requestConference = v ?? false),
                        ),
                        const Text(
                          'ห้องกิจกรรม',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),

                    // Tfood Section (only if bookingtype != C)
                    if (_bookingtype != 'C') ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildSectionHeader('รายการอาหาร', Icons.restaurant),
                          const Spacer(),
                          if (isEdit || _currentBooking != null)
                            ElevatedButton.icon(
                              onPressed: _addTfood,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('เพิ่ม'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_tfoods.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('ยังไม่มีรายการอาหาร'),
                          ),
                        ),
                      ..._tfoods.map(
                        (t) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ลำดับ: ${t.sequence} | ${t.foodtypeName ?? '-'} | ${t.amount} คน |เริ่ม ${Util.formatThaiDateStr(t.startdate)} |สิ้นสุด ${Util.formatThaiDateStr(t.stopdate)}',
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteTfood(t),
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Remark
                    const SizedBox(height: 14),
                    _fld('หมายเหตุ', _bookRemarkCtrl, maxLines: 2),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  // ใน _buildDateRow
  Widget _buildDateRow(bool isD) {
    return Row(
      children: [
        Expanded(
          child: _dateField('วันที่เริ่มต้น', _startDate, () async {
            final p = await Util.dateFieldPicker(context, _startDate);
            if (p != _startDate) setState(() => _startDate = p);
          }),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _dateField('วันที่สิ้นสุด', _stopDate, () async {
            final p = await Util.dateFieldPicker(context, _stopDate);
            if (p != _stopDate) setState(() => _stopDate = p);
          }),
        ),
      ],
    );
  }

  Widget _fld(
    String l,
    TextEditingController c, {
    int maxLines = 1,
    TextInputType? kb,
    String? Function(String?)? validator, // ✅ เพิ่มพารามิเตอร์ validator
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: c,
        keyboardType: kb,
        maxLines: maxLines,
        validator: validator, // ✅ ใช้ validator ที่รับเข้ามา
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
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
          fillColor: Colors.grey.shade50,
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
              color: Colors.grey.shade50,
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
//             final p = await Util.dateFieldPicker(context, widget.startDate);
//             if (p != widget.startDate) setState(() => widget.startDate = p);
//           }),
//        const SizedBox(height: 10),
// _dateField('วันที่สิ้นสุด', widget.startDate, () async {
//             final p = await Util.dateFieldPicker(context, widget.startDate);
//             if (p != widget.startDate) setState(() => widget.startDate = p);
//           }),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('ยกเลิก'),
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
  const _AddTfoodDialog({
    required this.foodtypes,
    required this.startDate,
    required this.stopDate,
  });

  @override
  State<_AddTfoodDialog> createState() => _AddTfoodDialogState();
}

class _AddTfoodDialogState extends State<_AddTfoodDialog> {
  int? _selectedFoodtypeID;
  int _amount = 1;
  int _sequence = 1;
  // ✅ เพิ่มตัวแปรสำหรับเก็บวันที่ที่สามารถเปลี่ยนแปลงได้
  late DateTime _startDate;
  late DateTime _stopDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _stopDate = widget.stopDate;
    if (widget.foodtypes.isNotEmpty) {
      _selectedFoodtypeID = widget.foodtypes.first.id;
    }
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
              color: Colors.grey.shade50,
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
      content: Column(
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
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'จำนวน (คน)'),
            onChanged: (v) => _amount = int.tryParse(v) ?? 1,
          ),
          const SizedBox(height: 10),
          // ✅ ใช้ _dateField ที่สร้างในคลาสนี้
          _dateField('วันที่เริ่มต้น', _startDate, () async {
            final p = await Util.dateFieldPicker(context, _startDate);
            if (p != _startDate) {
              setState(() => _startDate = p);
            }
          }),
          const SizedBox(height: 10),
          _dateField('วันที่สิ้นสุด', _stopDate, () async {
            final p = await Util.dateFieldPicker(context, _stopDate);
            if (p != _stopDate) {
              setState(() => _stopDate = p);
            }
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'foodtypeid': _selectedFoodtypeID,
              'price': selectedType.price,
              'amount': _amount,
              'sequence': _sequence,
              'startdate': DateFormat('yyyy-MM-dd').format(_startDate),
              'stopdate': DateFormat('yyyy-MM-dd').format(_stopDate),
            });
          },
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
