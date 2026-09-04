// สร้างไฟล์ check_in_tab.dart
import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';

class CheckInTab extends StatefulWidget {
   final int bookId;
  final ApiService apiService;
  const CheckInTab({super.key, required this.apiService, required this.bookId});

  @override
  State<CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<CheckInTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Check in - กำลังพัฒนา'));
  }
}
