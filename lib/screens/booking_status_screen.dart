import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/public_booking_status.dart';
import '../services/api_service.dart';
import '../utils/util.dart';
import '../widgets/payment_slip_upload_section.dart';

/// ตรวจสอบสถานะการจองสำหรับผู้จองที่ไม่ได้ล็อกอิน
///
/// ผู้จองกรอกเลขที่ใบจองคู่กับเลขบัตรประชาชนที่ใช้ตอนจอง แล้วเห็นแค่สถานะว่าถึงขั้นไหนแล้ว
/// ไม่เห็นรายละเอียดอื่นของใบจอง (คำขอปรับปรุงรอบ ต.ค. 2569)
/// ใบจองรายย่อยที่เจ้าหน้าที่รับจองแล้ว จะมีส่วนออกใบ Pay-in และแนบหลักฐานการชำระเงินต่อท้าย
///
/// ใช้แทนหน้ารายการการจองแบบไม่ล็อกอินเดิม ที่แสดงใบจองของทุกคนและเปิดดูรายละเอียดได้
/// เลขบัตรอยู่แค่ในหน้านี้ ไม่เก็บลงเครื่อง ไม่ใส่ใน URL และห้าม log
class BookingStatusScreen extends StatefulWidget {
  final ApiService apiService;

  /// เติมเลขใบจองไว้ให้ (เช่นเปิดมาจากหน้าที่รู้เลขอยู่แล้ว)
  final int? initialBookId;

  const BookingStatusScreen({
    super.key,
    required this.apiService,
    this.initialBookId,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  static const String _font = 'NotoSansThai';

  final _formKey = GlobalKey<FormState>();
  final _bookIdCtrl = TextEditingController();
  final _idcardCtrl = TextEditingController();

  bool _checking = false;
  String? _error;
  PublicBookingStatus? _status;

  /// เลขบัตรที่ตรวจผ่านแล้ว ส่งต่อให้ส่วนชำระเงิน (ไม่ใช้ค่าในช่องตรง ๆ เผื่อผู้ใช้แก้ช่องภายหลัง)
  String _checkedIdcard = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialBookId != null) {
      _bookIdCtrl.text = widget.initialBookId.toString();
    }
  }

  @override
  void dispose() {
    _bookIdCtrl.dispose();
    _idcardCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    final bookId = int.parse(_bookIdCtrl.text.trim());
    final idcard = _idcardCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _checking = true;
      _error = null;
      _status = null;
    });
    try {
      final s = await widget.apiService.getPublicBookingStatus(bookId, idcard);
      if (!mounted) return;
      setState(() {
        _status = s;
        _checkedIdcard = idcard;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'ตรวจสอบสถานะการจอง',
          style: TextStyle(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _formCard(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _errorCard(_error!),
                      ],
                      if (s != null) ...[
                        const SizedBox(height: 16),
                        _statusCard(s),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // ส่วนชำระเงินจัดความกว้างและระยะขอบของตัวเองอยู่แล้ว
            // key ผูกกับใบจอง + เลขบัตร ตรวจใบใหม่แล้วโหลดยอดใหม่ทั้งหมด
            if (s != null && s.onlinePayment)
              PaymentSlipUploadSection(
                key: ValueKey('pay-${s.bookId}-$_checkedIdcard'),
                apiService: widget.apiService,
                bookId: s.bookId,
                idcard: _checkedIdcard,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'กรอกเลขที่ใบจองและเลขบัตรประชาชนที่ใช้ตอนจอง',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bookIdCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                decoration: _decoration('เลขที่ใบจอง', Icons.confirmation_number),
                style: const TextStyle(fontFamily: _font),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกเลขที่ใบจอง'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idcardCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _checking ? null : _check(),
                decoration: _decoration('เลขบัตรประชาชน 13 หลัก', Icons.badge),
                style: const TextStyle(fontFamily: _font),
                validator: (v) {
                  final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (d.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
                  if (d.length != 13) return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                  if (!Util.isValidThaiId(d)) {
                    return 'เลขบัตรประชาชนไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: const Text(
                    'ตรวจสอบสถานะ',
                    style: TextStyle(fontFamily: _font, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ใบจองที่ไม่ได้กรอกเลขบัตรประชาชนไว้ตอนจอง ตรวจสอบผ่านหน้านี้ไม่ได้ '
                'กรุณาติดต่อเจ้าหน้าที่ศูนย์ฯ',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: _font),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppTheme.fieldFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontFamily: _font, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(PublicBookingStatus s) {
    String dateRange() {
      final a = s.startdate;
      final b = s.stopdate;
      if (a == null) return '-';
      if (b == null || b == a) return Util.formatThaiDate(a);
      return '${Util.formatThaiDate(a)} - ${Util.formatThaiDate(b)}';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'ใบจองเลขที่ ${s.bookId}',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    s.statusName.isEmpty ? '-' : s.statusName,
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
            _row('ประเภทผู้จอง', s.bookingtypeName),
            _row('ช่วงวันที่', dateRange()),
            if (!s.onlinePayment) ...[
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
