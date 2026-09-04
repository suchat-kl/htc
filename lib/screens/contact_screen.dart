import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import '../config/theme.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class ContactScreen extends StatefulWidget {
  /// `true` เมื่อถูกฝังเป็นแท็บใน MainNavigation ซึ่งมี Scaffold + header
  /// ของตัวเองอยู่แล้ว จะไม่สร้าง Scaffold/AppBar ซ้อน และไม่แสดงปุ่มปิด
  /// (ปุ่มปิดเรียก Navigator.pop ซึ่งใช้ไม่ได้ตอนเป็น root route)
  final bool embedded;

  const ContactScreen({super.key, this.embedded = false});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  bool _isDownloading = false;

  // ===== ฟังก์ชันเปิดลิงก์ภายนอก =====
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        html.window.open(url, '_blank');
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error opening URL: $e');
      if (mounted) context.showErrorSnackBar('ไม่สามารถเปิดลิงก์ได้');
    }
  }

  // ===== ดาวน์โหลดไฟล์จาก assets =====
  Future<void> _downloadAsset(String assetPath, String filename) async {
    setState(() => _isDownloading = true);
    try {
      final anchor = html.AnchorElement(href: assetPath)
        ..download = filename
        ..target = '_blank';
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);

      if (mounted) context.showSuccessSnackBar('กำลังดาวน์โหลด $filename');
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error downloading: $e');
      if (mounted) context.showErrorSnackBar('ไม่สามารถดาวน์โหลดได้');
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
    // ignore: unused_local_variable
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);

    final body = Container(
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
            _buildContactInfo(isDesktop, isLargeScreen),
            const SizedBox(height: 40),
            _buildMapSection(isDesktop, isLargeScreen),
            const SizedBox(height: 40),
            _buildDownloadButtons(isDesktop),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    // ฝังในแท็บ: MainNavigation มี Scaffold + CustomHeader ให้อยู่แล้ว
    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'ติดต่อเรา',
          style: TextStyle(
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: body,
    );
  }

  // ===== ส่วนหัว =====
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
          Icon(
            Icons.contact_phone,
            size: isDesktop ? 56 : 42,
            color: Colors.white,
          ),
          SizedBox(height: isDesktop ? 14 : 10),
          Text(
            'ติดต่อเรา',
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

  // ===== ข้อมูลติดต่อ =====
  Widget _buildContactInfo(bool isDesktop, bool isLargeScreen) {
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
          Text(
            'ศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.location_on,
            'ที่อยู่',
            'ถนนเจิมจอมพล อ.ศรีราชา จ.ชลบุรี 20110',
            isDesktop,
            isLargeScreen,
          ),
          _buildInfoRow(
            Icons.phone,
            'โทร.อัตโนมัติ',
            '(038) 314008-13',
            isDesktop,
            isLargeScreen,
          ),
          _buildInfoRow(
            Icons.phone_in_talk,
            'สายตรง',
            '(038) 314-005',
            isDesktop,
            isLargeScreen,
            isSub: true,
          ),
          _buildInfoRow(
            Icons.fax,
            'โทรสาร',
            '(038) 323980-1',
            isDesktop,
            isLargeScreen,
          ),
          _buildInfoRow(
            Icons.email,
            'Email',
            'HTC_Sriracha@doh.go.th',
            isDesktop,
            isLargeScreen,
            onTap: () => _launchUrl('mailto:HTC_Sriracha@doh.go.th'),
          ),
          _buildInfoRow(
            Icons.facebook,
            'Facebook',
            'https://www.facebook.com/HighwayTraining',
            isDesktop,
            isLargeScreen,
            onTap: () => _launchUrl('https://www.facebook.com/HighwayTraining'),
          ),
          const SizedBox(height: 8),
          // LINE
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/line.png',
                width: 100, //isDesktop ? 100 : 90,
                height: 100, //isDesktop ? 28 : 22,
                errorBuilder: (ctx, err, _) => Icon(
                  Icons.chat,
                  color: Colors.green,
                  size: isDesktop ? 28 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Text(
                'Line',
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'HighwayTraining',
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 13,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDesktop,
    bool isLargeScreen, {
    bool isSub = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: isDesktop ? 22 : 18,
              color: AppTheme.secondaryColor,
            ),
            SizedBox(width: isDesktop ? 12 : 8),
            SizedBox(
              width: isDesktop ? 110 : 80,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isDesktop ? 15 : 13,
                  color: isSub ? AppTheme.textSecondary : AppTheme.textPrimary,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ส่วนแผนที่ =====
  Widget _buildMapSection(bool isDesktop, bool isLargeScreen) {
    // final mapWidth = isLargeScreen
    //     ? 700.0
    //     : (isDesktop ? 550.0 : MediaQuery.of(context).size.width - 32);
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
              Icon(
                Icons.map,
                size: isDesktop ? 28 : 24,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 10),
              Text(
                'ที่ตั้ง',
                style: TextStyle(
                  fontSize: isDesktop ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง\nถนนเจิมจอมพล อ.ศรีราชา จ.ชลบุรี 20110',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 1000, //mapWidth,
                // height: isDesktop ? 400 : 250,
                decoration: BoxDecoration(color: Colors.grey.shade200),
                child: Image.asset(
                  'assets/images/map500.png',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, _) => Center(
                    child: Icon(
                      Icons.map,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _launchUrl(
                    'https://www.google.com/maps/search/?api=1&query=ศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง ถนนเจิมจอมพล อ.ศรีราชา จ.ชลบุรี 20110',
                  ),
                  icon: Icon(Icons.open_in_new, size: isDesktop ? 18 : 16),
                  label: Text(
                    'เปิดแผนที่',
                    style: TextStyle(fontSize: isDesktop ? 14 : 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isDownloading
                      ? null
                      : () => _downloadAsset(
                          'assets/images/location.pdf',
                          'location.pdf',
                        ),
                  icon: Icon(Icons.download, size: isDesktop ? 18 : 16),
                  label: Text(
                    'ดาวน์โหลด แผนที่',
                    style: TextStyle(fontSize: isDesktop ? 14 : 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== ปุ่มดาวน์โหลดโบรชัวร์ =====
  Widget _buildDownloadButtons(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withValues(alpha: 0.15),
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
            size: isDesktop ? 48 : 38,
            color: AppTheme.secondaryColor,
          ),
          SizedBox(height: 10),
          Text(
            'ดาวน์โหลดเอกสาร',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isDownloading
                ? null
                : () => _downloadAsset(
                    'assets/images/brochure.pdf',
                    'brochure.pdf',
                  ),
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
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
                horizontal: isDesktop ? 28 : 20,
                vertical: isDesktop ? 14 : 10,
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
