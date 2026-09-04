import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DebugPanel extends StatefulWidget {
  const DebugPanel({super.key});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  final _apiService = ApiService();
  String _testResult = '';
  bool _isTesting = false;

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _testResult = 'กำลังทดสอบ...\n';
    });

    // Test 1: Check internet connectivity
    setState(() {
      _testResult += '1. ทดสอบการเชื่อมต่ออินเทอร์เน็ต...\n';
    });

    // Test 2: Try to connect to the API
    setState(() {
      _testResult += '2. ทดสอบการเชื่อมต่อกับ API...\n';
    });

    final result = await _apiService.testConnection();
    setState(() {
      _testResult += '   ผลลัพธ์: ${result['message']}\n';
      if (result['success'] == false) {
        _testResult += '   ข้อผิดพลาด: ${result['error']}\n';
      }
    });

    // Test 3: Try login with curl equivalent
    setState(() {
      _testResult += '\n3. ทดสอบการล็อกอินด้วย curl:\n';
      _testResult +=
          '   curl --location \'${ApiService.baseUrl}/api/auth/login\' \\\n';
      _testResult += '   --header \'Content-Type: application/json\' \\\n';
      _testResult +=
          '   --data-raw \'{"username":"test","password":"test"}\'\n';
    });

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Debug Panel - ทดสอบการเชื่อมต่อ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // URL Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API URL:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(ApiService.baseUrl),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Test Results
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _testResult.isEmpty
                      ? 'กดปุ่ม "ทดสอบ" เพื่อเริ่ม'
                      : _testResult,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _runTests,
                    child: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ทดสอบ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ปิด'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
