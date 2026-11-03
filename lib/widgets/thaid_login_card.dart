// lib/widgets/thaid_login_card.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';
import '../utils/thaid.dart';

/// ป้ายแจ้ง [retailThaidOnlyMessage] (ผู้ใช้รายย่อยเข้าสู่ระบบผ่าน ThaID เท่านั้น)
///
/// ใช้ร่วมกันทุกจุดที่ต้องแจ้งเรื่องนี้ ข้อความและหน้าตาจะได้ตรงกัน
/// [extra] = ข้อความต่อท้ายบรรทัดถัดไป (ไม่บังคับ) เช่นบอกให้กดปุ่ม ThaID
class RetailThaidNotice extends StatelessWidget {
  final String? extra;

  const RetailThaidNotice({super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  retailThaidOnlyMessage,
                  style: TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.infoColor,
                  ),
                ),
                if (extra != null && extra!.isNotEmpty)
                  Text(
                    extra!,
                    style: const TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดขอให้เข้าสู่ระบบด้วย ThaID ก่อนใช้งาน ใช้ในหน้า "จอง" และ "ใบจองของฉัน"
///
/// ผู้จองรายย่อยต้องจองและดูใบจองของตัวเองผ่าน ThaID เท่านั้น (พ.ย. 2569)
/// หน้าที่ใช้การ์ดนี้ต้องฟัง [authProvider] เอง เข้าสู่ระบบสำเร็จแล้วการ์ดจะถูกแทนด้วยเนื้อหาจริง
/// ไม่มี [authProvider] (ผู้เรียกไม่ได้ส่งมา) = แสดงข้อความให้กดปุ่ม ThaID ที่แถบบนแทน
class ThaidLoginCard extends StatelessWidget {
  final AuthProvider? authProvider;

  /// หัวข้อการ์ด เช่น "กรุณาเข้าสู่ระบบด้วย ThaID ก่อนจอง"
  final String title;

  /// คำอธิบายใต้หัวข้อ
  final String message;

  const ThaidLoginCard({
    super.key,
    required this.authProvider,
    required this.title,
    required this.message,
  });

  static const String _font = 'NotoSansThai';

  /// เข้าสู่ระบบด้วย ThaID แบบเดียวกับปุ่มที่แถบบน (header.dart)
  Future<void> _login(BuildContext context) async {
    final auth = authProvider;
    if (auth == null) return;
    // จับ messenger ไว้ก่อนรอผล เข้าสู่ระบบสำเร็จแล้วการ์ดนี้ถูกถอดออก context เดิมใช้ไม่ได้
    final messenger = ScaffoldMessenger.of(context);
    void notify(String text, Color color, IconData icon, int seconds) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: const TextStyle(fontFamily: _font)),
                ),
              ],
            ),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: seconds),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    }

    try {
      final ok = await auth.loginWithThaid();
      if (ok) {
        notify(
          'เข้าสู่ระบบด้วย ThaID สำเร็จ ยินดีต้อนรับ ${auth.displayName}',
          AppTheme.successColor,
          Icons.check_circle,
          4,
        );
      } else if (!auth.isLoggedIn) {
        // กดยกเลิกในแอป ThaID หรือปิดหน้าต่าง ThaID เอง
        notify(thaidCancelledMessage, AppTheme.infoColor, Icons.info_outline, 4);
      }
    } catch (e) {
      if (AppLogger.on) {
        AppLogger.e('เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ', error: e);
      }
      notify(
        'เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ: '
        '${e.toString().replaceAll('Exception: ', '')}',
        AppTheme.dangerColor,
        Icons.error_outline,
        8,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = authProvider;
    final body = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.verified_user, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const RetailThaidNotice(),
            const SizedBox(height: 20),
            if (auth == null)
              Text(
                'กดปุ่ม ThaID ที่แถบด้านบนเพื่อเข้าสู่ระบบ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 14,
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Center(
                child: ListenableBuilder(
                  listenable: auth,
                  builder: (context, _) => SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: auth.thaidBusy ? null : () => _login(context),
                      icon: auth.thaidBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text(
                        'เข้าสู่ระบบด้วย ThaID',
                        style: TextStyle(fontFamily: _font, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(padding: const EdgeInsets.all(16), child: body),
      ),
    );
  }
}
