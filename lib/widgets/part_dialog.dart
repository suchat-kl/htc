import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/part.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class PartDialog extends StatefulWidget {
  final Part? part;
  final ApiService apiService;

  const PartDialog({super.key, this.part, required this.apiService});

  @override
  State<PartDialog> createState() => _PartDialogState();
}

class _PartDialogState extends State<PartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sequenceController = TextEditingController();
  final _stockLevelController = TextEditingController();
  final _unitController = TextEditingController();
  String _selectedType = 'S';
  String _selectedStatus = '1';
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.part != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.part!.name ?? '';
      _sequenceController.text = widget.part!.sequence.toString();
      _stockLevelController.text = widget.part!.stockLevel.toString();
      _unitController.text = widget.part!.unit ?? '';
      _selectedType = widget.part!.type;
      _selectedStatus = widget.part!.status;
    }
    else {
      _stockLevelController.text ="0";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sequenceController.dispose();
    _stockLevelController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final part = Part(
        partID: widget.part?.partID,
        name: _nameController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        stockLevel: double.tryParse(_stockLevelController.text) ?? 0.0,
        unit: _unitController.text.trim(),
      );
      if (isEdit) {
        await widget.apiService.updatePart(widget.part!.partID!, part);
      } else {
        await widget.apiService.createPart(part);
      }
      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 550 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: isDesktop ? 16 : 12,
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'แก้ไขวัสดุซ่อมบำรุง' : 'เพิ่มวัสดุซ่อมบำรุง',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      _buildField(
                        'ลำดับ',
                        _sequenceController,
                        isDesktop,
                        readOnly: false,
                        kb: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      _buildField('รายการ', _nameController, isDesktop),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        'ประเภท',
                        _selectedType,
                        [
                          const DropdownMenuItem(
                            value: 'S',
                            child: Text('Stock'),
                          ),
                          const DropdownMenuItem(
                            value: 'N',
                            child: Text('Empty'),
                          ),
                        ],
                        (v) => setState(() => _selectedType = v!),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        'จำนวน',
                        _stockLevelController,
                        isDesktop,
                        readOnly: true,
                        kb: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      _buildField('หน่วย', _unitController, isDesktop),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        'สถานะ',
                        _selectedStatus,
                        [
                          const DropdownMenuItem(
                            value: '1',
                            child: Text('ใช้งาน'),
                          ),
                          const DropdownMenuItem(
                            value: '2',
                            child: Text('ไม่ใช้งาน'),
                          ),
                        ],
                        (v) => setState(() => _selectedStatus = v!),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('ยกเลิก'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(isEdit ? 'อัปเดต' : 'บันทึก'),
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

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    bool isDesktop, {
    bool readOnly = false,
    TextInputType? kb,
    String? Function(String?)? valid,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          keyboardType: kb,
          validator:
              valid, // ✅ This is correct - it passes validator to TextFormField
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: TextStyle(fontSize: isDesktop ? 15 : 14),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    Function(T?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
