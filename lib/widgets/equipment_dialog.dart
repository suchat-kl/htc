import 'package:flutter/material.dart';
import 'package:highway_training/utils/util.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/equipment.dart';
import '../models/roomtype.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class EquipmentDialog extends StatefulWidget {
  final Equipment? equipment;
  final ApiService apiService;
  final List<Map<String, dynamic>> booktitles;
  final List<Roomtype> roomtypes;

  const EquipmentDialog({
    super.key,
    this.equipment,
    required this.apiService,
    required this.booktitles,
    required this.roomtypes,
  });

  @override
  State<EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<EquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sequenceController = TextEditingController();
  final _placeController = TextEditingController();
  final _contractnameController = TextEditingController();
  final _numberpersonController = TextEditingController();

  int? _selectedBookingid;
  int? _selectedRoomtypeid;
  DateTime _startDate = DateTime.now();
  DateTime _stopDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  String? _errorMessage;
  bool get isEdit => widget.equipment != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _selectedBookingid = widget.equipment!.bookingid;
      _selectedRoomtypeid = widget.equipment!.roomtypeid;
      _sequenceController.text = widget.equipment!.sequence.toString();
      _placeController.text = widget.equipment!.place ?? '';
      _contractnameController.text = widget.equipment!.contractname ?? '';
      _numberpersonController.text =
          widget.equipment!.numberperson?.toString() ?? '';
      if (widget.equipment!.startdate != null) {
        _startDate = DateTime.parse(widget.equipment!.startdate!);
      }
      if (widget.equipment!.stopdate != null) {
        _stopDate = DateTime.parse(widget.equipment!.stopdate!);
      }
    }
  }

  @override
  void dispose() {
    _sequenceController.dispose();
    _placeController.dispose();
    _contractnameController.dispose();
    _numberpersonController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = Equipment(
        equipmentID: widget.equipment?.equipmentID,
        bookingid: _selectedBookingid,
        roomtypeid: _selectedRoomtypeid,
        sequence: int.tryParse(_sequenceController.text) ?? 0,
        place: _placeController.text.trim(),
        contractname: _contractnameController.text.trim(),
        numberperson: int.tryParse(_numberpersonController.text),
        startdate: DateFormat('yyyy-MM-dd').format(_startDate),
        stopdate: DateFormat('yyyy-MM-dd').format(_stopDate),
      );
      if (isEdit) {
        await widget.apiService.updateEquipment(
          widget.equipment!.equipmentID!,
          data,
        );
      } else {
        await widget.apiService.createEquipment(data);
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

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _stopDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2037),
      locale: const Locale('th'),
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _stopDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 12), // ✅ Reduced padding
      child: Container(
        width: isDesktop ? 500 : screenWidth * 0.9, // ✅ Reduced width
        constraints: const BoxConstraints(maxWidth: 550),
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
                horizontal: isDesktop ? 20 : 14,
                vertical: isDesktop ? 14 : 10,
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
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form - with scroll
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 20 : 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch, // ✅ Stretch to fill width
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      _field(
                        'ลำดับ',
                        _sequenceController,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _dropdown(
                        'กิจกรรม/โครงการ',
                        _selectedBookingid,
                        widget.booktitles
                            .map(
                              (b) => DropdownMenuItem<int>(
                                value: b['bookID'] as int?,
                                child: Text(
                                  b['booktitle']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 6,
                                ),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedBookingid = v),
                      ),
                      const SizedBox(height: 12),
                      _field('สถานที่', _placeController),
                      const SizedBox(height: 12),
                      _dropdown(
                        'ประเภทห้อง',
                        _selectedRoomtypeid,
                        widget.roomtypes
                            .where((r) => r.roomtypeID != null)
                            .map(
                              (r) => DropdownMenuItem<int>(
                                value: r.roomtypeID,
                                child: Text(r.name),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedRoomtypeid = v),
                      ),
                      const SizedBox(height: 12),
                      _dateField(
                        'วันที่เริ่มต้น',
                        _startDate,
                        () => _pickDate(true),
                      ),
                      const SizedBox(height: 12),
                      _dateField(
                        'วันที่สิ้นสุด',
                        _stopDate,
                        () => _pickDate(false),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        'จำนวนผู้เข้าร่วม',
                        _numberpersonController,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _field('ผู้ติดต่อ', _contractnameController),
                      const SizedBox(height: 20),
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
                              onPressed: _isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
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

  Widget _field(
    String label,
    TextEditingController ctrl, [
    TextInputType? kb,
  ]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      SizedBox(
        // ✅ Fixed width for text fields
        width: double.infinity,
        child: TextFormField(
          controller: ctrl,
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
      ),
    ],
  );

  Widget _dropdown<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    Function(T?) onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true, // ✅ Important for overflow
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
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ],
  );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade50,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                size:  18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                // DateFormat('dd/MM/yyyy').format(date),
                Util.formatThaiDate(date),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
