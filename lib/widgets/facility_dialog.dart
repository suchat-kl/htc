import 'package:flutter/material.dart';
import 'package:highway_training/models/facility.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class FacilityDialog extends StatefulWidget {
  final Facility? facility;
  
  final ApiService apiService;

  const FacilityDialog({super.key, this.facility, required this.apiService});

  @override
  State<FacilityDialog> createState() => _FacilityDialogState();
}

class _FacilityDialogState extends State<FacilityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sequenceController = TextEditingController();
  // final _stockLevelController = TextEditingController();

  // String _selectedType = 'B';
  String _selectedStatus = '1';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEdit => widget.facility != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.facility!.name;
      _descriptionController.text = widget.facility!.description ?? '';
      _sequenceController.text = widget.facility!.sequence.toString();
      // _stockLevelController.text = widget.commodity!.stockLevel.toString();
      // _selectedType = widget.commodity!.type;
      _selectedStatus = widget.facility!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sequenceController.dispose();
    // _stockLevelController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facility = Facility(
        facilityID: widget.facility?.facilityID,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        // type: _selectedType,
        status: _selectedStatus,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        // stockLevel: double.tryParse(_stockLevelController.text) ?? 0.0,
      );

      if (isEdit) {
        // AppLogger.d("edit");
        // AppLogger.d(widget.facility!.facilityID.toString());
        // AppLogger.d(facility.description);
        // ✅ Check if facilityID is not null before accessing
        final facilityId = widget.facility?.facilityID;
        if (AppLogger.on) AppLogger.d("edit");
        if (AppLogger.on) AppLogger.d("facilityID: ${facilityId ?? 'null'}");

        // if (facilityId == null) {
        //   throw Exception('Facility ID is null - cannot update');
        // }

        await widget.apiService.updateFacility(
          widget.facility!.facilityID!,
          facility,
        );
      } else {
        await widget.apiService.createFacility(facility);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccessSnackBar(
          isEdit ? 'อัปเดตข้อมูลสำเร็จ' : 'บันทึกข้อมูลสำเร็จ',
        );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 600 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxWidth: 650),
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
                    width: isDesktop ? 45 : 38,
                    height: isDesktop ? 45 : 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit : Icons.add,
                      color: AppTheme.primaryColor,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isEdit
                              ? 'แก้ไขสิ่งอำนวยความสะดวก'
                              : 'เพิ่มสิ่งอำนวยความสะดวก',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Master Data',
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _errorMessage = null),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildTextField(
                        label: 'ลำดับ',
                        hint: 'กรอกลำดับ',
                        controller: _sequenceController,
                        isDesktop: isDesktop,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // Type dropdown
                      // Text(
                      //   'ประเภท',
                      //   style: TextStyle(
                      //     fontSize: isDesktop ? 14 : 13,
                      //     fontWeight: FontWeight.w600,
                      //   ),
                      // ),
                      // const SizedBox(height: 8),
                      // DropdownButtonFormField<String>(
                      //   initialValue: _selectedType,
                      //   decoration: InputDecoration(
                      //     border: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //     ),
                      //     filled: true,
                      //     fillColor: Colors.grey.shade50,
                      //   ),
                      //   items: const [
                      //     DropdownMenuItem(
                      //       value: 'B',
                      //       child: Text('เครื่องนอน'),
                      //     ),
                      //     DropdownMenuItem(value: 'C', child: Text('ของใช้')),
                      //   ],
                      //   onChanged: (v) => setState(() => _selectedType = v!),
                      // ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'รายการ',
                        hint: 'กรอกรายการ',
                        controller: _nameController,
                        isDesktop: isDesktop,
                        validator: (v) =>
                            v?.isEmpty == true ? 'กรุณากรอกรายการ' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'คำอธิบาย',
                        hint: 'กรอกคำอธิบาย',
                        controller: _descriptionController,
                        isDesktop: isDesktop,
                        maxLines: 3,
                      ),
                      // const SizedBox(height: 16),
                      // _buildTextField(
                      //   label: 'Stock Level',
                      //   hint: 'กรอกจำนวน',
                      //   controller: _stockLevelController,
                      //   isDesktop: isDesktop,
                      //   keyboardType: TextInputType.number,
                      // ),
                      const SizedBox(height: 16),
                      // Status dropdown
                      Text(
                        'สถานะ',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('ใช้งาน')),
                          DropdownMenuItem(
                            value: '2',
                            child: Text('ไม่ใช้งาน'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 14 : 12,
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
                                padding: EdgeInsets.symmetric(
                                  vertical: isDesktop ? 14 : 12,
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

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDesktop,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: TextStyle(fontSize: isDesktop ? 16 : 14),
          validator: validator,
        ),
      ],
    );
  }
}
