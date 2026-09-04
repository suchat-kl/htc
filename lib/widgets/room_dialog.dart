import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/room.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class RoomDialog extends StatefulWidget {
  final Room? room;
  final ApiService apiService;
  final List<Roomtype> roomtypes;

  const RoomDialog({
    super.key,
    this.room,
    required this.apiService,
    required this.roomtypes,
  });

  @override
  State<RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<RoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomNOController = TextEditingController();
  final _sequenceController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  int? _selectedRoomTypeID;
  String _selectedStatus = '1';
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _roomNOController.text = widget.room!.roomNO;
      _sequenceController.text = widget.room!.sequence.toString();
      _buildingController.text = widget.room!.building?.toString() ?? '';
      _floorController.text = widget.room!.floor?.toString() ?? '';
      _selectedRoomTypeID = widget.room!.roomTypeID;
      _selectedStatus = widget.room!.status;
    } else if (widget.roomtypes.isNotEmpty) {
      _selectedRoomTypeID = widget.roomtypes.first.roomtypeID;
    }
  }

  @override
  void dispose() {
    _roomNOController.dispose();
    _sequenceController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoomTypeID == null) {
      setState(() => _errorMessage = 'กรุณาเลือกประเภทห้อง');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = Room(
        roomID: widget.room?.roomID,
        roomNO: _roomNOController.text.trim(),
        roomTypeID: _selectedRoomTypeID,
        building: int.tryParse(_buildingController.text),
        floor: int.tryParse(_floorController.text),
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        status: _selectedStatus,
      );

      if (isEdit) {
        await widget.apiService.updateRoom(widget.room!.roomID!, room);
      } else {
        await widget.apiService.createRoom(room);
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
                      isEdit ? 'แก้ไขห้อง' : 'เพิ่มห้อง',
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
                      // Error message
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

                      // Sequence
                      _buildField(
                        'ลำดับ',
                        _sequenceController,
                        isDesktop,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // Room Number
                      _buildField(
                        'หมายเลขห้อง',
                        _roomNOController,
                        isDesktop,
                        
                      ),
                      const SizedBox(height: 14),

                      // Room Type Dropdown
                      Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('ประเภท'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedRoomTypeID,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: widget.roomtypes
                                .where((t) => t.roomtypeID != null)
                                .map(
                                  (t) => DropdownMenuItem<int>(
                                    value: t.roomtypeID,
                                    child: Text(t.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedRoomTypeID = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Building
                      _buildField(
                        'ตึก',
                        _buildingController,
                        isDesktop,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // Floor
                      _buildField(
                        'ชั้น',
                        _floorController,
                        isDesktop,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 14),

                      // Status Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          _buildLabel('สถานะ'),
                          const SizedBox(height: 6),
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
                        ],
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

  // Helper: Build label
  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  // Helper: Build text field
  Widget _buildField(
    String label,
    TextEditingController ctrl,
    bool isDesktop, [
    TextInputType? kb,
    String? Function(String?)? validator,
  ]) {
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
          keyboardType: kb,
          validator: validator,
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
}
