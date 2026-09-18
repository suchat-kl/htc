// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';

/// หน้ารับชำระเงินของใบจองหนึ่ง
///
/// เปิดจากปุ่มรับชำระในหน้ารายการรับชำระเงิน ([PaymentListScreen])
/// ตอนนี้ยังเป็นหน้าว่างตามที่กำหนดไว้ รับ [bookId] มาเก็บไว้ใช้ตอนทำส่วนที่เหลือ
class PaymentScreen extends StatelessWidget {
  final ApiService apiService;

  /// เลขที่ใบจองที่จะรับชำระ
  final int bookId;

  const PaymentScreen({
    super.key,
    required this.apiService,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          tooltip: 'ปิด',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รับชำระเงิน เลขที่จอง $bookId',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: const Center(
        child: Text(
          'อยู่ระหว่างพัฒนา',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
