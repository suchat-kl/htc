import 'package:flutter/material.dart';
import '../config/theme.dart';

class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1024) {
          return _buildDesktopFooter(context);
        } else if (constraints.maxWidth > 600) {
          return _buildTabletFooter(context);
        } else {
          return _buildMobileFooter(context);
        }
      },
    );
  }

  // Desktop Footer (> 1024px)
  Widget _buildDesktopFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Information (wider)
                Expanded(flex: 3, child: _buildContactSection(context)),
                const SizedBox(width: 32),
                // Quick Links
                Expanded(flex: 2, child: _buildQuickLinksSection()),
                const SizedBox(width: 24),
                // Downloads
                Expanded(flex: 2, child: _buildDownloadsSection()),
                const SizedBox(width: 24),
                // Social Media & Newsletter
                Expanded(flex: 2, child: _buildSocialSection(context)),
              ],
            ),
          ),
          _buildCopyrightBar(context),
        ],
      ),
    );
  }

  // Tablet Footer (601px - 1024px)
  Widget _buildTabletFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Information (full width)
                _buildContactSection(context),
                const SizedBox(height: 32),
                // Links in a row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildQuickLinksSection()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDownloadsSection()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSocialSection(context)),
                  ],
                ),
              ],
            ),
          ),
          _buildCopyrightBar(context),
        ],
      ),
    );
  }

  // Mobile Footer (< 600px)
  Widget _buildMobileFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo and Title
                _buildMobileHeader(context),
                const SizedBox(height: 24),
                // Contact Information
                _buildContactSection(context, isMobile: true),
                const SizedBox(height: 24),
                // Quick Links
                _buildQuickLinksSection(isMobile: true),
                const SizedBox(height: 16),
                // Downloads
                _buildDownloadsSection(isMobile: true),
                const SizedBox(height: 24),
                // Social Media
                _buildSocialSection(context, isMobile: true),
              ],
            ),
          ),
          _buildCopyrightBar(context),
        ],
      ),
    );
  }

  // Contact Section
  Widget _buildContactSection(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo and Title
        Row(
          children: [
            Container(
              width: isMobile ? 40 : 50,
              height: isMobile ? 40 : 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
              ),
              child: Icon(
                Icons.account_balance,
                color: AppTheme.primaryColor,
                size: isMobile ? 24 : 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Highway Training System',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Contact Details
        _buildContactItem(Icons.phone, 'โทร: 02 354 6668 ต่อ 55101,55107', isMobile: isMobile),
        const SizedBox(height: 10),
        _buildContactItem(Icons.phone, 'โทร: 038 314005', isMobile: isMobile),
        const SizedBox(height: 10),
        _buildContactItem(
          Icons.email,
          'อีเมล: train.6@doh.go.th',
          isMobile: isMobile,
        ),
        const SizedBox(height: 10),
        _buildContactItem(
          Icons.location_on,
          'ที่อยู่: ถนนเจิมจอมพล อ.ศรีราชา จ.ชลบุรี 20110',
          isMobile: isMobile,
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        _buildContactItem(
          Icons.access_time,
          'เวลาทำการ: จันทร์ - ศุกร์ 08:30 - 16:30 น.',
          isMobile: isMobile,
        ),
      ],
    );
  }

  // Quick Links Section
  Widget _buildQuickLinksSection({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เมนูหลัก',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile) ...[
          // Wrap links for mobile
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildFooterLink('หน้าหลัก', isMobile: true),
              _buildFooterLink('หลักสูตรฝึกอบรม', isMobile: true),
              _buildFooterLink('ปฏิทินอบรม', isMobile: true),
              _buildFooterLink('ลงทะเบียน', isMobile: true),
              _buildFooterLink('ข่าวสาร', isMobile: true),
              _buildFooterLink('ติดต่อเรา', isMobile: true),
            ],
          ),
        ] else ...[
          // Column layout for desktop/tablet
          _buildFooterLink('หน้าหลัก'),
          _buildFooterLink('หลักสูตรฝึกอบรม'),
          _buildFooterLink('ปฏิทินอบรม'),
          _buildFooterLink('ลงทะเบียน'),
          _buildFooterLink('ข่าวสาร'),
          _buildFooterLink('ติดต่อเรา'),
        ],
      ],
    );
  }

  // Downloads Section
  Widget _buildDownloadsSection({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ดาวน์โหลด',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile) ...[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildFooterLink('คู่มือการใช้งาน', isMobile: true),
              _buildFooterLink('เอกสารประกอบการอบรม', isMobile: true),
              _buildFooterLink('แบบฟอร์มลงทะเบียน', isMobile: true),
              _buildFooterLink('ระเบียบและข้อบังคับ', isMobile: true),
            ],
          ),
        ] else ...[
          _buildFooterLink('คู่มือการใช้งาน'),
          _buildFooterLink('เอกสารประกอบการอบรม'),
          _buildFooterLink('แบบฟอร์มลงทะเบียน'),
          _buildFooterLink('ระเบียบและข้อบังคับ'),
        ],
      ],
    );
  }

  // Social Media Section
  Widget _buildSocialSection(BuildContext context, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.start,
      children: [
        Text(
          'ติดตามเรา',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.start
              : MainAxisAlignment.start,
          children: [
            _buildSocialIcon(Icons.facebook, isMobile: isMobile),
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.message, isMobile: isMobile), // LINE
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.play_circle, isMobile: isMobile), // YouTube
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.camera_alt, isMobile: isMobile), // Instagram
          ],
        ),
        if (!isMobile) ...[
          const SizedBox(height: 24),
          // Newsletter Signup (desktop/tablet only)
          const Text(
            'รับข่าวสาร',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'อีเมลของคุณ',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('สมัคร', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Mobile Header
  Widget _buildMobileHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.account_balance,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ระบบฝึกอบรม กรมทางหลวง',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Highway Training System',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Contact Item
  Widget _buildContactItem(
    IconData icon,
    String text, {
    bool isMobile = false,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.secondaryColor, size: isMobile ? 16 : 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 13 : 18,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Footer Link
  Widget _buildFooterLink(String text, {bool isMobile = false}) {
    return InkWell(
      onTap: () {},
      onHover: (hovered) {},
      hoverColor: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 4 : 6,
          horizontal: isMobile ? 0 : 8,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isMobile ? 13 : 14,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  // Social Icon
  Widget _buildSocialIcon(IconData icon, {bool isMobile = false}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: isMobile ? 36 : 40,
        height: isMobile ? 36 : 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
      ),
    );
  }

  // Copyright Bar
  Widget _buildCopyrightBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2)),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            '© 2026 ระบบฝึกอบรม กรมทางหลวง',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
          Text(
            'สงวนลิขสิทธิ์',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'นโยบายความเป็นส่วนตัว',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
          InkWell(
            onTap: () {},
            child: Text(
              'ข้อกำหนดการใช้งาน',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
