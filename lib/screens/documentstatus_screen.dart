// lib/screens/documentstatus_screen.dart
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:highway_training/utils/dialog.dart';
import '../config/theme.dart';
import '../models/documentstatus.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
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

  @override
  Widget build(BuildContext context) {
    // final isDesktop = MediaQuery.of(context).size.width > 1024;
     final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    // ✅ กำหนดความกว้างสูงสุดของเนื้อหา
    final maxContentWidth = isDesktop ? 1200.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
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
                            Icon(Icons.error, size: 64, color: Colors.red.shade300),
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
                    : _documentStatus.isEmpty
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
                              itemCount: _documentStatus.length,
                              itemBuilder: (context, index) {
                                final item = _documentStatus[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 100, //16
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: isDesktop ? 80 : 60,
                                          child: Text(
                                            '${item.statusId}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.statusName ?? '-',
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                        ),
                                        SizedBox(
                                          width: isDesktop ? 160 : 120,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                onPressed: () =>
                                                    _showAddEditDialog(item: item),
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 20,
                                                  color: Colors.blue,
                                                ),
                                                tooltip: 'แก้ไข',
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _deleteDocumentStatus(item),
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                tooltip: 'ลบ',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Page Size
                                Row(
                                  children: [
                                    const Text('แสดง '),
                                    DropdownButton<int>(
                                      value: _pageSize,
                                      underline: Container(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 5,
                                          child: Text('5'),
                                        ),
                                        DropdownMenuItem(
                                          value: 10,
                                          child: Text('10'),
                                        ),
                                        DropdownMenuItem(
                                          value: 15,
                                          child: Text('15'),
                                        ),
                                        DropdownMenuItem(
                                          value: 20,
                                          child: Text('20'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _pageSize = value;
                                            _currentPage = 0;
                                          });
                                          _loadData();
                                        }
                                      },
                                    ),
                                    const Text(' รายการ'),
                                  ],
                                ),
          
                                // Page Info
                                Text(
                                  '${_currentPage * _pageSize + 1} - '
                                  '${((_currentPage + 1) * _pageSize).clamp(0, _totalItems)} '
                                  'จาก $_totalItems รายการ',
                                  style: const TextStyle(fontSize: 14),
                                ),
          
                                // Page Controls
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: _currentPage > 0
                                          ? () {
                                              setState(() => _currentPage--);
                                              _loadData();
                                            }
                                          : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Text(
                                      '${_currentPage + 1} / $_totalPages',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    IconButton(
                                      onPressed: _currentPage < _totalPages - 1
                                          ? () {
                                              setState(() => _currentPage++);
                                              _loadData();
                                            }
                                          : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
