import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/commodity.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:universal_html/html.dart' as html;
import '../utils/util.dart';
import 'package:highway_training/utils/logger.dart';

/// ห้องพักหนึ่งห้องที่ใช้งานในวันที่เลือก checkout = ออกวันนั้น (ห้องที่ต้องรื้อเครื่องนอน)
class _RoomLine {
  final String roomNo;
  final bool checkout;

  const _RoomLine({required this.roomNo, required this.checkout});

  factory _RoomLine.fromJson(Map<String, dynamic> json) => _RoomLine(
    roomNo: json['roomNo']?.toString() ?? '',
    checkout: json['checkout'] == true,
  );
}

/// หน้า "การจัดการวัสดุห้องพัก" (เมนู OP_BEDDING)
///
/// เลือกวันที่และแบบฟอร์ม แล้วแสดงห้องพักที่ใช้งานวันนั้น (มีผู้พักคืนนั้นหรือ check out)
/// หนึ่งแถวต่อห้อง คอลัมน์คือเครื่องนอน/ของใช้ที่ยังใช้งาน เรียงตามช่อง "ลำดับ"
/// ในหน้าเครื่องนอน-ของใช้ ปุ่มรายงานออกไฟล์ Excel ชื่อเอกสารเดิม
/// (ใบรื้อเครื่องนอน / ใบเติมของใช้) ไว้พิมพ์ให้เจ้าหน้าที่กรอก
class CommodityReportScreen extends StatefulWidget {
  final ApiService apiService;
  const CommodityReportScreen({super.key, required this.apiService});

  @override
  State<CommodityReportScreen> createState() => _CommodityReportScreenState();
}

class _CommodityReportScreenState extends State<CommodityReportScreen> {
  final ApiService _apiService = ApiService();
  List<Commodity> _commodities = [];
  List<_RoomLine> _rooms = [];
  bool _isLoading = false;
  bool _isDownloading = false;
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'B';
  String? _errorMessage;

  /// ชื่อในรายการคือชื่อเอกสารเดิมที่เจ้าหน้าที่คุ้น
  static const List<Map<String, String>> _types = [
    {'code': 'B', 'name': 'ใบรื้อเครื่องนอน'},
    {'code': 'C', 'name': 'ใบเติมของใช้'},
  ];

  String get _formName =>
      _types.firstWhere((t) => t['code'] == _selectedType)['name']!;

  /// วันที่ส่งให้ API เป็น yyyy-MM-dd (ค.ศ.)
  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// เปลี่ยนวันที่หรือแบบฟอร์มแล้วล้างตาราง ให้กดค้นหาใหม่ จะได้ไม่เห็นห้องของวันเดิม
  void _clearResult() {
    _commodities = [];
    _rooms = [];
    _errorMessage = null;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // ใช้ path เดียวกับไฟล์ Excel (สิทธิ์ OP_BEDDING) จึงเรียก dio ตรงจากหน้านี้
      final response = await _apiService.dio.get(
        '/api/auth/report/commodity',
        queryParameters: {
          'type': _selectedType,
          'date': _isoDate(_selectedDate),
          'format': 'json',
        },
      );
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(
          data is Map && data['message'] != null
              ? data['message'].toString()
              : 'ไม่สามารถโหลดข้อมูลได้',
        );
      }
      final commodities = (data['commodities'] as List? ?? [])
          .map((j) => Commodity.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      final rooms = (data['rooms'] as List? ?? [])
          .map((j) => _RoomLine.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _commodities = commodities;
          _rooms = rooms;
          _isLoading = false;
          if (commodities.isEmpty) {
            _errorMessage =
                'ไม่พบรายการ${_selectedType == 'B' ? 'เครื่องนอน' : 'ของใช้'}ที่ใช้งาน';
          }
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.e('โหลดข้อมูลใบเครื่องนอน/ของใช้ไม่สำเร็จ: $e');
      // เซิร์ฟเวอร์ตอบ 400 พร้อมข้อความไทย ให้แสดงข้อความนั้นแทนข้อความของ Dio
      final body = e is DioException ? e.response?.data : null;
      final reason = body is Map && body['message'] != null
          ? body['message'].toString()
          : e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $reason';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final dateStr = _isoDate(_selectedDate);

      final bytes = await _apiService.downloadCommodityReport(
        type: _selectedType,
        date: dateStr,
      );

      if (bytes.isEmpty) {
        throw Exception('ไฟล์รายงานว่างเปล่า');
      }

      if (AppLogger.on) AppLogger.d('Downloaded report: ${bytes.length} bytes');

      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = '${_formName}_$dateStr.xlsx';
      html.document.body!.children.add(anchor);
      anchor.click();

      Future.delayed(const Duration(seconds: 1), () {
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });

      if (mounted) {
        context.showSuccessSnackBar('ดาวน์โหลดรายงานสำเร็จ');
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Report download error: $e');
      if (mounted) {
        context.showErrorSnackBar('ดาวน์โหลดรายงานไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await Util.dateFieldPickerNullable(
      context,
      _selectedDate,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _clearResult();
      });
    }
  }

  /// สรุปจำนวนห้องเหนือตาราง
  Widget _roomSummary(double fontSize) {
    final checkout = _rooms.where((r) => r.checkout).length;
    final text = _rooms.isEmpty
        ? 'ไม่มีห้องพักที่มีผู้พักหรือ check out ในวันที่ ${Util.formatThaiDate(_selectedDate)}'
        : '$_formName วันที่ ${Util.formatThaiDate(_selectedDate)} — '
              'ห้องพักที่ใช้งาน ${_rooms.length} ห้อง'
              '${checkout > 0 ? ' (check out $checkout ห้อง)' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Sarabun',
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: _rooms.isEmpty ? Colors.grey.shade600 : AppTheme.primaryColor,
        ),
      ),
    );
  }

  DataColumn _headerColumn(String text, double width, double fontSize) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Sarabun',
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  DataCell _textCell(String text, double width, double fontSize) {
    return DataCell(
      SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(fontFamily: 'Sarabun', fontSize: fontSize),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// ช่องของใช้เว้นว่างไว้ ใบนี้พิมพ์ไปให้เจ้าหน้าที่กรอกจำนวนเอง
  DataCell _blankCell() {
    return DataCell(
      Container(
        width: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: const SizedBox(height: 40),
      ),
    );
  }

  List<DataRow> _rows(double fontSize) {
    if (_rooms.isEmpty) {
      return [
        DataRow(
          cells: [
            _textCell('', 50, fontSize),
            _textCell('-', 80, fontSize),
            ..._commodities.map((_) => _blankCell()),
            _textCell('', 100, fontSize),
          ],
        ),
      ];
    }
    return List.generate(_rooms.length, (i) {
      final room = _rooms[i];
      return DataRow(
        cells: [
          _textCell('${i + 1}', 50, fontSize),
          DataCell(
            SizedBox(
              width: 80,
              child: Text(
                room.roomNo,
                style: TextStyle(
                  fontFamily: 'Sarabun',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          ..._commodities.map((_) => _blankCell()),
          DataCell(
            SizedBox(
              width: 100,
              child: room.checkout
                  ? Text(
                      'check out',
                      style: TextStyle(
                        fontFamily: 'Sarabun',
                        fontSize: fontSize - 1,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'กลับหน้าหลัก',
        ),
        title: Text(
          'การจัดการวัสดุห้องพัก',
          style: TextStyle(
            fontFamily: 'Sarabun',
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
          // แถบเลือกเงื่อนไข
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
                  // วันที่ — กดเพื่อเปิดปฏิทิน พ.ศ.
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isDesktop ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.fieldFillColor,
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
                            Util.formatThaiDate(_selectedDate),
                            style: TextStyle(
                              fontFamily: 'Sarabun',
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // แบบฟอร์ม
                  SizedBox(
                    width: isDesktop ? 220 : 200,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      style: TextStyle(
                        fontFamily: 'Sarabun',
                        fontSize: bodyFontSize,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'แบบฟอร์ม',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.fieldFillColor,
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
                                style: TextStyle(
                                  fontFamily: 'Sarabun',
                                  fontSize: bodyFontSize,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedType = v!;
                        _clearResult();
                      }),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadData,
                    icon: Icon(Icons.search, size: isDesktop ? 22 : 18),
                    label: Text(
                      'ค้นหา',
                      style: TextStyle(
                        fontFamily: 'Sarabun',
                        fontSize: bodyFontSize,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.searchColor,
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
                      style: TextStyle(
                        fontFamily: 'Sarabun',
                        fontSize: bodyFontSize,
                      ),
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
                style: TextStyle(
                  fontFamily: 'Sarabun',
                  color: Colors.red.shade700,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _commodities.isEmpty
                ? Center(
                    child: Text(
                      'กรุณากดค้นหาเพื่อแสดงข้อมูล',
                      style: TextStyle(
                        fontFamily: 'Sarabun',
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _roomSummary(bodyFontSize),
                        Card(
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
                                  _headerColumn('ลำดับ', 50, bodyFontSize),
                                  _headerColumn('ห้อง', 80, bodyFontSize),
                                  ..._commodities.map(
                                    (c) => _headerColumn(
                                      c.name,
                                      120,
                                      bodyFontSize - 1,
                                    ),
                                  ),
                                  _headerColumn('หมายเหตุ', 100, bodyFontSize),
                                ],
                                rows: _rows(bodyFontSize),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
