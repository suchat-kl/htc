// lib/screens/activity_fiscal_chart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../models/activity_fiscal_chart.dart';
import '../services/api_service.dart';
import '../utils/fiscal_year.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/simple_chart.dart';

/// กราฟการใช้ห้องกิจกรรม ประจำปีงบประมาณ (เมนูรายงาน 16)
///
/// เลือกปีงบประมาณและชนิดกราฟ ดูผลบนหน้าจอได้ทันที
/// ปุ่มพิมพ์จะได้ไฟล์ Excel ที่มีกราฟจริงของ Excel ชนิดเดียวกับที่เลือกไว้
class ActivityFiscalChartScreen extends StatefulWidget {
  final ApiService apiService;

  const ActivityFiscalChartScreen({super.key, required this.apiService});

  @override
  State<ActivityFiscalChartScreen> createState() =>
      _ActivityFiscalChartScreenState();
}

class _ActivityFiscalChartScreenState extends State<ActivityFiscalChartScreen> {
  final TextEditingController _yearCtrl = TextEditingController();

  SimpleChartType _type = SimpleChartType.bar;
  ActivityFiscalChart? _data;
  bool _loading = false;
  bool _printing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _yearCtrl.text = '${FiscalYear.current()}';
    _load();
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  int? get _year {
    final y = int.tryParse(_yearCtrl.text.trim());
    if (y == null || y < 2500 || y > 2700) return null;
    return y;
  }

  Future<void> _load() async {
    final year = _year;
    if (year == null) {
      setState(() => _error = 'กรอกปีงบประมาณ พ.ศ. ให้ถูกต้อง เช่น 2569');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.apiService.getActivityFiscalChart(year: year);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _print() async {
    final year = _year;
    if (year == null) {
      context.showErrorSnackBar('กรอกปีงบประมาณ พ.ศ. ให้ถูกต้อง เช่น 2569');
      return;
    }

    setState(() => _printing = true);
    try {
      final chartType = _type == SimpleChartType.line ? 'line' : 'bar';
      final bytes = await widget.apiService.downloadActivityFiscalChart(
        year: year,
        chartType: chartType,
      );

      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'กราฟการใช้ห้องกิจกรรม_ปีงบประมาณ_$year.xlsx';
      html.document.body!.children.add(anchor);
      anchor.click();
      Future.delayed(const Duration(seconds: 1), () {
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      });

      if (!mounted) return;
      setState(() => _printing = false);
      context.showSuccessSnackBar('ออกรายงานเรียบร้อย');
    } catch (e) {
      if (!mounted) return;
      setState(() => _printing = false);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'กราฟการใช้ห้องกิจกรรม ประจำปีงบประมาณ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterCard(isWide),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _errorBox(_error!)
                else if (_data != null)
                  ..._charts(_data!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterCard(bool isWide) {
    final year = _year;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      labelText: 'ปีงบประมาณ',
                      labelStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<SimpleChartType>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'ชนิดกราฟ',
                      labelStyle: const TextStyle(fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SimpleChartType.bar,
                        child: Text('กราฟแท่ง'),
                      ),
                      DropdownMenuItem(
                        value: SimpleChartType.line,
                        child: Text('กราฟเส้น'),
                      ),
                    ],
                    // เปลี่ยนชนิดกราฟไม่ต้องเรียก API ใหม่ ใช้ข้อมูลชุดเดิมวาดใหม่
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('แสดงกราฟ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _printing ? null : _print,
                  icon: _printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print, size: 18),
                  label: const Text('พิมพ์'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.printColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              year == null
                  ? 'ปีงบประมาณเริ่ม 1 ตุลาคม ของปีก่อน ถึง 30 กันยายน'
                  : 'ครอบคลุม ${FiscalYear.rangeLabel(year)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สองกราฟแยกกัน เพราะจำนวนใบจองกับจำนวนคนคนละสเกล
  /// ถ้าวาดรวมกราฟเดียว เส้นใบจองจะแบนติดแกนจนอ่านไม่ได้
  List<Widget> _charts(ActivityFiscalChart data) {
    return [
      _chartCard(
        title: 'จำนวนใบจอง รายเดือน',
        total: 'รวมทั้งปี ${data.totalBookings} ใบจอง',
        color: AppTheme.primaryColor,
        points: [
          for (final m in data.months) SimpleChartPoint(m.label, m.bookings),
        ],
        unit: 'ใบ',
      ),
      const SizedBox(height: 16),
      _chartCard(
        title: 'จำนวนผู้ใช้บริการ รายเดือน',
        total: 'รวมทั้งปี ${data.totalPeople} คน',
        color: AppTheme.accentColor,
        points: [
          for (final m in data.months) SimpleChartPoint(m.label, m.people),
        ],
        unit: 'คน',
      ),
      const SizedBox(height: 16),
      _tableCard(data),
    ];
  }

  Widget _chartCard({
    required String title,
    required String total,
    required Color color,
    required List<SimpleChartPoint> points,
    required String unit,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SimpleChart(
              points: points,
              type: _type,
              color: color,
              unit: unit,
            ),
          ],
        ),
      ),
    );
  }

  /// ตารางตัวเลขใต้กราฟ เผื่อผู้ใช้อยากเห็นค่าตรง ๆ ไม่ต้องเปิดไฟล์
  Widget _tableCard(ActivityFiscalChart data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ตารางข้อมูล',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('เดือน')),
                  DataColumn(label: Text('จำนวนใบจอง'), numeric: true),
                  DataColumn(label: Text('จำนวนผู้ใช้บริการ (คน)'), numeric: true),
                ],
                rows: [
                  for (final m in data.months)
                    DataRow(
                      cells: [
                        DataCell(Text(m.label)),
                        DataCell(Text('${m.bookings}')),
                        DataCell(Text('${m.people}')),
                      ],
                    ),
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'รวมทั้งปี',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${data.totalBookings}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${data.totalPeople}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.dangerColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.dangerColor),
            ),
          ),
        ],
      ),
    );
  }
}
