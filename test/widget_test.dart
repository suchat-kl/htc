// Widget test สำหรับ NewsCard
//
// เลือก NewsCard เพราะเป็น StatelessWidget ล้วน ไม่มี Timer และไม่ยิง network
// ต่างจากการ pump ทั้งแอป (HighwayTrainingApp) ที่ HomeScreen.initState จะเริ่ม
// auto-play Timer และเรียก API ticker ทำให้เทสต์ค้างและ flaky

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highway_training/widgets/news_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    ),
  );
}

void main() {
  group('NewsCard', () {
    testWidgets('แสดง หัวข้อ วันที่ และคำอธิบาย ครบ', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NewsCard(
            title: 'เปิดรับสมัครหลักสูตรงานทาง',
            date: '4 ก.ย. 2569',
            description: 'รับสมัครผู้เข้าอบรมรุ่นที่ 12 ตั้งแต่วันนี้เป็นต้นไป',
            imageUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('เปิดรับสมัครหลักสูตรงานทาง'), findsOneWidget);
      expect(find.text('4 ก.ย. 2569'), findsOneWidget);
      expect(
        find.text('รับสมัครผู้เข้าอบรมรุ่นที่ 12 ตั้งแต่วันนี้เป็นต้นไป'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.article), findsOneWidget);
    });

    testWidgets('แตะแล้วเรียก onTap', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        _wrap(
          NewsCard(
            title: 'ข่าวทดสอบ',
            date: '1 ม.ค. 2569',
            description: 'คำอธิบาย',
            imageUrl: '',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('ข่าวทดสอบ'));
      await tester.pump();

      expect(taps, 1);
    });

    // ขนาดที่วัดได้รวม margin ขวา 16 ของการ์ดด้วย
    // desktop: 300 + 16 = 316, mobile: 250 + 16 = 266
    testWidgets('isDesktop เปลี่ยนความกว้างการ์ด 300 -> 250', (tester) async {
      Future<double> widthFor(bool isDesktop) async {
        await tester.pumpWidget(
          _wrap(
            NewsCard(
              title: 'ข่าว',
              date: '1 ม.ค. 2569',
              description: 'คำอธิบาย',
              imageUrl: '',
              onTap: () {},
              isDesktop: isDesktop,
            ),
          ),
        );
        return tester.getSize(find.byType(NewsCard)).width;
      }

      const margin = 16.0;

      expect(await widthFor(true), 300 + margin);
      expect(await widthFor(false), 250 + margin);
    });
  });
}
