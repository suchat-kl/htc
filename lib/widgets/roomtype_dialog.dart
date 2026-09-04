import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class RoomtypeDialog extends StatefulWidget {
  final Roomtype? roomtype;
  final ApiService apiService;

  const RoomtypeDialog({super.key, this.roomtype, required this.apiService});

  @override
  State<RoomtypeDialog> createState() => _RoomtypeDialogState();
}

class _RoomtypeDialogState extends State<RoomtypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sequenceController = TextEditingController();
  final _priceController = TextEditingController();
  final _remarkController = TextEditingController();

  String _selectedType = 'C';
  String _selectedStatus = '1';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEdit => widget.roomtype != null;

  // ✅ Hardcoded type list
  static const List<Map<String, String>> _types = [
    {'code': 'R', 'name': 'Room'},
    {'code': 'C', 'name': 'Conference'},
  ];

  // ✅ Hardcoded status list
  static const List<Map<String, String>> _statuses = [
    {'code': '1', 'name': 'ใช้งาน'},
    {'code': '2', 'name': 'ไม่ใช้งาน'},
  ];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.roomtype!.name;
      _descriptionController.text = widget.roomtype!.description ?? '';
      _sequenceController.text = widget.roomtype!.sequence.toString();
      _priceController.text = widget.roomtype!.price?.toString() ?? '';
      _remarkController.text = widget.roomtype!.remark ?? '';
      _selectedType = widget.roomtype!.type ?? 'C';
      _selectedStatus = widget.roomtype!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sequenceController.dispose();
    _priceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final roomtype = Roomtype(
        roomtypeID: widget.roomtype?.roomtypeID,
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim(),
        status: _selectedStatus,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        price: double.tryParse(_priceController.text),
        remark: _remarkController.text.trim(),
      );

      if (isEdit) {
        if (widget.roomtype?.roomtypeID == null) {
          throw Exception('ไม่พบข้อมูลที่ต้องการแก้ไข');
        }
        await widget.apiService.updateRoomtype(
          widget.roomtype!.roomtypeID!,
          roomtype,
        );
      } else {
        await widget.apiService.createRoomtype(roomtype);
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 600 : screenWidth * 0.95,
        constraints: BoxConstraints(
          maxWidth: 650,
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDesktop),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
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
                      _buildDropdown(
                        label: 'ประเภท',
                        value: _selectedType,
                        items: _types,
                        isDesktop: isDesktop,
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
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
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'ราคาห้อง',
                        hint: 'กรอกราคา',
                        controller: _priceController,
                        isDesktop: isDesktop,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'หมายเหตุ',
                        hint: 'กรอกหมายเหตุ',
                        controller: _remarkController,
                        isDesktop: isDesktop,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown(
                        label: 'สถานะ',
                        value: _selectedStatus,
                        items: _statuses,
                        isDesktop: isDesktop,
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                      const SizedBox(height: 24),
                      _buildButtons(isDesktop),
                      SizedBox(height: isDesktop ? 0 : 20),
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

  Widget _buildHeader(bool isDesktop) {
    return Container(
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  isEdit ? 'แก้ไขประเภทห้อง' : 'เพิ่มประเภทห้อง',
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
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close, color: Colors.red.shade700, size: 18),
          ),
        ],
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required bool isDesktop,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item['code'],
                  child: Text(
                    item['name'] ?? '',
                    style: TextStyle(fontSize: isDesktop ? 14 : 13),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildButtons(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 14 : 12),
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
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 14 : 12),
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
    );
  }
}
