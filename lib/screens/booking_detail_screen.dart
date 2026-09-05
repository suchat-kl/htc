// lib/screens/booking_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/screens/booking_info_tab.dart';
import 'package:highway_training/screens/booking_list_screen.dart';
import 'package:highway_training/screens/check_in_tab.dart';
import 'package:highway_training/screens/room_assignment_tab.dart';
import 'package:highway_training/utils/snackbar_helper.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

// import 'tabs/booking_info_tab.dart';
// import 'tabs/room_assignment_tab.dart';
// import 'tabs/check_in_tab.dart';

class BookingDetailScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService apiService;
  final int bookId;

  const BookingDetailScreen({
    super.key,
    required this.authProvider,
    required this.apiService,
    required this.bookId,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ✅ ตัวแปรสำหรับเก็บข้อมูล
  Map<String, dynamic>? _bookingData;
   
  bool _isLoading = true;
  String? _error;

  /// true เมื่อแท็บใดแท็บหนึ่งบันทึกข้อมูลสำเร็จ — ส่งกลับตอนปิดหน้าจอ
  /// เพื่อให้ BookingListScreen โหลดรายการใหม่
  bool _dataChanged = false;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // ✅ ตรวจสอบและนำทางไป  BookingListScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.authProvider.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BookingListScreen(
              authProvider: widget.authProvider,
              apiService: widget.apiService,
            ),
          ),
        );
      }
    });

    _loadBookingData();
    // _loadStatusList();
  }
  // Future<void> _loadStatusList() async {
  //   setState(() => _isLoading = true);
  //   try {
  //     final statuses = await widget.apiService.getDocumentStatusList();
  //     setState(() {
       
  //       _isLoading = false;
  //     });
  //   } catch (e) {
  //     if (AppLogger.on) AppLogger.d('Error loading status: $e');
  //     setState(() => _isLoading = false);
  //   }
  // }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context, _dataChanged),
        ),
        title: const Text(
          'ขออนุญาตใช้บริการ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info, size: 15), text: 'ข้อมูลสำรองห้อง'),
            Tab(icon: Icon(Icons.meeting_room, size: 15), text: 'กำหนดห้อง'),
            Tab(icon: Icon(Icons.check_circle, size: 15), text: 'Check in'),
          ],
          labelColor: Colors.white, // ✅ สีขาว
          unselectedLabelColor: Colors.grey.shade300, // ✅ สีเทาอ่อน

          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          indicatorColor: AppTheme.secondaryColor, // ✅ ใช้สีรองจาก Theme
          indicatorWeight: 3.0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      body: 
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          // : _error != null
          // ?
          :
      TabBarView(
        controller: _tabController,
        children: [
          // BookingInfoTab(bookId: widget.bookId),
          // const RoomAssignmentTab(),
          // const CheckInTab(),
          // Tab 1: ข้อมูลสำรองห้อง
          // BookingInfoTab มี SingleChildScrollView ของตัวเองอยู่แล้ว
          // ถ้าครอบซ้ำอีกชั้น viewport ชั้นในจะได้ความสูงแบบ unbounded แล้ว assert
          BookingInfoTab(
            apiService: widget.apiService,
            bookId: widget.bookId,
            bookingData: _bookingData,
            onSaved: () => _dataChanged = true,
          ),
          // Tab 2: กำหนดห้อง
          SingleChildScrollView(
            child: RoomAssignmentTab(
              apiService: widget.apiService,
              bookId: widget.bookId,
            ),
          ),
          // Tab 3: Check in
          SingleChildScrollView(
            child: CheckInTab(
              apiService: widget.apiService,
              bookId: widget.bookId,
            ),
          ),
        ],
      ),
    );
  }
  /*
  Widget _buildBookingInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('ข้อมูลการจอง', Icons.info),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('เลขที่จอง', '${widget.bookId}'),
                  _buildInfoRow('ชื่อหน่วยงาน', 'ตัวอย่างหน่วยงาน'),
                  _buildInfoRow('ชื่อหลักสูตร', 'ตัวอย่างหลักสูตร'),
                  _buildInfoRow('ผู้จอง', 'ตัวอย่างผู้จอง'),
                  _buildInfoRow('เบอร์ติดต่อ', '098-765-4321'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('รายละเอียดห้องพัก', Icons.hotel),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('ประเภทห้อง', 'ห้องพัก VIP'),
                  _buildInfoRow('จำนวนห้อง', '2'),
                  _buildInfoRow('จำนวนผู้เข้าพัก', '4'),
                  _buildInfoRow('วันที่เริ่มต้น', '01/01/2026'),
                  _buildInfoRow('วันที่สิ้นสุด', '03/01/2026'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('หมายเหตุ', Icons.note),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'ไม่มีหมายเหตุ',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomAssignmentTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'กำหนดห้อง',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'กำลังพัฒนา',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Check In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'กำลังพัฒนา',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
 
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
  */
  // ✅ ฟังก์ชันโหลดข้อมูล
  Future<void> _loadBookingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.apiService.searchBookings(
        bookID: widget.bookId,
        page: 0,
        size: 1,
      );

      if (mounted) {
        final bookings = response['bookings'] as List?;
        if (bookings != null && bookings.isNotEmpty) {
          setState(() {
            _bookingData = bookings.first as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'ไม่พบข้อมูลการจองเลขที่ ${widget.bookId}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        context.showErrorSnackBar(_error!);
      }
    }
  }

}
