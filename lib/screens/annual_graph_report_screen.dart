// lib/screens/annual_graph_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/fiscal_year.dart';
import '../utils/snackbar_helper.dart';

/// เงื่อนไขที่หัวข้อหนึ่งต้องการ
enum _Condition {
  /// ปีงบประมาณเดียว
  year,

  /// ช่วงปีงบประมาณ สำหรับหัวข้อเปรียบเทียบหลายปี
  yearRange,
}

/// หัวข้อหนึ่งในเมนูกราฟรายงานประจำปี
class _Topic {
  /// ส่วนท้ายของ path ที่ backend เช่น 'av' → /api/auth/report/annual/av
  final String path;
  final String title;
  final String detail;
  final IconData icon;
  final _Condition condition;

  /// ชื่อไฟล์ที่ดาวน์โหลด ต่อท้ายด้วยปีให้เอง
  final String fileBase;

  const _Topic({
    required this.path,
    required this.title,
    required this.detail,
    required this.icon,
    required this.fileBase,
    this.condition = _Condition.year,
  });
}

/// รายการหัวข้อ เรียงตามลำดับหน้าในรายงานประจำปีของศูนย์ฯ
///
/// หน้าคะแนนความพึงพอใจ ข้อเสนอแนะ และผลประเมินคุณภาพ ไม่อยู่ในรายการ
/// เพราะระบบไม่ได้เก็บข้อมูลเหล่านั้น (ผู้ใช้ยืนยันแล้ว)
const List<_Topic> _topics = [
  _Topic(
    path: 'service-summary',
    title: 'สรุปการให้บริการสถานที่',
    detail:
        'จำนวนคน คืน ห้องพัก และวันใช้ห้องประชุม แยกรายเดือนและตามประเภทผู้ใช้บริการ '
        'พร้อมตารางร้อยละและกราฟสัดส่วน',
    icon: Icons.summarize_outlined,
    fileBase: 'สรุปการให้บริการสถานที่',
  ),
  _Topic(
    path: 'rate-trend',
    title: 'อัตราการใช้ห้องพัก และห้องประชุม เปรียบเทียบหลายปี',
    detail:
        'ร้อยละการใช้ห้องรายปี (ค่าเฉลี่ย 12 เดือนของตารางเทียบขีดความสามารถ) '
        'กราฟแท่งคู่ห้องพักกับห้องประชุม (สูงสุด 10 ปี)',
    icon: Icons.stacked_bar_chart,
    fileBase: 'อัตราการใช้ห้อง',
    condition: _Condition.yearRange,
  ),
  _Topic(
    path: 'lodging-days',
    title: 'ปริมาณการใช้ห้องพัก (วัน) แยกรายเดือน',
    detail:
        'จำนวนวันในแต่ละเดือนที่มีห้องพักถูกใช้อย่างน้อยหนึ่งห้อง พร้อมกราฟเส้น',
    icon: Icons.show_chart,
    fileBase: 'ปริมาณการใช้ห้องพักรายเดือน',
  ),
  _Topic(
    path: 'lodging-capacity',
    title: 'ปริมาณการใช้ห้องพัก เปรียบเทียบกับขีดความสามารถ',
    detail:
        'ร้อยละการใช้ห้องพักรายเดือน แยกกองฝึกอบรมกับหน่วยงานอื่น และค่าเฉลี่ยทั้งปี',
    icon: Icons.hotel_outlined,
    fileBase: 'ขีดความสามารถห้องพัก',
  ),
  _Topic(
    path: 'projects',
    title: 'โครงการอบรม / สัมมนา ที่ใช้ห้องประชุม',
    detail:
        'รายชื่อหลักสูตรของกองฝึกอบรม และโครงการของหน่วยงานอื่น พร้อมจำนวนผู้เข้าร่วม',
    icon: Icons.groups_outlined,
    fileBase: 'โครงการที่ใช้ห้องประชุม',
  ),
  _Topic(
    path: 'meeting-rooms',
    title: 'การใช้ห้องประชุม แยกรายห้อง',
    detail:
        'ตารางจำนวนวันที่ใช้แต่ละห้องรายเดือน กราฟเส้นรายเดือน และกราฟวงกลมสัดส่วนรายห้อง',
    icon: Icons.meeting_room_outlined,
    fileBase: 'การใช้ห้องประชุมรายห้อง',
  ),
  _Topic(
    path: 'meeting-capacity',
    title: 'ปริมาณการใช้ห้องประชุม เปรียบเทียบกับขีดความสามารถ',
    detail:
        'ร้อยละการใช้ห้องประชุมรายเดือน แยกกองฝึกอบรมกับหน่วยงานอื่น และค่าเฉลี่ยทั้งปี',
    icon: Icons.co_present_outlined,
    fileBase: 'ขีดความสามารถห้องประชุม',
  ),
  _Topic(
    path: 'training-trend',
    title: 'จำนวนผู้เข้ารับการฝึกอบรม และจำนวนหลักสูตร เปรียบเทียบหลายปี',
    detail:
        'เฉพาะหลักสูตรที่ดำเนินการโดยกองฝึกอบรม กราฟแท่งเปรียบเทียบรายปี (สูงสุด 10 ปี)',
    icon: Icons.bar_chart,
    fileBase: 'ผู้เข้าอบรมและหลักสูตร',
    condition: _Condition.yearRange,
  ),
  _Topic(
    path: 'av',
    title: 'การให้บริการโสตทัศนูปกรณ์',
    detail:
        'จำนวนครั้งรายเดือนแยกกองฝึกอบรมกับหน่วยงานอื่น กราฟวงกลมสัดส่วน และกราฟเส้นรายเดือน',
    icon: Icons.videocam_outlined,
    fileBase: 'การให้บริการโสตทัศนูปกรณ์',
  ),
  _Topic(
    path: 'maintenance',
    title: 'การให้บริการซ่อมบำรุง',
    detail:
        'งานไฟฟ้า ประปา และอาคารสถานที่ รายเดือนและแยกอาคาร พร้อมกราฟแท่งและกราฟวงกลม',
    icon: Icons.build_outlined,
    fileBase: 'การให้บริการซ่อมบำรุง',
  ),
  _Topic(
    path: 'lodging-daily',
    title: 'ปริมาณการใช้ห้องพักรายวัน (ภาคผนวก)',
    detail: 'ตารางรายวันทั้งปีงบประมาณ จำนวนคืน จำนวนห้อง และร้อยละของทุกวัน',
    icon: Icons.calendar_month_outlined,
    fileBase: 'ปริมาณการใช้ห้องพักรายวัน',
  ),
];

/// หน้าจอกราฟรายงานประจำปี — เลือกหัวข้อ กรอกเงื่อนไข แล้วออกไฟล์ Excel
///
/// ทุกหัวข้อถอดแบบมาจากรายงานประจำปีของศูนย์ฯ และออกเป็น Excel อย่างเดียว
/// ตามที่ผู้ใช้กำหนด เพื่อเอาตัวเลขและกราฟไปใช้ต่อในเอกสารอื่น
class AnnualGraphReportScreen extends StatefulWidget {
  final ApiService apiService;

  const AnnualGraphReportScreen({super.key, required this.apiService});

  @override
  State<AnnualGraphReportScreen> createState() =>
      _AnnualGraphReportScreenState();
}

class _AnnualGraphReportScreenState extends State<AnnualGraphReportScreen> {
  static const String _font = 'NotoSansThai';
  static const int _maxYears = 10;

  final TextEditingController _yearCtrl = TextEditingController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  int? _selected;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final now = FiscalYear.current();
    _yearCtrl.text = '$now';
    // ค่าตั้งต้นเปรียบเทียบ 4 ปีแบบในเล่ม
    _fromCtrl.text = '${now - 3}';
    _toCtrl.text = '$now';
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  static int? _parseYear(TextEditingController c) {
    final y = int.tryParse(c.text.trim());
    return (y == null || y < 2500 || y > 2700) ? null : y;
  }

  /// ตรวจเงื่อนไขแล้วคืนพารามิเตอร์กับส่วนท้ายชื่อไฟล์ ผิดเงื่อนไขคืน null พร้อมแจ้งผู้ใช้
  (Map<String, dynamic>, String)? _params(_Topic t) {
    if (t.condition == _Condition.year) {
      final y = _parseYear(_yearCtrl);
      if (y == null) {
        context.showErrorSnackBar('กรอกปีงบประมาณ พ.ศ. ให้ถูกต้อง เช่น 2569');
        return null;
      }
      return ({'year': y}, '$y');
    }
    final from = _parseYear(_fromCtrl);
    final to = _parseYear(_toCtrl);
    if (from == null || to == null) {
      context.showErrorSnackBar(
        'กรอกปีงบประมาณ พ.ศ. ทั้งสองช่องให้ถูกต้อง เช่น 2566 ถึง 2569',
      );
      return null;
    }
    if (from > to) {
      context.showErrorSnackBar('ปีเริ่มต้นต้องไม่มากกว่าปีสิ้นสุด');
      return null;
    }
    if (to - from + 1 > _maxYears) {
      context.showErrorSnackBar('เปรียบเทียบได้ไม่เกิน $_maxYears ปี');
      return null;
    }
    return ({'fromYear': from, 'toYear': to}, '$from-$to');
  }

  Future<void> _download(_Topic t) async {
    final p = _params(t);
    if (p == null) return;

    setState(() => _printing = true);
    try {
      final bytes = await widget.apiService.downloadAnnualReport(t.path, p.$1);

      final blob = html.Blob([
        Uint8List.fromList(bytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = '${t.fileBase}_${p.$2}.xlsx';
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'กราฟรายงานประจำปี',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: _font,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'เลือกหัวข้อรายงาน แล้วกรอกเงื่อนไข ทุกหัวข้อออกเป็นไฟล์ Excel '
                  'ที่มีทั้งตารางข้อมูลและกราฟ นำไปใช้ต่อได้',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontFamily: _font,
                  ),
                ),
              ),
              for (int i = 0; i < _topics.length; i++) _topicCard(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topicCard(int i) {
    final t = _topics[i];
    final selected = _selected == i;

    return Card(
      elevation: selected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _printing
                ? null
                : () => setState(() => _selected = selected ? null : i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryPale,
                    child: Icon(t.icon, size: 22, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${t.title}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: _font,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.detail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontFamily: _font,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (selected) _conditionPanel(t),
        ],
      ),
    );
  }

  /// ส่วนเงื่อนไขที่กางออกใต้หัวข้อที่เลือก
  Widget _conditionPanel(_Topic t) {
    return Container(
      color: AppTheme.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          t.condition == _Condition.year ? _yearField() : _rangeFields(),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              const Text(
                'ออกเป็นไฟล์ Excel เท่านั้น',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontFamily: _font,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _printing ? null : () => _download(t),
                icon: _printing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text(
                  'ออกรายงาน Excel',
                  style: TextStyle(fontFamily: _font),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.printColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearField() {
    final year = _parseYear(_yearCtrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 180, child: _yearInput(_yearCtrl, 'ปีงบประมาณ')),
        const SizedBox(height: 8),
        // บอกช่วงวันที่ให้ชัด เพราะคนมักเข้าใจว่าปีงบประมาณ = ปีปฏิทิน
        Text(
          year == null
              ? 'ปีงบประมาณเริ่ม 1 ตุลาคม ของปีก่อน ถึง 30 กันยายน'
              : 'ครอบคลุม ${FiscalYear.rangeLabel(year)}',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontFamily: _font,
          ),
        ),
      ],
    );
  }

  Widget _rangeFields() {
    final from = _parseYear(_fromCtrl);
    final to = _parseYear(_toCtrl);
    final count = (from != null && to != null && to >= from)
        ? to - from + 1
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: _yearInput(_fromCtrl, 'ตั้งแต่ปีงบประมาณ'),
            ),
            const Text('ถึง', style: TextStyle(fontFamily: _font)),
            SizedBox(width: 160, child: _yearInput(_toCtrl, 'ถึงปีงบประมาณ')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          count == null
              ? 'เปรียบเทียบได้ไม่เกิน $_maxYears ปี'
              : 'เปรียบเทียบ $count ปี (ไม่เกิน $_maxYears ปี)',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontFamily: _font,
          ),
        ),
      ],
    );
  }

  Widget _yearInput(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textAlign: TextAlign.right,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontFamily: _font),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, fontFamily: _font),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
    );
  }
}
