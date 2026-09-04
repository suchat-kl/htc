import 'package:flutter/material.dart';
import 'package:highway_training/models/employee.dart';
import 'package:highway_training/utils/util.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/commodity.dart';
import '../models/commodity_in.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../providers/auth_provider.dart';

class CommodityInDialog extends StatefulWidget {
  final AuthProvider authProvider;
  final CommodityIn? transaction;
  final ApiService apiService;
  final List<Commodity> commodities;
  final List<Employee> employees;

  const CommodityInDialog({
    super.key,
    this.transaction,
    required this.apiService,
    required this.commodities,
    required this.employees,
    required this.authProvider,
  });

  @override
  State<CommodityInDialog> createState() => _CommodityInDialogState();
}

class _CommodityInDialogState extends State<CommodityInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _poController = TextEditingController();

  int? _selectedCommodityID;
  int? _selectedemployeeID; //= 28;
  String _selectedType = 'D';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEdit => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _selectedCommodityID = widget.transaction!.commodityID;
      _selectedemployeeID =
          widget.transaction!.employeeID; // ✅ Load employeeID for edit
      _selectedType = widget.transaction!.type;
      _qtyController.text = widget.transaction!.qty.toString();
      _priceController.text = widget.transaction!.price.toString();
      _poController.text = widget.transaction!.po ?? '';
      if (widget.transaction!.date != null) {
        try {
          _selectedDate = DateFormat(
            'yyyy-MM-dd',
          ).parse(widget.transaction!.date!);
        } catch (_) {}
      }
    } else {
      // ✅ Set default values for new transaction
      if (widget.commodities.isNotEmpty) {
        _selectedCommodityID = widget.commodities.first.commodityId;
      }
      // ✅ Parse empID from authProvider (String to int)
      // final empIdStr = widget.authProvider.empID;
      _selectedemployeeID = widget
          .authProvider
          .empID; //     empIdStr != null ? int.tryParse(empIdStr) : null;

      // Set default employee from list if authProvider doesn't have empID
      if (_selectedemployeeID == null && widget.employees.isNotEmpty) {
        _selectedemployeeID = widget.employees.first.empID;
      }
    } //add
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _poController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommodityID == null) {
      setState(() => _errorMessage = 'กรุณาเลือกของใช้');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = CommodityIn(
        commodityInTransactionID: widget.transaction?.commodityInTransactionID,
        commodityID: _selectedCommodityID,
        type: _selectedType,
        qty: double.tryParse(_qtyController.text) ?? 0.0,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        price: double.tryParse(_priceController.text) ?? 0.0,
        po: _poController.text.trim(),
        employeeID: _selectedemployeeID, // ✅ Make sure this is included!
      );

      // ✅ Debug print
      debugPrint('Saving data: ${data.toJson()}');

      if (isEdit) {
        await widget.apiService.updateCommodityIn(
          widget.transaction!.commodityInTransactionID!,
          data,
        );
      } else {
        await widget.apiService.createCommodityIn(data);
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
      if (mounted) context.showErrorSnackBar(_errorMessage!);
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
                      isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
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
                      _buildDropdown(
                        'ของใช้',
                        _selectedCommodityID,
                        widget.commodities
                            .where((c) => c.commodityId != null)
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.commodityId,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedCommodityID = v),
                      ),
                      const SizedBox(height: 14),
                      _buildDropdown(
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
                      const SizedBox(height: 14),
                      _buildField(
                        'จำนวน',
                        _qtyController,
                        isDesktop,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      _buildDatePicker(isDesktop),
                      const SizedBox(height: 14),
                      _buildField(
                        'ราคา',
                        _priceController,
                        isDesktop,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      _buildField('ใบสั่งซื้อ (PO)', _poController, isDesktop),
                      const SizedBox(height: 14),
                      _buildDropdown(
                        'ผู้เบิก',
                        _selectedemployeeID,
                        widget.employees
                            .where((c) => c.empID != null)
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.empID,
                                child: Text("${c.name!} ${c.lastname!}"),
                              ),
                            )
                            .toList(),
                        (v) => setState(() => _selectedemployeeID = v),
                      ),
                      const SizedBox(height: 24),

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
    bool isDesktop, [
    TextInputType? kb,
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

  Widget _buildDatePicker(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วันที่',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await Util.dateFieldPicker(
              context, // ✅ Pass context

              _selectedDate, // Christian year DateTime
            );
            if (picked != _selectedDate) setState(() => _selectedDate = picked);
            /*
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2037),
              locale: const Locale('th'),
              helpText: 'เลือกวันที่',
              cancelText: 'ยกเลิก',
              confirmText: 'ตกลง',
            );
            if (picked != null) setState(() => _selectedDate = picked);
*/
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: isDesktop ? 22 : 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  style: TextStyle(fontSize: isDesktop ? 15 : 14),
                  Util.formatThaiDate(_selectedDate),
                ),
                // Text(
                //   DateFormat('dd/MM/yyyy').format(_selectedDate),
                //   style: TextStyle(fontSize: isDesktop ? 15 : 14),
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
