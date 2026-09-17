// lib/widgets/app_autocomplete_field.dart
import 'package:flutter/material.dart';

/// ช่องกรอกข้อความแบบ autocomplete — widget กลางของระบบ
///
/// พิมพ์แล้วจะแนะนำค่าจาก [options] ที่มีคำนั้นอยู่ (ไม่สนตัวพิมพ์เล็กใหญ่)
/// คลิกช่องว่างๆ จะเห็นรายการทั้งหมด เลือกแล้วค่าจะลงใน [controller]
///
/// พิมพ์ค่าที่ไม่มีในรายการก็ได้ ผู้เรียกอ่านค่าจาก [controller] ตรงๆ
/// เหมาะกับช่องค้นหาที่ส่งต่อไปทำ LIKE %x% ฝั่ง backend
///
/// [options] โหลดมาทั้งหมดครั้งเดียวแล้วกรองในเครื่อง เหมาะกับรายการหลักร้อย
/// ถ้าข้อมูลเยอะกว่านั้นควรทำเวอร์ชันที่ยิง API ตามคำที่พิมพ์พร้อม debounce
class AppAutocompleteField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;

  /// กำลังโหลด [options] อยู่ — แสดงตัวหมุนท้ายช่องแทนไอคอนค้นหา
  final bool loading;

  final double width;

  /// จำนวนรายการแนะนำสูงสุดที่แสดง กันรายการยาวเกินจอ
  final int maxOptions;

  final ValueChanged<String>? onSelected;

  const AppAutocompleteField({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    this.loading = false,
    this.width = 220,
    this.maxOptions = 30,
    this.onSelected,
  });

  @override
  State<AppAutocompleteField> createState() => _AppAutocompleteFieldState();
}

class _AppAutocompleteFieldState extends State<AppAutocompleteField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _filter(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(q));
    return matches.take(widget.maxOptions);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: _filter,
        onSelected: widget.onSelected,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmitted(),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: widget.label,
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
              suffixIcon: widget.loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search, size: 18),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: widget.width,
                  maxHeight: 260,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final option = options.elementAt(i);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
