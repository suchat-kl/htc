import 'package:flutter/material.dart';
import '../config/theme.dart';

class FacilitiesScreen extends StatelessWidget {
  const FacilitiesScreen({super.key});

  // ข้อมูลสิ่งอำนวยความสะดวก
  final List<Map<String, dynamic>> _facilities = const [
    {'icon': Icons.wifi, 'title': 'WiFi', 'description': 'อินเทอร์เน็ตไร้สายความเร็วสูง ครอบคลุมทุกพื้นที่', 'color': Colors.blue},
    {'icon': Icons.room_service, 'title': 'รูมเซอร์วิซ', 'description': 'บริการอาหารและเครื่องดื่มถึงห้องพัก', 'color': Colors.orange},
    {'icon': Icons.elevator, 'title': 'ลิฟท์', 'description': 'ลิฟท์โดยสารอำนวยความสะดวกครบทุกชั้น', 'color': Colors.purple},
    {'icon': Icons.support_agent, 'title': 'พนักงานต้อนรับ', 'description': 'บริการให้คำแนะนำตลอด 24 ชั่วโมง', 'color': Colors.green},
    {'icon': Icons.bed, 'title': 'ห้องพัก', 'description': 'ห้องพักสะอาด สะดวกสบาย พร้อมสิ่งอำนวยความสะดวก', 'color': Colors.teal},
    {'icon': Icons.star, 'title': 'ห้องพักชั้นพิเศษ', 'description': 'ห้องพักระดับ VIP พร้อมสิ่งอำนวยความสะดวกครบครัน', 'color': Colors.amber},
    {'icon': Icons.meeting_room, 'title': 'ห้องกิจกรรม', 'description': 'ห้องประชุมและห้องจัดกิจกรรมรองรับผู้เข้าอบรม', 'color': Colors.indigo},
    {'icon': Icons.tv, 'title': 'LCD TV', 'description': 'โทรทัศน์จอแบนระบบดิจิทัลในทุกห้องพัก', 'color': Colors.deepOrange},
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 28.0 : (isDesktop ? 24.0 : 20.0);
    // ignore: unused_local_variable
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'สิ่งอำนวยความสะดวก',
          style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.04),
              Colors.white,
              AppTheme.secondaryColor.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 40 : 16,
            vertical: isDesktop ? 32 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 32),
              // Grid ของสิ่งอำนวยความสะดวก
              _buildFacilitiesGrid(context, isDesktop, isLargeScreen),
              const SizedBox(height: 40),
              // ส่วนการเดินทางและที่จอดรถ
              _buildTravelSection(context, isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  // หัวข้อใหญ่
  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.85),
            AppTheme.secondaryColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.spa, size: isDesktop ? 56 : 42, color: Colors.white),
          SizedBox(height: isDesktop ? 14 : 10),
          Text(
            'สิ่งอำนวยความสะดวก',
            style: TextStyle(
              fontSize: isDesktop ? 26 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Grid แสดงสิ่งอำนวยความสะดวก
  Widget _buildFacilitiesGrid(BuildContext context, bool isDesktop, bool isLargeScreen) {
    final crossAxisCount = isLargeScreen ? 4 : (isDesktop ? 3 : 2);
    final aspectRatio = isDesktop ? 1.1 : 0.9;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _facilities.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isDesktop ? 20 : 12,
        mainAxisSpacing: isDesktop ? 20 : 12,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        return _buildFacilityCard(
          context,
          icon: _facilities[index]['icon'] as IconData,
          title: _facilities[index]['title'] as String,
          description: _facilities[index]['description'] as String,
          color: _facilities[index]['color'] as Color,
          isDesktop: isDesktop,
        );
      },
    );
  }

  // การ์ดสิ่งอำนวยความสะดวก
  Widget _buildFacilityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isDesktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 18 : 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: isDesktop ? 40 : 32, color: color),
          ),
          SizedBox(height: isDesktop ? 14 : 10),
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 17 : 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนการเดินทางและที่จอดรถ
  Widget _buildTravelSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, size: isDesktop ? 28 : 24, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text(
                'การเดินทาง',
                style: TextStyle(
                  fontSize: isDesktop ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTravelItem(
            context,
            icon: Icons.local_parking,
            title: 'สถานที่จอดรถ',
            description: 'มีลานจอดรถกว้างขวางรองรับรถยนต์และรถบัสได้หลายคัน',
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 12),
          _buildTravelItem(
            context,
            icon: Icons.directions_bus,
            title: 'รถรับส่ง',
            description: 'บริการรถรับส่งจากตัวเมืองศรีราชาถึงศูนย์ฝึกอบรม',
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildTravelItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDesktop,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 12 : 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: isDesktop ? 26 : 22, color: AppTheme.primaryColor),
        ),
        SizedBox(width: isDesktop ? 14 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}