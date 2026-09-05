// สร้างไฟล์ booking_info_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:highway_training/models/bookroom.dart';
import 'package:highway_training/models/documentstatus.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/utils/dialog.dart';
import 'package:highway_training/utils/logger.dart';
import 'package:highway_training/utils/snackbar_helper.dart';
import 'package:highway_training/utils/util.dart';
import '../config/theme.dart';

class BookingInfoTab extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  final int bookId;
  final ApiService apiService;

  /// แจ้งหน้าแม่เมื่อบันทึกสำเร็จ เพื่อให้ปุ่มปิด (X) บน AppBar
  /// ส่งสัญญาณให้หน้ารายการรีเฟรชได้เหมือนกับปุ่ม "กลับ" ในแท็บนี้
  final VoidCallback? onSaved;

  const BookingInfoTab({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.bookingData,
    this.onSaved,
  });

  @override
  State<BookingInfoTab> createState() => _BookingInfoTabState();
}

class _BookingInfoTabState extends State<BookingInfoTab> {
  /// จำกัดความกว้างฟอร์มบนจอกว้าง ไม่งั้นช่องกรอกยืดจนอ่านยาก
  static const double _maxFormWidth = 1180;

  final _formKey = GlobalKey<FormState>();

  // ===== Controllers =====
  final _contractNameCtrl = TextEditingController();
  final _contractNumberCtrl = TextEditingController();
  final _idcardCtrl = TextEditingController();
  final _numberMemberCtrl = TextEditingController();
  final _numberStaffCtrl = TextEditingController();
  final _bookRemarkCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _booktitleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // ===== State =====
  String _bookingtype = 'A';
  bool _requestRoom = false;
  bool _requestConference = false;
  DateTime _startDate = DateTime.now();
  DateTime _stopDate = DateTime.now().add(const Duration(days: 1));
  int? _statusId;

  // ค่าอ่านอย่างเดียว เก็บไว้ส่งกลับตอนบันทึกเพื่อไม่ให้ถูกล้างเป็น null
  String? _bookdate;
  String? _branchName;

  List<DocumentStatus> _statusList = [];
  bool _isLoading = false;
  bool _isSaving = false;

  /// true เมื่อบันทึกสำเร็จอย่างน้อยหนึ่งครั้ง — ใช้บอกหน้ารายการว่าต้องโหลดใหม่
  /// เพราะปุ่ม "บันทึก" ไม่ได้ปิดหน้าจอ ค่าจึงต้องรอส่งกลับตอนกด "กลับ"
  bool _hasSaved = false;
  bool _isDeleting = false;
  String? _error;

  /// JSON ตัวเลขอาจมาเป็น int, double หรือ String แล้วแต่ serializer
  /// ใช้ตัวช่วยนี้แทนการ cast ตรงๆ เพื่อไม่ให้หน้าจอพังทั้งหน้าเพราะชนิดไม่ตรง
  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int get _bookID => _asInt(widget.bookingData?['bookID']) ?? widget.bookId;

  @override
  void initState() {
    super.initState();
    _loadFromBookingData();
    _loadStatusList();
  }

  @override
  void didUpdateWidget(covariant BookingInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ข้อมูลถูกโหลดแบบ async จากหน้าแม่ ถ้ามาถึงทีหลังต้องเติมลงฟอร์มด้วย
    if (oldWidget.bookingData != widget.bookingData) {
      _loadFromBookingData();
    }
  }

  @override
  void dispose() {
    _contractNameCtrl.dispose();
    _contractNumberCtrl.dispose();
    _idcardCtrl.dispose();
    _numberMemberCtrl.dispose();
    _numberStaffCtrl.dispose();
    _bookRemarkCtrl.dispose();
    _departmentCtrl.dispose();
    _booktitleCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _loadFromBookingData() {
    final b = widget.bookingData;
    if (b == null) return;

    _contractNameCtrl.text = b['contractname1']?.toString() ?? '';
    _contractNumberCtrl.text = b['contractnumber1']?.toString() ?? '';
    _idcardCtrl.text = b['idcard']?.toString() ?? '';
    _numberMemberCtrl.text = b['numbermember']?.toString() ?? '';
    _numberStaffCtrl.text = b['numberstaff']?.toString() ?? '';
    _bookRemarkCtrl.text = b['bookremark']?.toString() ?? '';
    _departmentCtrl.text = b['departmentname']?.toString() ?? '';
    _booktitleCtrl.text = b['booktitle']?.toString() ?? '';
    _addressCtrl.text = b['address']?.toString() ?? '';

    _bookingtype = b['bookingtype']?.toString() ?? 'A';
    _requestRoom = b['requestroom'] == 'T';
    _requestConference = b['requestconference'] == 'T';
    _statusId = _asInt(b['statusId']);
    _bookdate = b['bookdate']?.toString();
    _branchName = b['branchName']?.toString();

    final sd = b['startdate']?.toString();
    if (sd != null && sd.isNotEmpty) {
      _startDate = DateTime.tryParse(sd) ?? _startDate;
    }
    final ed = b['stopdate']?.toString();
    if (ed != null && ed.isNotEmpty) {
      _stopDate = DateTime.tryParse(ed) ?? _stopDate;
    }
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

  // ===== บันทึก =====
  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final d = Bookroom(
        bookID: _bookID,
        idcard: _idcardCtrl.text,
        startdate: DateFormat('yyyy-MM-dd').format(_startDate),
        stopdate: DateFormat('yyyy-MM-dd').format(_stopDate),
        bookdate: _bookdate,
        numbermember: int.tryParse(_numberMemberCtrl.text),
        numberstaff: int.tryParse(_numberStaffCtrl.text),
        departmentname: _departmentCtrl.text,
        booktitle: _booktitleCtrl.text,
        contractname1: _contractNameCtrl.text,
        contractnumber1: _contractNumberCtrl.text,
        bookingtype: _bookingtype,
        requestroom: _requestRoom ? 'T' : 'F',
        requestconference: _requestConference ? 'T' : 'F',
        bookremark: _bookRemarkCtrl.text,
        address: _addressCtrl.text,
        branchName: _branchName,
        statusId: _statusId,
      );

      await widget.apiService.updateBooking(_bookID, d);

      _hasSaved = true;
      widget.onSaved?.call();

      if (mounted) {
        await AppDialog.showSuccess(
          context,
          'บันทึกข้อมูลเรียบร้อยแล้ว\nเลขที่ขออนุญาต: $_bookID',
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error saving booking: $e');
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() => _error = msg);
        context.showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===== ลบ =====
  Future<void> _deleteBooking() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบข้อมูลการจอง\nเลขที่ขออนุญาต $_bookID ใช่หรือไม่?',
      confirmText: 'ลบ',
    );
    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await widget.apiService.deleteBooking(_bookID);
      if (mounted) {
        await AppDialog.showSuccess(context, 'ลบข้อมูลเรียบร้อยแล้ว');
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error deleting booking: $e');
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() => _error = msg);
        context.showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... เนื้อหา Tab 1
          if (_isLoading && _statusList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.bookingData == null)
            _emptyState()
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxFormWidth),
                child: LayoutBuilder(
                  builder: (context, c) {
                    // จอกว้างพอค่อยแบ่งสองคอลัมน์ ไม่งั้นซ้อนกันอ่านง่ายกว่า
                    final isWide = c.maxWidth > 900;
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            _errorBanner(_error!),
                            const SizedBox(height: 16),
                          ],
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _leftColumn()),
                                const SizedBox(width: 16),
                                Expanded(child: _rightColumn()),
                              ],
                            )
                          else ...[
                            _leftColumn(),
                            const SizedBox(height: 16),
                            _rightColumn(),
                          ],
                          const SizedBox(height: 16),
                          _actionBar(isWide),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Add more widgets here as needed
        ],
      ),
    );
  }

  // ===================== คอลัมน์ซ้าย =====================

  Widget _leftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('ข้อมูลการขออนุญาต', Icons.assignment_outlined),
              const SizedBox(height: 18),
              _bookIdBadge(),
              const SizedBox(height: 16),
              _readOnlyRow(
                'วันที่จอง',
                Util.formatThaiDateStr(_bookdate),
                Icons.event_outlined,
              ),
              const SizedBox(height: 10),
              _readOnlyRow(
                'สาขา',
                (_branchName == null || _branchName!.isEmpty)
                    ? '-'
                    : _branchName!,
                Icons.location_city_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('ผู้จอง', Icons.person_outline),
              const SizedBox(height: 18),
              _fld('ชื่อ-สกุล ผู้จอง', _contractNameCtrl),
              const SizedBox(height: 18),
              _twoCol(
                a: _fld(
                  'เบอร์ติดต่อ',
                  _contractNumberCtrl,
                  kb: TextInputType.phone,
                ),
                b: _fld(
                  'เลขบัตรประชาชน',
                  _idcardCtrl,
                  kb: TextInputType.number,
                  hint: 'ตัวเลข 13 หลัก',
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  validator: (value) {
                    final cleaned = (value ?? '').replaceAll(' ', '');
                    if (cleaned.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
                    if (cleaned.length != 13) {
                      return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                    }
                    if (!RegExp(r'^[0-9]{13}$').hasMatch(cleaned)) {
                      return 'กรุณากรอกเฉพาะตัวเลขเท่านั้น';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('ช่วงเวลาและจำนวนผู้เข้าพัก', Icons.date_range),
              const SizedBox(height: 18),
              _twoCol(
                a: _dateField('วันที่เริ่มต้น', _startDate, () async {
                  final p = await Util.dateFieldPicker(context, _startDate);
                  if (p != _startDate) setState(() => _startDate = p);
                }),
                b: _dateField('วันที่สิ้นสุด', _stopDate, () async {
                  final p = await Util.dateFieldPicker(context, _stopDate);
                  if (p != _stopDate) setState(() => _stopDate = p);
                }),
              ),
              const SizedBox(height: 18),
              _twoCol(
                a: _fld(
                  'จำนวนผู้เข้าพัก',
                  _numberMemberCtrl,
                  kb: TextInputType.number,
                  suffix: 'คน',
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                b: _fld(
                  'จำนวนเจ้าหน้าที่',
                  _numberStaffCtrl,
                  kb: TextInputType.number,
                  suffix: 'คน',
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(height: 18),
              _fieldLabel('ประเภทห้องที่ขอใช้'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CheckOption(
                    value: _requestRoom,
                    label: 'ห้องพัก',
                    onChanged: (v) => setState(() => _requestRoom = v),
                  ),
                  _CheckOption(
                    value: _requestConference,
                    label: 'ห้องกิจกรรม',
                    onChanged: (v) => setState(() => _requestConference = v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== คอลัมน์ขวา =====================

  Widget _rightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('ประเภทการขออนุญาต', Icons.how_to_reg_outlined),
              const SizedBox(height: 14),
              RadioGroup<String>(
                groupValue: _bookingtype,
                onChanged: (String? value) {
                  if (value != null) setState(() => _bookingtype = value);
                },
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RadioOption(value: 'A', label: 'กองฝึก กรมทางหลวง'),
                    _RadioOption(value: 'B', label: 'หน่วยราชการอื่น'),
                    _RadioOption(
                      value: 'C',
                      label: 'รายย่อย (ไม่เกิน 10 ห้อง)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _fld('หมายเหตุ', _bookRemarkCtrl, maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('กรณีจองในนามหน่วยงาน', Icons.apartment_outlined),
              const SizedBox(height: 18),
              _fld('ชื่อหน่วยงาน', _departmentCtrl),
              const SizedBox(height: 18),
              _fld('ชื่อหลักสูตร/โครงการ/เรื่อง', _booktitleCtrl, maxLines: 2),
              const SizedBox(height: 18),
              _fld('ที่อยู่ในการออกใบเสร็จ', _addressCtrl, maxLines: 4),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== แถบสถานะ + ปุ่ม =====================

  Widget _actionBar(bool isWide) {
    final busy = _isSaving || _isDeleting;

    final statusField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('สถานะการจอง'),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          // กันกรณี statusId ที่ได้มาไม่มีอยู่ในรายการ ไม่งั้น dropdown จะ assert
          initialValue:
              _statusList.any((s) => s.statusId == _statusId) ? _statusId : null,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: _statusList.isEmpty
                ? 'กำลังโหลดสถานะ...'
                : 'เลือกสถานะการจอง',
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
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1.6,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
          items: _statusList
              .map(
                (s) => DropdownMenuItem<int>(
                  value: s.statusId,
                  child: Text(
                    s.statusName ?? '-',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: busy ? null : (v) => setState(() => _statusId = v),
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        ),
      ],
    );

    final buttons = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(
          label: 'บันทึก',
          icon: Icons.save_outlined,
          color: const Color(0xFF43A047),
          busy: _isSaving,
          onPressed: busy ? null : _saveBooking,
        ),
        _actionButton(
          label: 'ลบ',
          icon: Icons.delete_outline,
          color: const Color(0xFFE53935),
          busy: _isDeleting,
          onPressed: busy ? null : _deleteBooking,
        ),
        _actionButton(
          label: 'กลับ',
          icon: Icons.arrow_back,
          color: const Color(0xFF00ACC1),
          busy: false,
          // ส่ง _hasSaved กลับไป หน้ารายการจะรีเฟรชเฉพาะตอนที่ข้อมูลถูกแก้จริง
          onPressed: busy ? null : () => Navigator.pop(context, _hasSaved),
        ),
      ],
    );

    return _card(
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 340, child: statusField),
                const Spacer(),
                buttons,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statusField,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white70,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ===================== ชิ้นส่วน UI ที่ใช้ซ้ำ =====================

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'ไม่พบข้อมูลการจองเลขที่ ${widget.bookId}',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
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
        ],
      ),
    );
  }

  /// เลขที่ขออนุญาตเป็นตัวระบุหลักของหน้านี้ จึงเน้นให้เห็นชัดกว่าช่องอื่น
  Widget _bookIdBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.09),
            AppTheme.secondaryColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 22,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'เลขที่ขออนุญาต',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            '$_bookID',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// ข้อมูลที่แก้ไขไม่ได้ — แสดงเป็นข้อความ ไม่ทำเป็นช่องกรอกที่กดไม่ได้
  /// เพื่อไม่ให้ผู้ใช้เข้าใจผิดว่าพิมพ์ได้
  Widget _readOnlyRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

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

  /// วางสองช่องคู่กันเมื่อพื้นที่ *ของแถวนั้นเอง* พอ ไม่ใช่ดูจากความกว้างจอ
  /// เพราะการ์ดอาจอยู่ในคอลัมน์แคบของ layout สองคอลัมน์อยู่แล้ว
  Widget _twoCol({
    required Widget a,
    required Widget b,
    double breakpoint = 440,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [a, const SizedBox(height: 18), b],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      },
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
    String? hint,
    String? suffix,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (l.isNotEmpty) ...[_fieldLabel(l), const SizedBox(height: 6)],
      TextFormField(
        controller: c,
        keyboardType: kb,
        maxLines: maxLines,
        inputFormatters: formatters,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
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
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 1.6,
            ),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          suffixText: suffix,
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

  Widget _dateField(String l, DateTime d, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(l),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Util.formatThaiDate(d),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// radio พร้อม label ที่กดได้ทั้งแถว
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
            Flexible(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
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
