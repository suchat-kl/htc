// สร้างไฟล์ room_assignment_tab.dart
import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/widgets/booking_room_assignment_section.dart';
import 'package:highway_training/widgets/booking_room_list_section.dart';
import 'package:highway_training/widgets/booking_summary_bar.dart';
import 'package:highway_training/widgets/room_availability_dialog.dart';

class RoomAssignmentTab extends StatefulWidget {
  final int bookId;
  final ApiService apiService;
  final Map<String, dynamic>? bookingData;

  /// แจ้งหน้าแม่เมื่อบันทึกสำเร็จ เพื่อให้ปุ่มปิด (X) สั่งรีเฟรชหน้ารายการได้
  final VoidCallback? onSaved;

  const RoomAssignmentTab({
    super.key,
    required this.apiService,
    required this.bookId,
    required this.bookingData,
    this.onSaved,
  });

  @override
  State<RoomAssignmentTab> createState() => _RoomAssignmentTabState();
}

class _RoomAssignmentTabState extends State<RoomAssignmentTab> {
  /// จำกัดความกว้างบนจอกว้าง ให้ตรงกับแท็บข้อมูลสำรองห้อง
  static const double _maxFormWidth = 1180;

  /// เพิ่มค่าทุกครั้งที่ dialog ตรวจสอบห้องว่างปิดลง ตารางห้องพักที่กำหนดแล้ว
  /// ฟังค่านี้อยู่ จึงโหลดใหม่ให้เห็นห้องที่เพิ่งบันทึกทันที
  final _assignmentsChanged = ValueNotifier<int>(0);

  @override
  void dispose() {
    _assignmentsChanged.dispose();
    super.dispose();
  }


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
              // ตารางเดียวกับแท็บข้อมูลสำรองห้อง แต่แท็บนี้ใช้ดูอย่างเดียว
              // จึงปิดปุ่มเพิ่ม/ไอคอนแก้ไข-ลบ เหลือปุ่มกำหนดห้องพักท้ายแถว
              BookingRoomListSection(
                apiService: widget.apiService,
                bookId: widget.bookId,
                type: 'R',
                title: 'รายการห้องพัก',
                icon: Icons.hotel,
                emptyText: 'ยังไม่มีรายการห้องพัก',
                actionLabel: 'กำหนดห้องพัก',
                showAddButton: false,
                showRowActions: false,
                onDialogClosed: () => _assignmentsChanged.value++,
                availabilityDialogBuilder: (ctx, d) => RoomAvailabilityDialog(
                  apiService: widget.apiService,
                  bookId: widget.bookId,
                  roomTypeId: d.roomTypeId!,
                  // ตรวจห้องว่างด้วยช่วงของใบจองเสมอ
                  startDate: widget.bookingData?['startdate']?.toString(),
                  stopDate: widget.bookingData?['stopdate']?.toString(),
                  // แต่บันทึกลง bookdetail ด้วยช่วงของแถวที่กำลังกำหนดห้อง
                  rowStartDate: d.startDate,
                  rowStopDate: d.stopDate,
                  roomTypeName: d.name ?? '',
                  bookRoomId: d.bookRoomId,
                  selectionMode: true,
                ),
              ),
              const SizedBox(height: 16),
              // ห้องพักที่กำหนดแล้ว — แก้ไขได้เฉพาะลำดับ ชื่อ เบอร์ติดต่อ และสถานะ
              BookingRoomAssignmentSection(
                apiService: widget.apiService,
                bookId: widget.bookId,
                refreshSignal: _assignmentsChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
