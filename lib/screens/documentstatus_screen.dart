// lib/screens/documentstatus_screen.dart
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:highway_training/utils/dialog.dart';
import '../config/theme.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';

// import '../utils/dialog.dart';

class DocumentStatusScreen extends StatefulWidget {
  final ApiService apiService;
  const DocumentStatusScreen({super.key, required this.apiService});

  @override
  State<DocumentStatusScreen> createState() => _DocumentStatusScreenState();
}

class _DocumentStatusScreenState extends State<DocumentStatusScreen> {
  // Pagination
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalItems = 0;
  int _totalPages = 0;

  // Data
  List<DocumentStatus> _documentStatus = [];
  bool _isLoading = false;
  String? _error;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  // Dialog
  DocumentStatus? _editingItem;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.apiService.getDocumentStatus(
        page: _currentPage,
        size: _pageSize,
        keyword: _searchKeyword.isEmpty ? null : _searchKeyword,
      );

      if (mounted) {
        setState(() {
          _documentStatus = (response['documentstatus'] as List)
              .map((j) => DocumentStatus.fromJson(j))
              .toList();
          _totalItems = response['totalItems'] ?? 0;
          _totalPages = response['totalPages'] ?? 0;
          // สร้างแถวแก้ไขใหม่ทุกครั้งที่โหลด การแก้ไขค้างจะถูกทิ้งไปพร้อมกัน
          _rebuildRows();
          _deletedIds.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        context.showErrorSnackBar(_error!);
      }
    }
  }

  Future<void> _saveDocumentStatus() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final documentStatus = DocumentStatus(
        statusId: _editingItem?.statusId,
        statusName: _nameController.text.trim(),
      );

      if (_editingItem == null) {
        // Create
        await widget.apiService.createDocumentStatus(documentStatus);
        if (mounted) {
          context.showSuccessSnackBar('เพิ่มสถานะการจองสำเร็จ');
        }
      } else {
        // Update
        await widget.apiService.updateDocumentStatus(
          _editingItem!.statusId!,
          documentStatus,
        );
        if (mounted) {
          context.showSuccessSnackBar('อัปเดตสถานะการจองสำเร็จ');
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close dialog
        await _loadData(); // Reload data
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteDocumentStatus(DocumentStatus item) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      'ต้องการลบสถานะ "${item.statusName}" นี้?',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
    );

    if (confirmed == true) {
      try {
        await widget.apiService.deleteDocumentStatus(item.statusId!);
        if (mounted) {
          context.showSuccessSnackBar('ลบสถานะการจองสำเร็จ');
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  void _showAddEditDialog({DocumentStatus? item}) {
    _editingItem = item;
    _nameController.text = item?.statusName ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                item == null ? Icons.add_circle : Icons.edit,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                item == null ? 'เพิ่มสถานะการจอง' : 'แก้ไขสถานะการจอง',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'รหัส: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('${item.statusId}'),
                      ],
                    ),
                  ),
                if (item != null) const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อสถานะ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.label),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณากรอกชื่อสถานะ';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: _saveDocumentStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(item == null ? 'บันทึก' : 'อัปเดต'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // แก้ไขในตาราง — แก้หลายแถวแล้วกดบันทึกทีเดียว
  // ---------------------------------------------------------------------------

  /// สร้างแถวแก้ไขจากข้อมูลที่โหลดมา ทิ้งของเดิมเพื่อไม่ให้ controller ค้าง
  void _rebuildRows() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(_documentStatus.map(_EditRow.from));
  }

  /// มีการแก้ไขที่ยังไม่ได้บันทึกหรือไม่
  bool get _dirty =>
      _rows.any((r) => r.isNew || r.changed) || _deletedIds.isNotEmpty;

  Widget _headerCheckbox() {
    final selected = _rows.where((r) => r.selected).length;
    final value = _rows.isEmpty || selected == 0
        ? false
        : (selected == _rows.length ? true : null);
    return Checkbox(
      tristate: true,
      value: value,
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.transparent,
      ),
      checkColor: AppTheme.primaryColor,
      side: const BorderSide(color: Colors.white, width: 2),
      onChanged: _rows.isEmpty ? null : (_) => _selectAll(),
    );
  }

  void _selectAll() {
    final all = _rows.isNotEmpty && _rows.every((r) => r.selected);
    setState(() {
      for (final r in _rows) {
        r.selected = !all;
      }
    });
  }

  /// เพิ่มแถวว่างท้ายตาราง รหัสเป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่ให้กรอก
  void _addRow() {
    setState(() => _rows.add(_EditRow.empty()));
  }

  /// ลบออกจากหน้าจอ แถวที่มีอยู่แล้วจะถูกลบจริงตอนกดบันทึก
  void _deleteSelectedRows() {
    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      context.showInfoSnackBar('ยังไม่ได้เลือกรายการที่จะลบ');
      return;
    }
    setState(() {
      for (final r in selected) {
        if (!r.isNew) _deletedIds.add(r.originalId!);
        r.dispose();
        _rows.remove(r);
      }
    });
    context.showInfoSnackBar(
      'ลบ ${selected.length} รายการออกจากหน้าจอแล้ว กดบันทึกเพื่อยืนยัน',
    );
  }

  /// ข้อความแจ้งเตือนเมื่อยังบันทึกไม่ได้ — null แปลว่าผ่าน
  ///
  /// รหัสเป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่มีการตรวจรหัสซ้ำ
  String? _validateRows() {
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      if (r.nameCtrl.text.trim().isEmpty) {
        return 'แถวที่ $no ยังไม่ได้กรอกชื่อสถานะ';
      }
    }
    return null;
  }

  /// บันทึกทุกแถวที่แก้ไขในครั้งเดียว
  ///
  /// ลบแถวที่เอาออก สร้างแถวใหม่ และอัปเดตแถวที่แก้ชื่อ แล้วโหลดข้อมูลใหม่
  Future<void> _saveRows() async {
    if (_isSaving) return;
    final problem = _validateRows();
    if (problem != null) {
      context.showErrorSnackBar(problem);
      return;
    }
    if (!_dirty) {
      context.showInfoSnackBar('ไม่มีการแก้ไขที่ต้องบันทึก');
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final id in _deletedIds) {
        await widget.apiService.deleteDocumentStatus(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        final item = DocumentStatus(
          statusId: r.originalId,
          statusName: r.nameCtrl.text.trim(),
        );
        if (r.isNew) {
          await widget.apiService.createDocumentStatus(item);
        } else if (r.changed) {
          await widget.apiService.updateDocumentStatus(r.originalId!, item);
        }
      }

      if (!mounted) return;
      context.showSuccessSnackBar('บันทึกเรียบร้อยแล้ว');
      setState(() => _isSaving = false);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar(
        'บันทึกไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}',
      );
      // อาจบันทึกสำเร็จไปแล้วบางส่วน จึงโหลดใหม่ให้ตรงของจริง
      await _loadData();
    }
  }

  /// ปิดหน้าจอ ถามก่อนถ้ายังมีการแก้ไขค้าง
  Future<void> _closeScreen() async {
    if (!await _confirmDiscard()) return;
    if (mounted) Navigator.pop(context);
  }

  /// ถามยืนยันเมื่อยังมีการแก้ไขค้างอยู่ — true = ไปต่อได้
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await AppDialog.showConfirm(
      context,
      'ยังมีการแก้ไขที่ยังไม่ได้บันทึก ต้องการทิ้งการแก้ไขหรือไม่?',
      confirmText: 'ทิ้งการแก้ไข',
    );
    return ok == true;
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// รหัสเป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแสดงอย่างเดียว แก้ไม่ได้ทุกแถว
  Widget _editableRow(_EditRow row, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 100, //16
          vertical: 8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: row.selected,
                onChanged: (v) => setState(() => row.selected = v ?? false),
              ),
            ),
            SizedBox(
              width: isDesktop ? 80 : 60,
              child: Text(
                row.isNew ? 'ใหม่' : '${row.originalId}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: row.isNew ? Colors.orange.shade800 : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.nameCtrl,
                style: const TextStyle(fontSize: 15),
                decoration: _rowInput(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: isDesktop ? 160 : 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: row.isNew
                        ? null
                        : () =>
                              _showAddEditDialog(item: row.toDocumentStatus()),
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    tooltip: 'แก้ไขในหน้าต่าง',
                  ),
                  IconButton(
                    onPressed: row.isNew
                        ? null
                        : () => _deleteDocumentStatus(row.toDocumentStatus()),
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    tooltip: 'ลบทันที',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'มีการแก้ไขที่ยังไม่ได้บันทึก',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
              ),
            ),
          _rowButton('ลบที่เลือก', _deleteSelectedRows),
          const SizedBox(width: 12),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          const SizedBox(width: 4),
          _rowButton('เพิ่ม', _addRow),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(
                0xFF43A047,
              ).withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final isDesktop = MediaQuery.of(context).size.width > 1024;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    // ✅ กำหนดความกว้างสูงสุดของเนื้อหา
    final maxContentWidth = isDesktop ? 1200.0 : double.infinity;

    return PopScope(
      // ปิดด้วยปุ่มย้อนกลับของเบราว์เซอร์ก็ต้องถามก่อนเหมือนกัน
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            tooltip: 'ปิด',
            onPressed: _closeScreen,
          ),
          title: const Text(
            'สถานะการจอง',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('เพิ่ม', style: TextStyle(fontSize: 14)),
                // style: ElevatedButton.styleFrom(
                //   backgroundColor: Colors.white,
                //   foregroundColor: AppTheme.primaryColor,
                // ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 14,
                    vertical: isDesktop ? 14 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Container(
            // ✅ จำกัดความกว้างสูงสุดและจัดกึ่งกลาง
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ค้นหาด้วย รหัส หรือ ชื่อ',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchKeyword = '';
                                      _currentPage = 0;
                                      _loadData();
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (value) {
                            setState(() {
                              _searchKeyword = value.trim();
                              _currentPage = 0;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _searchKeyword = _searchController.text.trim();
                            _currentPage = 0;
                          });
                          _loadData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('ค้นหา'),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('ลองอีกครั้ง'),
                              ),
                            ],
                          ),
                        )
                      : _documentStatus.isEmpty && _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchKeyword.isEmpty
                                    ? 'ไม่มีข้อมูลสถานะการจอง'
                                    : 'ไม่พบข้อมูลที่ค้นหา',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addRow,
                                icon: const Icon(Icons.add),
                                label: const Text('เพิ่มแถวในตาราง'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 100, //16
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 40, child: _headerCheckbox()),
                                  SizedBox(
                                    width: isDesktop ? 80 : 60,
                                    child: const Text(
                                      'รหัส',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: const Text(
                                      'ชื่อสถานะ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isDesktop ? 160 : 120,
                                    child: const Text(
                                      'จัดการ',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table Body
                            Expanded(
                              child: ListView.builder(
                                itemCount: _rows.length,
                                itemBuilder: (context, index) {
                                  return _editableRow(_rows[index], isDesktop);
                                },
                              ),
                            ),

                            _rowActionBar(),

                            // Pagination
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: AppPagination(
                                currentPage: _currentPage,
                                totalPages: _totalPages,
                                pageSize: _pageSize,
                                summary: 'ทั้งหมด $_totalItems รายการ',
                                onPageChanged: (page) async {
                                  if (!await _confirmDiscard()) return;
                                  setState(() => _currentPage = page);
                                  _loadData();
                                },
                                onPageSizeChanged: (size) async {
                                  if (!await _confirmDiscard()) return;
                                  setState(() {
                                    _pageSize = size;
                                    _currentPage = 0;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// หนึ่งแถวที่แก้ไขได้ในตารางสถานะการจอง
class _EditRow {
  /// รหัสเดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalId;
  final String originalName;

  final TextEditingController nameCtrl;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({this.originalId, this.originalName = '', required this.nameCtrl});

  factory _EditRow.from(DocumentStatus s) => _EditRow(
    originalId: s.statusId,
    originalName: s.statusName ?? '',
    nameCtrl: TextEditingController(text: s.statusName ?? ''),
  );

  factory _EditRow.empty() => _EditRow(nameCtrl: TextEditingController());

  bool get isNew => originalId == null;

  /// แถวเดิมที่ถูกแก้ชื่อ (รหัสเป็นคีย์ที่ฐานข้อมูลสร้างเอง แก้ไม่ได้)
  bool get changed => !isNew && nameCtrl.text.trim() != originalName.trim();

  DocumentStatus toDocumentStatus() =>
      DocumentStatus(statusId: originalId, statusName: nameCtrl.text.trim());

  void dispose() {
    nameCtrl.dispose();
  }
}
