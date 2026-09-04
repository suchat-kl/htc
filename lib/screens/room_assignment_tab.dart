// สร้างไฟล์ room_assignment_tab.dart
import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';

class RoomAssignmentTab extends StatefulWidget {
  final int bookId;
  final ApiService apiService;
  const RoomAssignmentTab({super.key,
    required this.apiService,
    required this.bookId,
  });

  @override
  State<RoomAssignmentTab> createState() => _RoomAssignmentTabState();
}

class _RoomAssignmentTabState extends State<RoomAssignmentTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('กำหนดห้อง - กำลังพัฒนา'));
  }
}
