import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/foodtype.dart';
import '../services/api_service.dart';
import '../widgets/foodtype_dialog.dart';
import '../utils/snackbar_helper.dart';

class FoodtypeScreen extends StatefulWidget {
  final ApiService apiService;
  const FoodtypeScreen({super.key, required this.apiService});

  @override
  State<FoodtypeScreen> createState() => _FoodtypeScreenState();
}

class _FoodtypeScreenState extends State<FoodtypeScreen> {
  List<Foodtype> _list = [];
  bool _isLoading = true;
  int _cp = 0, _tp = 0, _ps = 5;
  String? _fName;
  int? _fGroup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r = await widget.apiService.getFoodtypes(
        page: _cp,
        size: _ps,
        name: _fName,
        foodgroupID: _fGroup,
      );
      if (mounted) {
        final l = r['foodtypes'] as List?;
        setState(() {
          _list = l?.map((j) => Foodtype.fromJson(j)).toList() ?? [];
          _tp = r['totalPages'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้');
      }
    }
  }

  void _dialog({Foodtype? foodtype}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) =>
          FoodtypeDialog( foodtype: foodtype,
            // ✅ ส่งค่าถูกต้อง 
            apiService: widget.apiService),
    ).then((_) => _load());
  }

  Future<void> _del(Foodtype f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'ต้องการลบ "${f.name}"?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && f.id != null) {
      try {
        await widget.apiService.deleteFoodtype(f.id!);
        if (mounted) {
          context.showSuccessSnackBar('ลบสำเร็จ');
          _load();
        }
      } catch (e) {
        if (mounted) context.showErrorSnackBar('ลบไม่สำเร็จ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isD = sw > 1024;
    final isL = sw > 1400;
    final hf = isL ? 22.0 : (isD ? 20.0 : 18.0);
    final bf = isL ? 16.0 : (isD ? 15.0 : 14.0);
    final ic = isL ? 22.0 : (isD ? 20.0 : 18.0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'กลุ่มรายการอาหาร',
          style: TextStyle(fontSize: hf, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _dialog(),
              icon: Icon(Icons.add, size: ic),
              label: Text('เพิ่มรายการ', style: TextStyle(fontSize: bf)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isD ? 20 : 14,
                  vertical: isD ? 14 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isD ? 14 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: isL ? 200 : (isD ? 170 : double.infinity),
                    child: TextField(
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'ค้นหารายการ...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (v) {
                        _fName = v;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isL ? 170 : (isD ? 140 : 120),
                    child: DropdownButtonFormField<int?>(
                      initialValue: _fGroup,
                      isExpanded: true,
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'กลุ่ม',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'ทั้งหมด',
                            style: TextStyle(fontSize: bf - 1),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 1,
                          child: Text('อาหารหลัก'),
                        ),
                        const DropdownMenuItem(
                          value: 2,
                          child: Text('อาหารว่างและเครื่องดื่ม'),
                        ),
                      ],
                      onChanged: (v) {
                        _fGroup = v;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                  SizedBox(
                    width: isL ? 90 : (isD ? 80 : 70),
                    child: DropdownButtonFormField<int>(
                      initialValue: _ps,
                      isExpanded: true,
                      style: TextStyle(fontSize: bf - 1),
                      decoration: InputDecoration(
                        hintText: 'แสดง',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      items: [5, 10, 15, 20]
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s,
                              child: Text(
                                '$s',
                                style: TextStyle(fontSize: bf - 1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        _ps = v!;
                        _cp = 0;
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                ? Center(
                    child: Text(
                      'ไม่พบข้อมูล',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isD ? 14 : 6),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppTheme.primaryColor.withValues(alpha: 0.05),
                            ),
                            headingRowHeight: 44,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            columnSpacing: isL ? 14 : (isD ? 10 : 6),
                            columns: [
                              DataColumn(label: _hdr('ID', 35, bf)),
                              DataColumn(label: _hdr('กลุ่ม', 150, bf)),
                              DataColumn(label: _hdr('รายการ', 150, bf)),
                              DataColumn(label: _hdr('ราคา', 60, bf)),
                              DataColumn(label: _hdr('หมวดหมู่', 60, bf)),
                              DataColumn(label: _hdr('ลำดับ', 45, bf)),
                              DataColumn(label: _hdr('จัดการ', 60, bf)),
                            ],
                            rows: _list
                                .map(
                                  (f) => DataRow(
                                    cells: [
                                      DataCell(_cell('${f.id}', 35, bf)),
                                      DataCell(_cellWrap(f.foodgroupName, 150, bf)),
                                      DataCell(
                                        _cellWrap(f.name ?? '-', 150, bf),
                                      ),
                                      DataCell(
                                        _cell('${f.price ?? 0}', 60, bf),
                                      ),
                                      DataCell(_cell(f.section ?? '-', 60, bf)),
                                      DataCell(
                                        _cell('${f.sequence ?? 0}', 45, bf),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => _dialog(
                                                 foodtype: f,
                                               
                                              ), // ✅ ใช้ foodtype ไม่ใช่ transaction
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.edit,
                                                  size: ic - 6,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            InkWell(
                                              onTap: () => _del(f),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.delete,
                                                  size: ic - 6,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(), // ✅ .toList() หลัง .map()
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          if (_tp > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _cp > 0
                        ? () {
                            _cp = 0;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.first_page, size: ic),
                  ),
                  IconButton(
                    onPressed: _cp > 0
                        ? () {
                            _cp--;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.chevron_left, size: ic),
                  ),
                  Text(
                    'หน้า ${_cp + 1} จาก $_tp',
                    style: TextStyle(fontSize: bf),
                  ),
                  IconButton(
                    onPressed: _cp < _tp - 1
                        ? () {
                            _cp++;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.chevron_right, size: ic),
                  ),
                  IconButton(
                    onPressed: _cp < _tp - 1
                        ? () {
                            _cp = _tp - 1;
                            _load();
                          }
                        : null,
                    icon: Icon(Icons.last_page, size: ic),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hdr(String t, double w, double fs) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: w),
    child: Text(
      t,
      style: TextStyle(
        fontSize: fs - 1,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
  Widget _cell(String t, double w, double fs) => SizedBox(
    width: w,
    child: Text(
      t,
      style: TextStyle(fontSize: fs - 1),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
  Widget _cellWrap(String t, double w, double fs) => Container(
    width: w,
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      t,
      style: TextStyle(fontSize: fs - 1, height: 1.2),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
    ),
  );
}
