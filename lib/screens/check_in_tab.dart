// สร้างไฟล์ check_in_tab.dart
import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/widgets/booking_activity_assignment_section.dart';
import 'package:highway_training/widgets/booking_room_assignment_section.dart';
import 'package:highway_training/widgets/booking_summary_bar.dart';

/// แท็บ Check in — ใช้ชุดหน้าจอเดียวกับแท็บกำหนดห้อง แต่แก้ได้เฉพาะสถานะ
///
/// ตารางห้องพักและห้องกิจกรรมเหลือปุ่มแก้ไขปุ่มเดียว ไม่มีรายละเอียดและลบ
/// เพราะแท็บนี้ใช้เปลี่ยนสถานะตอนเข้าพักและคืนห้อง ไม่ใช่การกำหนดห้อง
class CheckInTab extends StatefulWidget {
  final int bookId;
  final ApiService apiService;
  final Map<String, dynamic>? bookingData;

  /// แจ้งหน้าแม่เมื่อบันทึกสำเร็จ เพื่อให้ปุ่มปิด (X) สั่งรีเฟรชหน้ารายการได้
  final VoidCallback? onSaved;

  const CheckInTab({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.bookingData,
    this.onSaved,
  });

  @override
  State<CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<CheckInTab> {
  /// จำกัดความกว้างบนจอกว้าง ให้ตรงกับแท็บกำหนดห้อง
  static const double _maxFormWidth = 1180;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxFormWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookingSummaryBar(
                apiService: widget.apiService,
                bookId: widget.bookId,
                bookingData: widget.bookingData,
                onSaved: widget.onSaved,
              ),
              const SizedBox(height: 16),
              BookingRoomAssignmentSection(
                apiService: widget.apiService,
                bookId: widget.bookId,
                statusOnly: true,
              ),
              const SizedBox(height: 16),
              BookingActivityAssignmentSection(
                apiService: widget.apiService,
                bookId: widget.bookId,
                statusOnly: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
