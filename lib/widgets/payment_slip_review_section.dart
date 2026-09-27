// lib/widgets/payment_slip_review_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/payment_slip.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';

/// สลิปที่ผู้จองแนบมา — ส่วนหนึ่งของหน้ารับชำระเงิน
///
/// เจ้าหน้าที่เปิดดูรูป เทียบกับรายการเดินบัญชีของศูนย์ฯ แล้วกดยืนยันหรือไม่รับ
/// ระบบช่วยได้แค่บอกว่าอ่าน QR บนสลิปได้หรือไม่ และกันสลิปซ้ำตั้งแต่ตอนแนบ
/// การยืนยันสลิปไม่ได้ลงเลขที่ใบเสร็จให้ ยังต้องบันทึกการรับชำระตามเดิม
class PaymentSlipReviewSection extends StatefulWidget {
  final ApiService apiService;
  final int bookId;

  /// ยอดที่ต้องชำระจากตารางสรุปค่าบริการ ใช้แสดงเทียบกับยอดที่ยืนยันแล้ว
  final double totalDue;

  /// ใบจองประเภทรายย่อย (C) ซึ่งเป็นประเภทเดียวที่ผู้จองแนบสลิปได้
  /// ประเภทอื่นซ่อนส่วนนี้ไว้ ยกเว้นมีสลิปค้างอยู่ เช่นใบจองที่ถูกเปลี่ยนประเภททีหลัง
  final bool onlinePayment;

  const PaymentSlipReviewSection({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.totalDue,
    required this.onlinePayment,
  });

  @override
  State<PaymentSlipReviewSection> createState() =>
      _PaymentSlipReviewSectionState();
}

class _PaymentSlipReviewSectionState extends State<PaymentSlipReviewSection> {
  static const String _font = 'NotoSansThai';

  final _money = NumberFormat('#,##0.00');

  bool _loading = true;
  String? _error;
  List<PaymentSlip> _slips = [];
  final Set<int> _busy = {};

  bool get _canReview => Perm.edit(Perm.payment);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slips = await widget.apiService.getPaymentSlips(widget.bookId);
      if (!mounted) return;
      setState(() {
        _slips = slips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _review(PaymentSlip s, String status) async {
    String? remark;
    if (status == 'REJECTED') {
      remark = await _askRemark();
      if (remark == null) return;
    } else if (status == 'CONFIRMED') {
      final ok = await _confirm(
        'ยืนยันสลิปยอด ${_money.format(s.amount)} บาท',
        'ตรวจกับรายการเดินบัญชีของศูนย์ฯ แล้วว่าเงินเข้าจริงตามวันเวลาและยอดในสลิป',
      );
      if (!ok) return;
    }
    setState(() => _busy.add(s.id));
    try {
      final updated = await widget.apiService.reviewPaymentSlip(
        s.id,
        status: status,
        remark: remark,
      );
      if (!mounted) return;
      setState(() {
        _slips = [for (final x in _slips) x.id == updated.id ? updated : x];
      });
      context.showSuccessSnackBar('บันทึกผลการตรวจสลิปแล้ว');
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: _font)),
        content: Text(message, style: const TextStyle(fontFamily: _font)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// ถามเหตุผลที่ไม่รับสลิป ผู้จองจะเห็นข้อความนี้ คืน null ถ้ากดยกเลิก
  Future<String?> _askRemark() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ไม่รับสลิปนี้', style: TextStyle(fontFamily: _font)),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            style: const TextStyle(fontFamily: _font),
            decoration: const InputDecoration(
              labelText: 'เหตุผล (ผู้จองจะเห็นข้อความนี้)',
              hintText: 'เช่น ไม่พบเงินเข้าบัญชีตามวันเวลาในสลิป',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ไม่รับ'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _showImage(PaymentSlip s) async {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'สลิปยอด ${_money.format(s.amount)} บาท',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'เลื่อนนิ้วหรือล้อเมาส์เพื่อซูม',
                  style: const TextStyle(fontFamily: _font, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Flexible(
                child: FutureBuilder(
                  future: widget.apiService.getPaymentSlipImage(s.id),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snap.error.toString().replaceAll('Exception: ', ''),
                          style: TextStyle(
                            fontFamily: _font,
                            color: Colors.red.shade700,
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      );
                    }
                    return InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(snap.data!, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.onlinePayment &&
        (_loading || _error != null || _slips.isEmpty)) {
      return const SizedBox.shrink();
    }
    final confirmed = _slips
        .where((s) => s.isConfirmed)
        .fold<double>(0, (sum, s) => sum + s.amount);
    final pending = _slips.where((s) => s.isPending).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'สลิปโอนเงินที่ผู้จองแนบมา',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'โหลดใหม่',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (!_loading && _error == null && _slips.isNotEmpty) ...[
            Text(
              'ยืนยันแล้ว ${_money.format(confirmed)} บาท '
              'จากยอดที่ต้องชำระ ${_money.format(widget.totalDue)} บาท'
              '${pending > 0 ? '  ·  รอตรวจ $pending ใบ' : ''}',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: confirmed + 0.005 >= widget.totalDue
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ก่อนกดยืนยัน ให้ตรวจกับรายการเดินบัญชีว่าเงินเข้าจริง '
              'การยืนยันสลิปไม่ได้บันทึกเลขที่ใบเสร็จให้',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(fontFamily: _font, color: Colors.red.shade700),
            )
          else if (_slips.isEmpty)
            const Text(
              'ยังไม่มีสลิปแนบมา',
              style: TextStyle(
                fontFamily: _font,
                color: AppTheme.textSecondary,
              ),
            )
          else
            for (final s in _slips) ...[const Divider(height: 1), _slipRow(s)],
        ],
      ),
    );
  }

  Widget _slipRow(PaymentSlip s) {
    final date = s.uploadedAt == null
        ? '-'
        : '${Util.formatThaiDate(s.uploadedAt!)} '
              '${DateFormat('HH:mm').format(s.uploadedAt!)} น.';
    final busy = _busy.contains(s.id);
    final qrColor = s.needsCloserLook
        ? AppTheme.warningColor
        : AppTheme.successColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_money.format(s.amount)} บาท',
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(s.reviewLabel, _reviewColor(s)),
                  ],
                ),
                Text(
                  'แนบเมื่อ $date${s.note == null ? '' : '  ·  ${s.note}'}',
                  style: const TextStyle(fontFamily: _font, fontSize: 13),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.needsCloserLook
                          ? Icons.warning_amber_rounded
                          : Icons.qr_code_2,
                      size: 16,
                      color: qrColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s.needsCloserLook
                            ? '${s.qrLabel} — ตรวจรูปสลิปให้ละเอียด'
                            : '${s.qrLabel}  ธนาคารผู้โอน ${s.sendingBankName}'
                                  '  เลขอ้างอิง ${s.transRef}',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          color: qrColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (s.reviewedBy != null)
                  Text(
                    '${s.reviewLabel}โดย ${s.reviewedBy}'
                    '${s.reviewRemark == null ? '' : '  ·  ${s.reviewRemark}'}',
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showImage(s),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('ดูสลิป'),
              ),
              if (_canReview && !s.isConfirmed)
                ElevatedButton(
                  onPressed: busy ? null : () => _review(s, 'CONFIRMED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ยืนยัน'),
                ),
              if (_canReview && !s.isRejected)
                ElevatedButton(
                  onPressed: busy ? null : () => _review(s, 'REJECTED'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ไม่รับ'),
                ),
              if (_canReview && !s.isPending)
                TextButton(
                  onPressed: busy ? null : () => _review(s, 'PENDING'),
                  child: const Text('กลับเป็นรอตรวจ'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _reviewColor(PaymentSlip s) => s.isConfirmed
      ? AppTheme.successColor
      : s.isRejected
      ? AppTheme.dangerColor
      : AppTheme.warningColor;

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: _font,
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
