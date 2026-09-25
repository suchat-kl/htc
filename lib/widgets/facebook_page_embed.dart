// lib/widgets/facebook_page_embed.dart
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

/// กล่องข่าวประชาสัมพันธ์ ฝังเพจ Facebook ของศูนย์ฯ
///
/// ระบบนี้ไม่มีตารางข่าวของตัวเอง ศูนย์ฯ ประกาศข่าวที่เพจ Facebook อยู่แล้ว
/// จึงดึงมาแสดงตรงนี้เลย ไม่ต้องให้ใครมาลงข่าวซ้ำสองที่
/// ระบบเดิมก็ใช้วิธีเดียวกัน
///
/// ใช้ได้เฉพาะ Flutter Web เพราะสร้าง iframe จริงผ่าน platform view
/// โปรเจกต์นี้เป็นเว็บอย่างเดียวจึง import dart:ui_web ตรง ๆ ได้
class FacebookPageEmbed extends StatefulWidget {
  /// URL ของเพจ เช่น https://www.facebook.com/HighwayTraining/
  final String pageUrl;
  final double height;

  const FacebookPageEmbed({
    super.key,
    this.pageUrl = 'https://www.facebook.com/HighwayTraining/',
    this.height = 420,
  });

  @override
  State<FacebookPageEmbed> createState() => _FacebookPageEmbedState();
}

class _FacebookPageEmbedState extends State<FacebookPageEmbed> {
  /// ลงทะเบียน view factory ได้ครั้งเดียวต่อหนึ่ง viewType ตลอดอายุของแอป
  /// ถ้าลงซ้ำจะ assert ตอน hot reload หรือตอนกลับเข้าหน้าเดิม
  static final Set<String> _registered = {};

  /// สร้าง iframe ของเพจตามความกว้างที่มีจริง
  ///
  /// ปลั๊กอินของ Facebook จัดหน้าตามค่า width ที่ส่งไปใน URL ถ้าส่งค่าตายตัว
  /// แล้วเปิดด้วยจอแคบกว่านั้น เนื้อหาจะถูกตัดหายไปทางขวา
  /// จึงต้องส่งความกว้างจริงไปด้วย และปัดเป็นช่วงละ 20 พิกเซล
  /// เพื่อไม่ให้สร้าง view ใหม่ทุกพิกเซลตอนผู้ใช้ลากขยายหน้าต่าง
  String _viewTypeFor(double width) {
    final w = (width / 20).round() * 20;
    final viewType = 'facebook-page-${widget.pageUrl.hashCode}-$w';

    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final src = Uri.https('www.facebook.com', '/plugins/page.php', {
          'href': widget.pageUrl,
          'tabs': 'timeline',
          'width': '$w',
          'height': '${widget.height.round()}',
          'small_header': 'false',
          'adapt_container_width': 'true',
          'hide_cover': 'false',
          'show_facepile': 'false',
          'locale': 'th_TH',
        }).toString();

        final frame = html.IFrameElement()
          ..src = src
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'encrypted-media'
          // กันไม่ให้หน้าที่ฝังเข้ามาสั่งเปิดหน้าต่างหรือเล่นเสียงเอง
          ..setAttribute('scrolling', 'no')
          ..setAttribute('frameborder', '0')
          ..setAttribute('allowfullscreen', 'true');
        return frame;
      });
    }
    return viewType;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ปลั๊กอินรองรับความกว้าง 180-500 นอกช่วงนี้จะจัดหน้าเพี้ยน
        final width = constraints.maxWidth.clamp(180.0, 500.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                // iframe ทึบแสง ทับทุกอย่างที่วางไว้ข้างหลัง
                // จึงไม่วางข้อความสำรองไว้ใต้มัน เพราะจะไม่มีวันได้เห็น
                child: HtmlElementView(viewType: _viewTypeFor(width)),
              ),
            ),
            const SizedBox(height: 10),
            // ทางออกสำรองที่เห็นเสมอ
            //
            // กล่องด้านบนเป็นเนื้อหาจาก facebook.com ซึ่งถูกบล็อกได้หลายทาง
            // ทั้งส่วนขยายกันโฆษณา การตั้งค่ากันการติดตามของเบราว์เซอร์
            // และไฟร์วอลล์ขององค์กร เวลาถูกบล็อกจะเหลือเป็นกล่องขาวเปล่า
            // โดยไม่มีอะไรบอกผู้ใช้เลย ปุ่มนี้จึงต้องอยู่ข้างนอกกล่องเสมอ
            TextButton.icon(
              onPressed: _openPage,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('เปิดเพจ Facebook ของศูนย์ฯ'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'NotoSansThai',
                ),
              ),
            ),
            Text(
              'ถ้ากล่องด้านบนว่าง แสดงว่าเบราว์เซอร์หรือเครือข่ายปิดกั้นเนื้อหาจาก Facebook',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontFamily: 'NotoSansThai',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPage() async {
    final uri = Uri.parse(widget.pageUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
