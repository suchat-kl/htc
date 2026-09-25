// lib/widgets/simple_chart.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// ชนิดกราฟที่รองรับ
enum SimpleChartType { bar, line }

/// หนึ่งจุดข้อมูลของกราฟ
class SimpleChartPoint {
  final String label;
  final num value;

  const SimpleChartPoint(this.label, this.value);
}

/// กราฟแท่งและกราฟเส้นแบบง่าย วาดเองด้วย CustomPainter
///
/// ตั้งใจไม่เพิ่ม package กราฟเข้ามาในโปรเจกต์ เพราะต้องการแค่สองชนิดนี้
/// และ package กราฟส่วนใหญ่ลากของอื่นตามมาเยอะจนไม่คุ้ม
///
/// แกนตั้งเริ่มที่ศูนย์เสมอ ไม่ตัดฐานกราฟ เพราะถ้าตัดจะทำให้ความต่าง
/// ระหว่างเดือนดูเกินจริง ซึ่งเป็นรายงานที่ผู้บริหารเอาไปใช้ตัดสินใจ
class SimpleChart extends StatelessWidget {
  final List<SimpleChartPoint> points;
  final SimpleChartType type;
  final Color color;

  /// หน่วยที่ต่อท้ายค่าในป้ายกำกับ เช่น "ใบ" หรือ "คน"
  final String unit;

  final double height;

  const SimpleChart({
    super.key,
    required this.points,
    required this.type,
    required this.color,
    this.unit = '',
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'ไม่มีข้อมูลในช่วงที่เลือก',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _ChartPainter(
              points: points,
              type: type,
              color: color,
              unit: unit,
              textDirection: Directionality.of(context),
            ),
          );
        },
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<SimpleChartPoint> points;
  final SimpleChartType type;
  final Color color;
  final String unit;
  final TextDirection textDirection;

  _ChartPainter({
    required this.points,
    required this.type,
    required this.color,
    required this.unit,
    required this.textDirection,
  });

  static const double _leftPad = 46;
  static const double _rightPad = 12;
  static const double _topPad = 18;
  static const double _bottomPad = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final maxValue = _niceMax();

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1.2;

    // เส้นแนวนอน 5 ระดับ พร้อมตัวเลขกำกับฝั่งซ้าย
    const steps = 4;
    for (int i = 0; i <= steps; i++) {
      final y = plotBottom - plotHeight * i / steps;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _text(
        canvas,
        _fmt(maxValue * i / steps),
        Offset(plotLeft - 6, y),
        align: TextAlign.right,
        maxWidth: _leftPad - 8,
        anchorRight: true,
        centerVertically: true,
        size: 10,
      );
    }

    canvas.drawLine(
      Offset(plotLeft, plotTop),
      Offset(plotLeft, plotBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plotLeft, plotBottom),
      Offset(plotRight, plotBottom),
      axisPaint,
    );

    final slot = plotWidth / points.length;

    // ป้ายชื่อเดือนใต้แกน วางกลางช่องของตัวเอง
    for (int i = 0; i < points.length; i++) {
      final cx = plotLeft + slot * (i + 0.5);
      _text(
        canvas,
        points[i].label,
        Offset(cx, plotBottom + 6),
        align: TextAlign.center,
        maxWidth: slot,
        centerHorizontally: true,
        size: 10,
      );
    }

    double yOf(num v) => plotBottom - (v / maxValue) * plotHeight;

    if (type == SimpleChartType.bar) {
      final barPaint = Paint()..color = color;
      final barWidth = slot * 0.55;
      for (int i = 0; i < points.length; i++) {
        final v = points[i].value;
        if (v <= 0) continue;
        final cx = plotLeft + slot * (i + 0.5);
        final top = yOf(v);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, plotBottom),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, barPaint);
        _valueLabel(canvas, v, cx, top, slot);
      }
    } else {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final dotPaint = Paint()..color = color;

      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final cx = plotLeft + slot * (i + 0.5);
        final cy = yOf(points[i].value);
        if (i == 0) {
          path.moveTo(cx, cy);
        } else {
          path.lineTo(cx, cy);
        }
      }
      canvas.drawPath(path, linePaint);

      for (int i = 0; i < points.length; i++) {
        final cx = plotLeft + slot * (i + 0.5);
        final cy = yOf(points[i].value);
        canvas.drawCircle(Offset(cx, cy), 3.5, dotPaint);
        if (points[i].value > 0) {
          _valueLabel(canvas, points[i].value, cx, cy, slot);
        }
      }
    }
  }

  /// ตัวเลขกำกับเหนือแท่งหรือจุด ข้ามไปถ้าช่องแคบจนตัวเลขจะทับกัน
  void _valueLabel(Canvas canvas, num v, double cx, double top, double slot) {
    if (slot < 34) return;
    _text(
      canvas,
      _fmt(v),
      Offset(cx, top - 15),
      align: TextAlign.center,
      maxWidth: slot,
      centerHorizontally: true,
      size: 10,
      color: AppTheme.textSecondary,
    );
  }

  /// ปัดค่าสูงสุดขึ้นให้เป็นเลขกลม ๆ เส้นกริดจะได้อ่านง่าย
  double _niceMax() {
    num max = 0;
    for (final p in points) {
      if (p.value > max) max = p.value;
    }
    if (max <= 0) return 4;

    final magnitude = _pow10((max.toDouble()).floor().toString().length - 1);
    final step = magnitude / 2 == 0 ? 1 : magnitude / 2;
    return ((max / step).ceil() * step).toDouble();
  }

  double _pow10(int n) {
    var r = 1.0;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  String _fmt(num v) {
    final rounded = v.round();
    final s = rounded.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _text(
    Canvas canvas,
    String value,
    Offset at, {
    required TextAlign align,
    required double maxWidth,
    bool anchorRight = false,
    bool centerHorizontally = false,
    bool centerVertically = false,
    double size = 11,
    Color color = AppTheme.textPrimary,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: size, color: color),
      ),
      textAlign: align,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    var dx = at.dx;
    if (anchorRight) dx = at.dx - tp.width;
    if (centerHorizontally) dx = at.dx - tp.width / 2;

    var dy = at.dy;
    if (centerVertically) dy = at.dy - tp.height / 2;

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.type != type ||
      old.color != color ||
      old.unit != unit;
}
