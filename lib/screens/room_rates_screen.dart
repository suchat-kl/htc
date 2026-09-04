import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import '../config/theme.dart';
import '../utils/snackbar_helper.dart';

class RoomRatesScreen extends StatefulWidget {
  const RoomRatesScreen({super.key});

  @override
  State<RoomRatesScreen> createState() => _RoomRatesScreenState();
}

class _RoomRatesScreenState extends State<RoomRatesScreen> {
  bool _isDownloading = false;

  Future<void> _downloadBrochure() async {
    setState(() => _isDownloading = true);
    try {
      // Open PDF in new tab
      html.window.open('assets/images/brochure.pdf', '_blank');

      if (mounted) {
        context.showSuccessSnackBar('กำลังเปิดโบรชัวร์');
      }
    } catch (e) {
      debugPrint('Error downloading brochure: $e');
      if (mounted) {
        context.showErrorSnackBar('ไม่สามารถดาวน์โหลดโบรชัวร์ได้');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 28.0 : (isDesktop ? 24.0 : 20.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'ราคาห้อง',
          style: TextStyle(
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadBrochure,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, size: 20),
              label: Text(
                'ดาวน์โหลด โบรชัวร์',
                style: TextStyle(fontSize: bodyFontSize),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.05),
              Colors.white,
              AppTheme.secondaryColor.withValues(alpha: 0.05),
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
              // Header Section
              _buildHeader(context, isDesktop),
              const SizedBox(height: 40),

              // Room Cards
              _buildRoomCards(context, isDesktop, isLargeScreen),
              const SizedBox(height: 40),

              // Meeting Room Section
              _buildMeetingSection(context, isDesktop),
              const SizedBox(height: 40),

              // Download Brochure Button
              _buildDownloadButton(context, isDesktop),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Header with title and subtitle
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 30 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
                AppTheme.secondaryColor.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.hotel, size: isDesktop ? 60 : 40, color: Colors.white),
              SizedBox(height: isDesktop ? 16 : 10),
              Text(
                'รายละเอียดห้องพักและห้องกิจกรรม',
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isDesktop ? 8 : 6),
              Text(
                'ศูนย์ฝึกอบรมกรมทางหลวง',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 15,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Room Cards Row
  Widget _buildRoomCards(
    BuildContext context,
    bool isDesktop,
    bool isLargeScreen,
  ) {
    return Column(
      children: [
        Text(
          'อัตราค่าบริการ',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(height: isDesktop ? 20 : 14),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRoomCard(
                context: context,
                imagePath: 'assets/images/normal.png',
                roomType: 'ห้องพักธรรมดา',
                price: '800 บาท',
                details: 'ปรับอากาศ น้ำอุ่น ทีวี WIFI',
                icon: Icons.bed,
                color: Colors.blue,
                isDesktop: isDesktop,
              ),
              SizedBox(width: isLargeScreen ? 30 : 20),
              _buildRoomCard(
                context: context,
                imagePath: 'assets/images/vip.png',
                roomType: 'ห้อง VIP',
                price: '1,500 บาท',
                details: 'ปรับอากาศ น้ำอุ่น ทีวี\nตู้เย็น WIFI และห้องนั่งเล่น',
                icon: Icons.star,
                color: Colors.amber,
                isDesktop: isDesktop,
              ),
            ],
          )
        else
          Column(
            children: [
              _buildRoomCard(
                context: context,
                imagePath: 'assets/images/normal.png',
                roomType: 'ห้องพักธรรมดา',
                price: '800 บาท',
                details: 'ปรับอากาศ น้ำอุ่น ทีวี WIFI',
                icon: Icons.bed,
                color: Colors.blue,
                isDesktop: isDesktop,
              ),
              SizedBox(height: 20),
              _buildRoomCard(
                context: context,
                imagePath: 'assets/images/vip.png',
                roomType: 'ห้อง VIP',
                price: '1,500 บาท',
                details: 'ปรับอากาศ น้ำอุ่น ทีวี\nตู้เย็น WIFI และห้องนั่งเล่น',
                icon: Icons.star,
                color: Colors.amber,
                isDesktop: isDesktop,
              ),
            ],
          ),
      ],
    );
  }

  // Individual Room Card
  Widget _buildRoomCard({
    required BuildContext context,
    required String imagePath,
    required String roomType,
    required String price,
    required String details,
    required IconData icon,
    required Color color,
    required bool isDesktop,
  }) {
    final cardWidth = isDesktop
        ? 380.0
        : MediaQuery.of(context).size.width - 32;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: isDesktop ? 250 : 200,
              width: double.infinity,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1)),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: color.withValues(alpha: 0.1),
                    child: Icon(icon, size: 80, color: color),
                  );
                },
              ),
            ),
          ),
          // Info
          Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: isDesktop ? 24 : 20),
                    SizedBox(width: 8),
                    Text(
                      roomType,
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.payments,
                      color: AppTheme.secondaryColor,
                      size: isDesktop ? 20 : 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ราคา: ',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'รายละเอียด:',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Meeting Section
  Widget _buildMeetingSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.meeting_room,
                color: Colors.purple,
                size: isDesktop ? 28 : 24,
              ),
              SizedBox(width: 10),
              Text(
                'ห้องกิจกรรม',
                style: TextStyle(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: isDesktop ? 300 : 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.05),
              ),
              child: Image.asset(
                'assets/images/meeting.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.purple.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.meeting_room,
                      size: 80,
                      color: Colors.purple,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildMeetingPriceRow(
            context,
            isDesktop,
            'ห้องประชุม ขนาด 50-120 คน',
            '4,000 – 5,000 บาท/วัน',
          ),
          SizedBox(height: 10),
          _buildMeetingPriceRow(
            context,
            isDesktop,
            'ห้องประชุม ขนาด 40-50 คน',
            '3,000 – 3,500 บาท/วัน',
          ),
          SizedBox(height: 16),
          Text(
            'รายละเอียด:',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildDetailChip(Icons.speaker, 'เครื่องเสียง', isDesktop),
              _buildDetailChip(Icons.tv, 'LCD Projector', isDesktop),
              _buildDetailChip(Icons.mic, 'ไมโครโฟน', isDesktop),
            ],
          ),
        ],
      ),
    );
  }

  // Meeting price row
  Widget _buildMeetingPriceRow(
    BuildContext context,
    bool isDesktop,
    String title,
    String price,
  ) {
    return Row(
      children: [
        Icon(
          Icons.chevron_right,
          size: isDesktop ? 20 : 16,
          color: AppTheme.primaryColor,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontSize: isDesktop ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  // Detail chip
  Widget _buildDetailChip(IconData icon, String text, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isDesktop ? 16 : 14, color: AppTheme.primaryColor),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: isDesktop ? 13 : 12,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Download button
  Widget _buildDownloadButton(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description,
            size: isDesktop ? 50 : 40,
            color: AppTheme.secondaryColor,
          ),
          SizedBox(height: 12),
          Text(
            'ต้องการรายละเอียดเพิ่มเติม?',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _downloadBrochure,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.download, size: isDesktop ? 22 : 18),
            label: Text(
              'ดาวน์โหลด โบรชัวร์',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 24,
                vertical: isDesktop ? 16 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }
}
