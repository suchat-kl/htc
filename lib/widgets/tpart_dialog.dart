import 'package:flutter/material.dart';
import 'package:highway_training/utils/util.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/tpart.dart';
import '../models/part.dart';
import '../models/employee.dart';
import '../models/maintenance.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class TpartDialog extends StatefulWidget {
  final Tpart? transaction;
  final ApiService apiService;
  final List<Part> parts;
  final List<Employee> employees;
  final List<Maintenance> maintenances;
  final AuthProvider authProvider;
  final int? preselectedMaintenanceId;
  const TpartDialog({
    super.key,
    this.transaction,
    required this.apiService,
    required this.parts,
    required this.employees,
    required this.maintenances,
    required this.authProvider,
    this.preselectedMaintenanceId,
  });

  @override
  State<TpartDialog> createState() => _TpartDialogState();
}

class _TpartDialogState extends State<TpartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(),
      _priceCtrl = TextEditingController(),
      _poCtrl = TextEditingController(),
      _remarkCtrl = TextEditingController(),
      _placeCtrl = TextEditingController();
  int? _selectedPartid, _selectedEmpid, _selectedMtid;
  String _selectedType = 'D';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  bool get isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _selectedPartid = widget.transaction!.partid;
      _selectedType = widget.transaction!.type ?? 'D';
      _qtyCtrl.text = widget.transaction!.qty?.toString() ?? '';
      _priceCtrl.text = widget.transaction!.price?.toString() ?? '';
      _poCtrl.text = widget.transaction!.po ?? '';
      _remarkCtrl.text = widget.transaction!.remark ?? '';
      _placeCtrl.text = widget.transaction!.place ?? '';
      _selectedEmpid = widget.transaction!.employeeid;
      _selectedMtid = widget.transaction!.maintenanceid;
      if (widget.transaction!.date != null) {
        _selectedDate =
            DateTime.tryParse(widget.transaction!.date!) ?? DateTime.now();
      }
    } else {
      _qtyCtrl.text = "0";
      if (widget.parts.isNotEmpty) _selectedPartid = widget.parts.first.partID;
      if (widget.employees.isNotEmpty) {
        // Set to logged-in user's employee ID
        final empId = widget.authProvider.empID;
        _selectedEmpid = empId ?? widget.employees.first.empID;
      }
    }
    // In initState, set default maintenance
    // if (!isEdit && widget.preselectedMaintenanceId != null) {
    //   _selectedMtid = widget.preselectedMaintenanceId;
    // }
    // ✅ Set preselected maintenance ID
    if (widget.preselectedMaintenanceId != null) {
      _selectedMtid = widget.preselectedMaintenanceId;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _poCtrl.dispose();
    _remarkCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartid == null) {
      setState(() => _error = 'กรุณาเลือกรายการ');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final d = Tpart(
        tpartID: widget.transaction?.tpartID,
        partid: _selectedPartid,
        type: _selectedType,
        qty: double.tryParse(_qtyCtrl.text),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        place: _placeCtrl.text,
        price: double.tryParse(_priceCtrl.text),
        employeeid: _selectedEmpid,
        po: _poCtrl.text,
        maintenanceid: _selectedMtid,
        remark: _remarkCtrl.text,
      );
      if (isEdit) {
        await widget.apiService.updateTpart(widget.transaction!.tpartID!, d);
      } else {
        await widget.apiService.createTpart(d);
      }
      if (mounted) {
        Navigator.pop(context, true);
        context.showSuccessSnackBar(isEdit ? 'อัปเดตสำเร็จ' : 'บันทึกสำเร็จ');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      if (mounted) context.showErrorSnackBar(_error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isD = MediaQuery.of(context).size.width > 768;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isD ? 30 : 10),
      child: Container(
        width: isD ? 550 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 600),
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
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      _dd(
                        'รายการ',
                        _selectedPartid,
                        widget.parts
                            .where((p) => p.partID != null)
                            .map(
                              (p) => DropdownMenuItem<int>(
                                value: p.partID,
                                child: Text(p.name ?? '', maxLines: 6),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedPartid = v),
                      ),
                      const SizedBox(height: 10),
                      _dd(
                        'รับ/จ่าย',
                        _selectedType,
                        [
                          const DropdownMenuItem(
                            value: 'D',
                            child: Text('รับ'),
                          ),
                          const DropdownMenuItem(
                            value: 'C',
                            child: Text('จ่าย'),
                          ),
                        ],
                        (v) => setState(() => _selectedType = v!),
                      ),
                      const SizedBox(height: 10),
                      _fld('จำนวน', _qtyCtrl, inputType: TextInputType.number),
                      const SizedBox(height: 10),
                      _dateField('วันที่', _selectedDate, () async {
                        DateTime p = await Util.dateFieldPicker(
                          context, // ✅ Pass context

                          _selectedDate, // Christian year DateTime
                        );
                        if (p != _selectedDate) {
                          setState(() => _selectedDate = p);
                        }
                      }),

                      /*
                       () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2037),
                          locale: const Locale('th'),
                        );
                        if (p != null) setState(() => _selectedDate = p);
                      }),
*/
                      const SizedBox(height: 10),
                      _fld('พื้นที่ใช้งาน', _placeCtrl),
                      const SizedBox(height: 10),
                      _dd(
                        'ผู้เบิก',
                        _selectedEmpid,
                        widget.employees
                            .where((e) => e.empID != null)
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e.empID,
                                child: Text(
                                  '${e.name ?? ''} ${e.lastname ?? ''}',
                                  maxLines: 6,
                                ),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedEmpid = v),
                      ),
                      const SizedBox(height: 10),
                      _fld('ใบสั่งซื้อ (PO)', _poCtrl),
                      const SizedBox(height: 10),
                      _fld('ราคา', _priceCtrl, inputType: TextInputType.number),
                      const SizedBox(height: 10),
                      _dd(
                        'ใบแจ้งซ่อม',
                        _selectedMtid,
                        widget.maintenances
                            .where((m) => m.maintenanceID != null)
                            .map(
                              (m) => DropdownMenuItem<int>(
                                value: m.maintenanceID,
                                child: Text(
                                  '${m.maintenanceID} ${m.place ?? ''} ${m.position ?? ''}',
                                  maxLines: 6,
                                ),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedMtid = v),
                      ),
                      const SizedBox(height: 10),
                      _fld('หมายเหตุ', _remarkCtrl, maxLines: 2),
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
                              onPressed: _isLoading ? null : _save,
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

  Widget _fld(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? inputType,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        maxLines: maxLines,
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
    String label,
    T? value,
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
      DropdownButtonFormField<T>(
        initialValue: value,
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
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
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
                size: 18,
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
