// สร้างไฟล์ booking_info_tab.dart
import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/utils/util.dart';

class BookingInfoTab extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  final int bookId;
  final ApiService apiService;
  const BookingInfoTab({super.key,required this.apiService,
   required this.bookId,required this.bookingData});

  @override
  State<BookingInfoTab> createState() => _BookingInfoTabState();
}

class _BookingInfoTabState extends State<BookingInfoTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... เนื้อหา Tab 1
//1
          Row(
            children: [
              const Text(
                'เลขที่จอง:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['bookID']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
//2
          Row(
            children: [
              const Text(
                'วันที่จอง:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
               Util.formatThaiDateStr( widget.bookingData?['bookdate']) ,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          //3
          Row(
            children: [
              const Text(
                'สาขา:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['branchName']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'ชื่อ-สกุล ผู้จอง:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['contractname1']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'เบอร์ติดต่อ:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['contractnumber1']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'วันที่เริ่มต้น:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
               Util.formatThaiDateStr( widget.bookingData?['startdate']?.toString() ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'วันที่สิ้นสุด:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
               Util.formatThaiDateStr( widget.bookingData?['stopdate']?.toString() ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'จำนวนผู้เข้าพัก:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['numbermember']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'จำนวนเจ้าหน้าที่:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.bookingData?['numberstaff']?.toString() ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        
///////
Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ประเภท',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: widget.bookingData?['requestroom'] == 'T' ? true : false,
                          onChanged: null,
                          activeColor: Colors.green,
                        ),
                        const Text('ห้องพัก', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: widget.bookingData?['requestconference'] == 'T'
                              ? true
                              : false,
                          onChanged: null,
                          activeColor: Colors.blue,
                        ),
                        const Text(
                          'ห้องกิจกรรม',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
///



          // Add more widgets here as needed
        ],
      ),
    );
  }
}
