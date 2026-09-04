import 'dart:typed_data';

import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:universal_html/html.dart' as html;
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

class CommodityReportScreen extends StatefulWidget {
  final ApiService apiService;
  const CommodityReportScreen({super.key, required this.apiService});

  @override
  State<CommodityReportScreen> createState() => _CommodityReportScreenState();
}

class _CommodityReportScreenState extends State<CommodityReportScreen> {
  final ApiService _apiService = ApiService();
  List<Commodity> _commodities = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'B';
  String? _errorMessage;

  static const List<Map<String, String>> _types = [
    {'code': 'B', 'name': 'เครื่องนอน'},
    {'code': 'C', 'name': 'ของใช้'},
  ];

  // String _formatThaiDate(DateTime date) {
  //   final thaiYear = date.year + 543;
  //   final thaiMonths = [
  //     'มกราคม',
  //     'กุมภาพันธ์',
  //     'มีนาคม',
  //     'เมษายน',
  //     'พฤษภาคม',
  //     'มิถุนายน',
  //     'กรกฎาคม',
  //     'สิงหาคม',
  //     'กันยายน',
  //     'ตุลาคม',
  //     'พฤศจิกายน',
  //     'ธันวาคม',
  //   ];
  //   return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  // }

  // String _formatDateForApi(DateTime date) {
  //   return DateFormat('dd/MM/yyyy').format(date);
  // }

  // ✅ Simplified: Just call API service
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final commodities = await _apiService.getCommoditiesByType(_selectedType);
      if (mounted) {
        setState(() {
          _commodities = commodities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // ✅ Simplified: Just call API service and handle download
  /*Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final dateStr = _formatDateForApi(_selectedDate);
      final bytes = await _apiService.downloadCommodityReport(
        type: _selectedType,
        date: dateStr,
      );

      // Download file in browser
      final blob = html.Blob([
        bytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'ใบเติมของใช้_$dateStr.xlsx';
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        context.showSuccessSnackBar('ดาวน์โหลดรายงานสำเร็จ');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
  */
  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      // final dateStr = _formatDateForApi(_selectedDate);

      final dateStr = Util.formatThaiDate(_selectedDate);

      final bytes = await _apiService.downloadCommodityReport(
        type: _selectedType,
        date: dateStr,
      );

      // ✅ Verify the bytes are not empty and look like an Excel file
      if (bytes.isEmpty) {
        throw Exception('ไฟล์รายงานว่างเปล่า');
      }

      AppLogger.d('Downloaded report: ${bytes.length} bytes');
      AppLogger.d(
        'First bytes: ${bytes.take(8).map((b) => b.toRadixString(16)).join(' ')}',
      );

      // ✅ Create blob with correct MIME type
      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'ใบเติมของใช้_$dateStr.xlsx';
      html.document.body!.children.add(anchor);
      anchor.click();

      // Cleanup
      Future.delayed(const Duration(seconds: 1), () {
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });

      if (mounted) {
        context.showSuccessSnackBar('ดาวน์โหลดรายงานสำเร็จ');
      }
    } catch (e) {
      AppLogger.d('Report download error: $e');
      if (mounted) {
        context.showErrorSnackBar('ดาวน์โหลดรายงานไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ✅ Date picker already works
// late DateTime dateNow ;//= DateTime.now();
  Future<void> _selectDate() async {
    
    // AppLogger.d("dateNow $dateNow");
    // int y = dateNow.year;
    final DateTime? picked; //=
    picked = await Util.dateFieldPicker(context,  _selectedDate);
    if (picked != _selectedDate) {
      setState(() => _selectedDate = picked!);
    }
    /*
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(y, 1, 1),
      lastDate: DateTime(y, 12, 31),
      locale: const Locale('th'),
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
      fieldLabelText: 'วันที่',
      fieldHintText: 'วัน/เดือน/ปี',
      errorFormatText: 'รูปแบบวันที่ไม่ถูกต้อง',
      errorInvalidText: 'วันที่ไม่ถูกต้อง',
      // ✅ Add today button
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick select buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, DateTime.now());
                    },
                    child: const Text('วันนี้'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedDate);
                    },
                    child: const Text('ยกเลิก'),
                  ),
                ],
              ),
            ),
            Expanded(child: child!),
          ],
        );
      },
    );

*/
    // if (picked != null && picked != _selectedDate) {
    //   setState(() {
    //     _selectedDate = picked;
    //   });
    // }
  }
  /*
  // ✅ Thai date display
  String _formatThaiDate(DateTime date) {
    final thaiYear = date.year + 543;
    final thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  }
*/
  // ✅ API date format
  // String _formatDateForApi(DateTime date) {
  //   return DateFormat('dd/MM/yyyy').format(date);
  // }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    // Create instance
    // final util = Util();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'ใบเติมของใช้',
          style: TextStyle(
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Date Picker
                  // The date picker trigger - user taps this to open calendar
                  InkWell(
                    onTap: _selectDate, // ✅ Opens date picker
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isDesktop ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: isDesktop ? 22 : 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            Util.formatThaiDate(
                              _selectedDate,
                            ), // ✅ Shows selected date in Thai
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Type Dropdown
                  SizedBox(
                    width: isDesktop ? 180 : 160,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        labelText: 'ประเภท',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isDesktop ? 14 : 10,
                        ),
                      ),
                      items: _types
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t['code'],
                              child: Text(
                                t['name']!,
                                style: TextStyle(fontSize: bodyFontSize),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                  ),
                  // Search Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadData,
                    icon: Icon(Icons.search, size: isDesktop ? 22 : 18),
                    label: Text(
                      'ค้นหา',
                      style: TextStyle(fontSize: bodyFontSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: isDesktop ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Report Button
                  ElevatedButton.icon(
                    onPressed: (_isDownloading || _commodities.isEmpty)
                        ? null
                        : _downloadReport,
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
                      'รายงาน',
                      style: TextStyle(fontSize: bodyFontSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: isDesktop ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Error
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _commodities.isEmpty
                ? Center(
                    child: Text(
                      'กรุณากดค้นหาเพื่อแสดงข้อมูล',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppTheme.primaryColor.withValues(alpha: 0.08),
                            ),
                            headingRowHeight: 56,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 60,
                            columnSpacing: 20,
                            columns: [
                              DataColumn(
                                label: SizedBox(
                                  width: 80,
                                  child: Text(
                                    'ห้อง',
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              ..._commodities.map(
                                (c) => DataColumn(
                                  label: SizedBox(
                                    width: 120,
                                    child: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: bodyFontSize - 1,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: List.generate(
                              1,
                              (rowIndex) => DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '',
                                        // '${rowIndex + 1}',
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  ..._commodities.map(
                                    (c) => DataCell(
                                      Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 0.5,
                                          ),
                                        ),
                                        child: const SizedBox(height: 40),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  @override
  void initState() {
    
    super.initState();
    //  dateNow = DateTime.now();
  }
}
