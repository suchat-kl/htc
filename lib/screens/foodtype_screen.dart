import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/foodtype.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../widgets/app_pagination.dart';
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

  /// ช่องค้นหา — ค้นเมื่อกดปุ่มค้นหาหรือกด Enter เท่านั้น
  final TextEditingController _searchCtrl = TextEditingController();

  /// นับรอบรีเซ็ตตัวกรอง — เปลี่ยนค่าเพื่อบังคับสร้าง dropdown ใหม่
  /// ให้กลับไปแสดงค่าเดิมเมื่อผู้ใช้ไม่ยอมทิ้งการแก้ไข
  int _filterEpoch = 0;

  /// แถวที่แก้ไขได้ในตาราง — สร้างใหม่ทุกครั้งที่โหลดข้อมูล
  final List<_EditRow> _rows = [];

  /// รหัสของแถวที่กดลบออกจากหน้าจอแล้ว แต่ยังไม่ได้ลบในฐานข้อมูล
  final List<int> _deletedIds = [];

  /// กำลังบันทึกอยู่ กันกดซ้ำ
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
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
          // สร้างแถวแก้ไขใหม่ทุกครั้งที่โหลด การแก้ไขค้างจะถูกทิ้งไปพร้อมกัน
          _rebuildRows();
          _deletedIds.clear();
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
      builder: (c) => FoodtypeDialog(
        foodtype: foodtype,
        // ✅ ส่งค่าถูกต้อง
        apiService: widget.apiService,
      ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteColor,
            ),
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
      ..addAll(_list.map(_EditRow.from));
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
      activeColor: AppTheme.primaryColor,
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

  /// เพิ่มแถวว่างท้ายตาราง ID เป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่ให้กรอก
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
  /// ID เป็นเลขที่ฐานข้อมูลสร้างเอง จึงไม่มีการตรวจรหัสซ้ำ
  /// แต่ชื่อรายการในกลุ่มเดียวกันต้องไม่ซ้ำกัน
  String? _validateRows() {
    final keys = <String, int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final no = i + 1;
      final name = r.nameCtrl.text.trim();
      if (name.isEmpty) return 'แถวที่ $no ยังไม่ได้กรอกรายการ';
      if (r.price == null) return 'แถวที่ $no ราคาต้องเป็นตัวเลข';
      if (r.sequence == null) return 'แถวที่ $no ลำดับต้องเป็นตัวเลข';
      final key = '${r.group}|$name';
      if (keys.containsKey(key)) {
        return 'รายการ "$name" ซ้ำกันในกลุ่มเดียวกัน '
            '(แถวที่ ${keys[key]! + 1} และ $no)';
      }
      keys[key] = i;
    }
    return null;
  }

  /// บันทึกทุกแถวที่แก้ไขในครั้งเดียว
  ///
  /// ลบแถวที่เอาออก สร้างแถวใหม่ และอัปเดตแถวที่ค่าเปลี่ยน แล้วโหลดข้อมูลใหม่
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
        await widget.apiService.deleteFoodtype(id);
      }
      _deletedIds.clear();

      for (final r in _rows) {
        final item = r.toFoodtype();
        if (r.isNew) {
          await widget.apiService.createFoodtype(item);
        } else if (r.changed) {
          await widget.apiService.updateFoodtype(r.originalId!, item);
        }
      }

      if (!mounted) return;
      context.showSuccessSnackBar('บันทึกเรียบร้อยแล้ว');
      setState(() => _isSaving = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showErrorSnackBar(
        'บันทึกไม่สำเร็จ\n${e.toString().replaceAll('Exception: ', '')}',
      );
      // อาจบันทึกสำเร็จไปแล้วบางส่วน จึงโหลดใหม่ให้ตรงของจริง
      await _load();
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

  /// ค้นหาตามคำในช่องค้นหา — เรียกจากปุ่มค้นหาและการกด Enter
  Future<void> _search() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _fName = _searchCtrl.text;
      _cp = 0;
    });
    _load();
  }

  /// ล้างคำค้นแล้วโหลดใหม่
  Future<void> _clearSearch() async {
    if (!await _confirmDiscard()) return;
    setState(() {
      _searchCtrl.clear();
      _fName = '';
      _cp = 0;
    });
    _load();
  }

  /// เปลี่ยนตัวกรองกลุ่ม — ถ้าไม่ยอมทิ้งการแก้ไข ให้ dropdown กลับไปแสดงค่าเดิม
  Future<void> _changeGroupFilter(int? value) async {
    if (value == _fGroup) return;
    if (!await _confirmDiscard()) {
      setState(() => _filterEpoch++);
      return;
    }
    setState(() {
      _fGroup = value;
      _cp = 0;
    });
    _load();
  }

  /// หนึ่งแถวของตารางที่แก้ไขได้
  ///
  /// ID เป็นคีย์ที่ฐานข้อมูลสร้างเอง จึงแสดงอย่างเดียว แก้ไม่ได้ทุกแถว
  DataRow _editableRow(_EditRow row, double bf, double ic) {
    return DataRow(
      cells: [
        DataCell(
          Checkbox(
            value: row.selected,
            activeColor: AppTheme.primaryColor,
            onChanged: (v) => setState(() => row.selected = v ?? false),
          ),
        ),
        DataCell(
          SizedBox(
            width: 35,
            child: Text(
              row.isNew ? 'ใหม่' : '${row.originalId}',
              style: TextStyle(
                fontSize: bf - 1,
                color: row.isNew ? AppTheme.warningColor : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 165,
            child: DropdownButtonFormField<int>(
              initialValue: row.group,
              isExpanded: true,
              style: TextStyle(fontSize: bf - 1, color: AppTheme.textPrimary),
              decoration: _rowInput(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('อาหารหลัก')),
                DropdownMenuItem(
                  value: 2,
                  child: Text('อาหารว่างและเครื่องดื่ม'),
                ),
              ],
              onChanged: (v) => setState(() => row.group = v ?? 1),
            ),
          ),
        ),
        DataCell(_rowInputField(row.nameCtrl, 180, bf)),
        DataCell(_rowInputField(row.priceCtrl, 80, bf, digitsOnly: true)),
        DataCell(_rowInputField(row.sectionCtrl, 110, bf)),
        DataCell(_rowInputField(row.seqCtrl, 70, bf, digitsOnly: true)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rowIcon(
                Icons.edit,
                Colors.blue,
                ic,
                'แก้ไขในหน้าต่าง',
                row.isNew ? null : () => _dialog(foodtype: row.toFoodtype()),
              ),
              const SizedBox(width: 2),
              _rowIcon(
                Icons.delete,
                Colors.red,
                ic,
                'ลบทันที',
                row.isNew ? null : () => _del(row.toFoodtype()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ปุ่มไอคอนรายแถว ปิดไว้สำหรับแถวที่เพิ่งเพิ่ม (ยังไม่มีในฐานข้อมูล)
  Widget _rowIcon(
    IconData icon,
    Color color,
    double ic,
    String tooltip,
    VoidCallback? onTap,
  ) {
    final c = onTap == null ? Colors.grey : color;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: ic - 6, color: c),
        ),
      ),
    );
  }

  Widget _rowInputField(
    TextEditingController c,
    double w,
    double bf, {
    bool digitsOnly = false,
  }) {
    return SizedBox(
      width: w,
      child: TextField(
        controller: c,
        style: TextStyle(fontSize: bf - 1),
        keyboardType: digitsOnly ? TextInputType.number : null,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: _rowInput(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  InputDecoration _rowInput() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  /// แถวปุ่มใต้ตาราง — ลบที่เลือก เลือกทั้งหมด เพิ่ม และบันทึก
  Widget _rowActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_dirty)
            Text(
              'มีการแก้ไขที่ยังไม่ได้บันทึก',
              style: TextStyle(fontSize: 13, color: AppTheme.warningColor),
            ),
          _rowButton(
            'ลบที่เลือก',
            _deleteSelectedRows,
            color: AppTheme.deleteColor,
          ),
          _rowButton('เลือกทั้งหมด', _rows.isEmpty ? null : _selectAll),
          _rowButton('เพิ่ม', _addRow, color: AppTheme.addColor),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveRows,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.saveColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.saveColor.withValues(
                alpha: 0.45,
              ),
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

  Widget _rowButton(
    String label,
    VoidCallback? onTap, {
    Color color = AppTheme.neutralColor,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
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
    final sw = MediaQuery.of(context).size.width;
    final isD = sw > 1024;
    final isL = sw > 1400;
    final hf = isL ? 22.0 : (isD ? 20.0 : 18.0);
    final bf = isL ? 16.0 : (isD ? 15.0 : 14.0);
    final ic = isL ? 22.0 : (isD ? 20.0 : 18.0);
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
                  backgroundColor: AppTheme.addColor,
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
                        controller: _searchCtrl,
                        style: TextStyle(fontSize: bf - 1),
                        decoration: InputDecoration(
                          hintText: 'ค้นหารายการ...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: 'ล้างคำค้น',
                                  onPressed: _clearSearch,
                                )
                              : null,
                        ),
                        // พิมพ์แล้วให้ปุ่มกากบาทโผล่/หาย แต่ยังไม่โหลดข้อมูล
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.searchColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isD ? 20 : 14,
                          vertical: isD ? 14 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: TextStyle(fontSize: bf - 1),
                      ),
                      child: const Text('ค้นหา'),
                    ),
                    SizedBox(
                      width: isL ? 170 : (isD ? 140 : 120),
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('fgroup-$_fGroup-$_filterEpoch'),
                        initialValue: _fGroup,
                        isExpanded: true,
                        style: TextStyle(fontSize: bf - 1),
                        decoration: InputDecoration(
                          hintText: 'กลุ่ม',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: AppTheme.fieldFillColor,
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
                        onChanged: _changeGroupFilter,
                      ),
                    ),
                    // ตัวเลือกแถวต่อหน้าย้ายไปอยู่ในแถบแบ่งหน้า (AppPagination) แล้ว
                  ],
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ไม่พบข้อมูล',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add),
                            label: const Text('เพิ่มแถวในตาราง'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.addColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 64,
                              columnSpacing: isL ? 14 : (isD ? 10 : 6),
                              columns: [
                                DataColumn(label: _headerCheckbox()),
                                DataColumn(label: _hdr('ID', 35, bf)),
                                DataColumn(label: _hdr('กลุ่ม', 165, bf)),
                                DataColumn(label: _hdr('รายการ', 180, bf)),
                                DataColumn(label: _hdr('ราคา', 80, bf)),
                                DataColumn(label: _hdr('หมวดหมู่', 110, bf)),
                                DataColumn(label: _hdr('ลำดับ', 70, bf)),
                                DataColumn(label: _hdr('จัดการ', 60, bf)),
                              ],
                              rows: _rows
                                  .map((r) => _editableRow(r, bf, ic))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            _rowActionBar(),

            // แถบแบ่งหน้ามาตรฐาน (มีตัวเลือกแถวต่อหน้าในตัว)
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
              child: AppPagination(
                currentPage: _cp,
                totalPages: _tp,
                pageSize: _ps,
                onPageChanged: (page) async {
                  if (!await _confirmDiscard()) return;
                  _cp = page;
                  _load();
                },
                onPageSizeChanged: (size) async {
                  if (!await _confirmDiscard()) return;
                  _ps = size;
                  _cp = 0;
                  _load();
                },
              ),
            ),
          ],
        ),
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
}

/// หนึ่งแถวที่แก้ไขได้ในตารางกลุ่มรายการอาหาร
class _EditRow {
  /// ID เดิมตอนโหลดมา — null แปลว่าเป็นแถวใหม่ที่ยังไม่มีในฐานข้อมูล
  final int? originalId;
  final int originalGroup;
  final String originalName;
  final String originalPrice;
  final String originalSection;
  final String originalSeq;

  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController sectionCtrl;
  final TextEditingController seqCtrl;

  /// กลุ่มรายการอาหาร (1 = อาหารหลัก, 2 = อาหารว่างและเครื่องดื่ม)
  int group;

  /// ติ๊กเลือกไว้ (สำหรับปุ่มลบที่เลือก)
  bool selected = false;

  _EditRow({
    this.originalId,
    this.originalGroup = 1,
    this.originalName = '',
    this.originalPrice = '0',
    this.originalSection = '',
    this.originalSeq = '0',
    this.group = 1,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.sectionCtrl,
    required this.seqCtrl,
  });

  factory _EditRow.from(Foodtype f) {
    final price = '${f.price ?? 0}';
    final seq = '${f.sequence ?? 0}';
    return _EditRow(
      originalId: f.id,
      originalGroup: f.foodgroupID ?? 1,
      originalName: f.name ?? '',
      originalPrice: price,
      originalSection: f.section ?? '',
      originalSeq: seq,
      group: f.foodgroupID ?? 1,
      nameCtrl: TextEditingController(text: f.name ?? ''),
      priceCtrl: TextEditingController(text: price),
      sectionCtrl: TextEditingController(text: f.section ?? ''),
      seqCtrl: TextEditingController(text: seq),
    );
  }

  factory _EditRow.empty() => _EditRow(
    nameCtrl: TextEditingController(),
    priceCtrl: TextEditingController(text: '0'),
    sectionCtrl: TextEditingController(),
    seqCtrl: TextEditingController(text: '0'),
  );

  bool get isNew => originalId == null;

  /// ว่างถือเป็น 0 — null แปลว่ากรอกมาไม่ใช่ตัวเลข
  int? get price {
    final t = priceCtrl.text.trim();
    return t.isEmpty ? 0 : int.tryParse(t);
  }

  int? get sequence {
    final t = seqCtrl.text.trim();
    return t.isEmpty ? 0 : int.tryParse(t);
  }

  /// แถวเดิมที่ถูกแก้ค่าใดค่าหนึ่ง
  bool get changed =>
      !isNew &&
      (group != originalGroup ||
          nameCtrl.text.trim() != originalName.trim() ||
          priceCtrl.text.trim() != originalPrice.trim() ||
          sectionCtrl.text.trim() != originalSection.trim() ||
          seqCtrl.text.trim() != originalSeq.trim());

  Foodtype toFoodtype() => Foodtype(
    id: originalId,
    foodgroupID: group,
    name: nameCtrl.text.trim(),
    price: price ?? 0,
    section: sectionCtrl.text.trim(),
    sequence: sequence ?? 0,
  );

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    sectionCtrl.dispose();
    seqCtrl.dispose();
  }
}
