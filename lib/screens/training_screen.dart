import 'package:flutter/material.dart';
import '../config/theme.dart';

class TrainingScreen extends StatelessWidget {
  /// `true` เมื่อถูกฝังเป็นแท็บใน MainNavigation ซึ่งมี Scaffold อยู่แล้ว
  /// จะไม่สร้าง Scaffold ซ้อนอีกชั้น
  final bool embedded;

  const TrainingScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หลักสูตรฝึกอบรม',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'เลือกหลักสูตรที่เหมาะสมกับความต้องการของคุณ',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.5,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.school,
                            color: AppTheme.primaryColor,
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'หลักสูตรที่ ${index + 1}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ระยะเวลา: 3 วัน',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const Text(
                        'จำนวนผู้เข้าอบรม: 30 คน',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('ลงทะเบียน'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return embedded ? body : Scaffold(body: body);
  }
}
