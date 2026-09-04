import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/foodtype.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class FoodtypeDialog extends StatefulWidget {
  final Foodtype? foodtype;
  final ApiService apiService;
  const FoodtypeDialog({super.key, this.foodtype, required this.apiService});

  @override
  State<FoodtypeDialog> createState() => _FoodtypeDialogState();
}

class _FoodtypeDialogState extends State<FoodtypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(),
      _priceCtrl = TextEditingController(),
      _sectionCtrl = TextEditingController(),
      _seqCtrl = TextEditingController();
  int _group = 1;
  bool _loading = false;
  String? _err;
  bool get isEdit => widget.foodtype != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameCtrl.text = widget.foodtype!.name ?? '';
      _priceCtrl.text = '${widget.foodtype!.price ?? 0}';
      _sectionCtrl.text = widget.foodtype!.section ?? '';
      _seqCtrl.text = '${widget.foodtype!.sequence ?? 0}';
      _group = widget.foodtype!.foodgroupID ?? 1;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sectionCtrl.dispose();
    _seqCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = Foodtype(
        id: widget.foodtype?.id,
        foodgroupID: _group,
        name: _nameCtrl.text,
        price: int.tryParse(_priceCtrl.text),
        section: _sectionCtrl.text,
        sequence: int.tryParse(_seqCtrl.text),
      );
      if (isEdit) {
        await widget.apiService.updateFoodtype(widget.foodtype!.id!, d);
      } else {
        await widget.apiService.createFoodtype(d);
      }
      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ');
      }
    } catch (e) {
      setState(() {
        _err = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isD = MediaQuery.of(context).size.width > 768;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isD ? 30 : 10),
      child: Container(
        width: isD ? 500 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 550),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isD ? 20 : 14,
                vertical: isD ? 14 : 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
                      style: TextStyle(
                        fontSize: isD ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isD ? 20 : 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_err != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _err!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      _dd('กลุ่ม', _group, [
                        const DropdownMenuItem(
                          value: 1,
                          child: Text('อาหารหลัก'),
                        ),
                        const DropdownMenuItem(
                          value: 2,
                          child: Text('อาหารว่างและเครื่องดื่ม'),
                        ),
                      ], (v) => setState(() => _group = v!)),
                      const SizedBox(height: 10),
                      _fld('รายการ', _nameCtrl),
                      const SizedBox(height: 10),
                      _fld('ราคา', _priceCtrl, kb: TextInputType.number),
                      const SizedBox(height: 10),
                      _fld('หมวดหมู่', _sectionCtrl),
                      const SizedBox(height: 10),
                      _fld('ลำดับ', _seqCtrl, kb: TextInputType.number),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'ยกเลิก',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isEdit ? 'อัปเดต' : 'บันทึก',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fld(String l, TextEditingController c, {TextInputType? kb}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: c,
        keyboardType: kb,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    ],
  );
  Widget _dd<T>(
    String l,
    T v,
    List<DropdownMenuItem<T>> items,
    Function(T?) oc,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      DropdownButtonFormField<T>(
        initialValue: v,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        items: items,
        onChanged: oc,
        style: const TextStyle(fontSize: 14),
      ),
    ],
  );
}
