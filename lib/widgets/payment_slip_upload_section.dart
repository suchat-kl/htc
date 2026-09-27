// lib/widgets/payment_slip_upload_section.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../models/payment_slip.dart';
import '../services/api_service.dart';
import '../utils/file_pick.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// ส่วนแจ้งชำระเงินของผู้จอง — QR พร้อมเพย์ และแนบรูปสลิปโอนเงิน (ไม่ต้องล็อกอิน)
///
/// ใช้กับใบจองประเภทรายย่อย (C) เท่านั้น หน้าที่เรียกต้องเช็คประเภทเอง
/// QR ตั้งยอดตั้งต้นเป็นยอดคงเหลือ ผู้จองเปลี่ยนเป็นยอดที่ต่ำกว่าได้ถ้าจะจ่ายแยกงวด
///
/// สลิปที่แนบเป็นแค่รายการรอตรวจ เจ้าหน้าที่ต้องเทียบกับรายการเดินบัญชีก่อนยืนยัน
/// ผู้จองเห็นแค่ยอด สถานะ และเหตุผลที่ไม่รับ ไม่เห็นรูปสลิปที่แนบไปแล้ว
class PaymentSlipUploadSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  const PaymentSlipUploadSection({
    super.key,
    required this.apiService,
    required this.bookId,
  });

  @override
  State<PaymentSlipUploadSection> createState() =>
      _PaymentSlipUploadSectionState();
}

class _PaymentSlipUploadSectionState extends State<PaymentSlipUploadSection> {
  static const String _font = 'NotoSansThai';

  /// ต้องตรงกับ MAX_BYTES ของ PaymentSlipService
  static const int _maxBytes = 5 * 1024 * 1024;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _money = NumberFormat('#,##0.00');

  final _qrAmountCtrl = TextEditingController();
  PromptPayQrInfo? _qr;
  bool _qrLoading = true;
  String? _qrError;

  PickedFile? _file;
  bool _uploading = false;
  bool _loading = true;
  String? _loadError;
  List<PaymentSlip> _slips = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadQr();
  }

  @override
  void dispose() {
    _qrAmountCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final slips = await widget.apiService.getPublicPaymentSlips(
        widget.bookId,
      );
      if (!mounted) return;
      setState(() {
        _slips = slips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// โหลด QR ยอดคงเหลือ หรือยอดที่ผู้จองระบุ
  Future<void> _loadQr({double? amount}) async {
    setState(() {
      _qrLoading = true;
      _qrError = null;
    });
    try {
      final qr = await widget.apiService.getPromptPayQr(
        widget.bookId,
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _qrLoading = false;
        if (qr.amount != null) {
          _qrAmountCtrl.text = qr.amount!.toStringAsFixed(2);
          // ตั้งยอดในช่องแนบสลิปให้ตรงกับ QR ไว้ก่อน ผู้จองแก้ได้
          if (_amountCtrl.text.isEmpty) {
            _amountCtrl.text = qr.amount!.toStringAsFixed(2);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrError = e.toString().replaceAll('Exception: ', '');
        _qrLoading = false;
      });
    }
  }

  void _requestQrAmount() {
    final amount = double.tryParse(_qrAmountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      context.showErrorSnackBar('กรุณากรอกยอดเงินที่จะชำระ');
      return;
    }
    _amountCtrl.text = amount.toStringAsFixed(2);
    _loadQr(amount: amount);
  }

  /// บันทึกรูป QR ลงเครื่อง สำหรับคนที่เปิดหน้านี้บนมือถือเครื่องเดียวกับแอปธนาคาร
  /// จะได้เลือก "สแกนจากรูป" ในแอปธนาคารได้
  void _saveQr() {
    final qr = _qr;
    if (qr == null || !qr.hasQr) return;
    html.AnchorElement(href: 'data:image/png;base64,${qr.image}')
      ..download =
          'QR_ใบจอง_${widget.bookId}_${qr.amount?.toStringAsFixed(2)}.png'
      ..click();
  }

  Future<void> _pick() async {
    try {
      final f = await pickImageFile();
      if (f == null || !mounted) return;
      if (f.bytes.length > _maxBytes) {
        context.showErrorSnackBar('ไฟล์ใหญ่เกิน 5 MB กรุณาใช้รูปที่เล็กลง');
        return;
      }
      setState(() => _file = f);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      context.showErrorSnackBar('กรุณากรอกยอดเงินที่โอน');
      return;
    }
    final file = _file;
    if (file == null) {
      context.showErrorSnackBar('กรุณาเลือกรูปสลิป');
      return;
    }
    setState(() => _uploading = true);
    try {
      await widget.apiService.uploadPaymentSlip(
        bookId: widget.bookId,
        amount: amount,
        note: _noteCtrl.text,
        bytes: file.bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      _amountCtrl.clear();
      _noteCtrl.clear();
      setState(() => _file = null);
      context.showSuccessSnackBar(
        'แนบสลิปเรียบร้อย เจ้าหน้าที่จะตรวจกับรายการเดินบัญชีอีกครั้ง',
      );
      // ยอดคงเหลือเปลี่ยนหลังแนบสลิป QR ต้องคำนวณใหม่
      await Future.wait([_load(), _loadQr()]);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _qrCard(),
              const SizedBox(height: 16),
              _uploadCard(),
              const SizedBox(height: 16),
              _historyCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrCard() {
    final qr = _qr;
    Widget body;
    if (_qrLoading && qr == null) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_qrError != null && qr == null) {
      body = Column(
        children: [
          Text(
            _qrError!,
            style: TextStyle(fontFamily: _font, color: Colors.red.shade700),
          ),
          TextButton(onPressed: _loadQr, child: const Text('ลองใหม่')),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _amountLine('ค่าบริการรวม', qr!.totalDue),
          if (qr.confirmed > 0) _amountLine('ยืนยันการชำระแล้ว', qr.confirmed),
          if (qr.pending > 0) _amountLine('แนบสลิปแล้ว รอตรวจ', qr.pending),
          _amountLine('ยอดคงเหลือ', qr.remaining, bold: true),
          const SizedBox(height: 12),
          if (!qr.hasQr)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                qr.message ?? 'ไม่มียอดที่ต้องชำระ',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: _font, fontSize: 15),
              ),
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(
                  base64Decode(qr.image!),
                  width: 240,
                  height: 240,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'พร้อมเพย์ ${qr.promptPayId ?? ''}\n'
              'ยอด ${_money.format(qr.amount ?? 0)} บาท',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: _saveQr,
                icon: const Icon(Icons.download),
                label: const Text(
                  'บันทึกรูป QR',
                  style: TextStyle(fontFamily: _font),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. สแกน QR ด้วยแอปธนาคาร (ถ้าเปิดหน้านี้บนมือถือ '
              'ให้บันทึกรูป QR แล้วเลือกสแกนจากรูปในแอปธนาคาร)\n'
              '2. ตรวจชื่อบัญชีปลายทางและยอดเงินก่อนยืนยันการโอน\n'
              '3. โอนแล้วแนบรูปสลิปในช่องด้านล่าง',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qrAmountCtrl,
                    enabled: !_qrLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(fontFamily: _font),
                    decoration: const InputDecoration(
                      labelText: 'จ่ายแยกงวด: ยอดที่จะชำระครั้งนี้ (บาท)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _qrLoading ? null : _requestQrAmount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'สร้าง QR',
                    style: TextStyle(fontFamily: _font),
                  ),
                ),
              ],
            ),
            if (_qrError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _qrError!,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ],
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(Icons.qr_code_2, 'ชำระผ่าน QR พร้อมเพย์'),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  Widget _amountLine(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontFamily: _font,
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${_money.format(value)} บาท', style: style),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(Icons.receipt_long, 'แนบสลิปโอนเงิน'),
            const SizedBox(height: 8),
            const Text(
              'โอนเงินค่าบริการแล้ว แนบรูปสลิปจากแอปธนาคารที่นี่ '
              'ถ้าโอนหลายครั้งให้แนบแยกทีละใบ '
              'เจ้าหน้าที่จะตรวจกับรายการเดินบัญชีของศูนย์ฯ ก่อนยืนยันการชำระเงิน',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              enabled: !_uploading,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(fontFamily: _font),
              decoration: const InputDecoration(
                labelText: 'ยอดเงินที่โอน (บาท) *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !_uploading,
              maxLength: 200,
              style: const TextStyle(fontFamily: _font),
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ เช่น ค่าห้องพัก / ค่าอาหาร',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pick,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _file == null ? 'เลือกรูปสลิป' : 'เปลี่ยนรูป',
                    style: const TextStyle(fontFamily: _font),
                  ),
                ),
                Text(
                  _file == null
                      ? 'รับไฟล์ JPG หรือ PNG ไม่เกิน 5 MB'
                      : '${_file!.name} (${_size(_file!.bytes.length)})',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: _file == null
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            if (_file != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Image.memory(_file!.bytes, fit: BoxFit.contain),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saveColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: const Text(
                'ส่งสลิป',
                style: TextStyle(fontFamily: _font, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_loadError != null) {
      body = Column(
        children: [
          Text(
            _loadError!,
            style: TextStyle(fontFamily: _font, color: Colors.red.shade700),
          ),
          TextButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      );
    } else if (_slips.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'ยังไม่มีสลิปที่แนบไว้',
          style: TextStyle(fontFamily: _font, color: AppTheme.textSecondary),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final s in _slips) ...[_slipTile(s), const Divider(height: 1)],
        ],
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(Icons.history, 'สลิปที่แนบแล้ว'),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }

  Widget _slipTile(PaymentSlip s) {
    final date = s.uploadedAt == null
        ? '-'
        : '${Util.formatThaiDate(s.uploadedAt!)} '
              '${DateFormat('HH:mm').format(s.uploadedAt!)} น.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_money.format(s.amount)} บาท',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'แนบเมื่อ $date',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (s.note != null)
                  Text(
                    s.note!,
                    style: const TextStyle(fontFamily: _font, fontSize: 13),
                  ),
                if (s.isRejected && s.reviewRemark != null)
                  Text(
                    'เหตุผล: ${s.reviewRemark}',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          _statusChip(s),
        ],
      ),
    );
  }

  Widget _statusChip(PaymentSlip s) {
    final color = s.isConfirmed
        ? AppTheme.successColor
        : s.isRejected
        ? AppTheme.dangerColor
        : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        s.reviewLabel,
        style: TextStyle(
          fontFamily: _font,
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _title(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 26, color: AppTheme.secondaryColor),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontFamily: _font,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(0)} KB';
}
