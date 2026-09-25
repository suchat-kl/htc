// lib/screens/notification_screen.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/notification_item.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/app_pagination.dart';
import '../widgets/notification_dialog.dart';

/// จัดการประกาศประชาสัมพันธ์ (เมนูการดำเนินงาน)
///
/// ต่างจากข้อความวิ่งตรงที่มีหัวเรื่อง เนื้อความยาว และช่วงวันที่ที่ให้แสดง
/// ประกาศที่อยู่ในช่วงวันที่และสถานะใช้งาน จะไปโผล่บนหน้าแรก
class NotificationScreen extends StatefulWidget {
  final ApiService apiService;

  const NotificationScreen({super.key, required this.apiService});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<NotificationItem> _items = [];
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _loading = true;

  /// ตัวกรองสถานะ null = ทุกสถานะ
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.apiService.getNotifications(
        page: _currentPage,
        size: _pageSize,
        title: _searchCtrl.text.trim(),
        status: _statusFilter,
      );
      if (!mounted) return;
      final list = r['notifications'] as List?;
      setState(() {
        _items = list
                ?.map((e) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        _totalPages = r['totalPages'] as int? ?? 1;
        _totalItems = r['totalItems'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      context.showErrorSnackBar('ไม่สามารถโหลดข้อมูลได้');
    }
  }

  Future<void> _openDialog({NotificationItem? item}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotificationDialog(
        apiService: widget.apiService,
        item: item,
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      context.showSuccessSnackBar(
          item == null ? 'เพิ่มประกาศเรียบร้อย' : 'อัปเดตประกาศเรียบร้อย');
      _load();
    }
  }

  Future<void> _delete(NotificationItem item) async {
    final ok = await AppDialog.showConfirm(
      context,
      'ต้องการลบประกาศ "${item.title ?? ''}" ใช่หรือไม่',
      confirmText: 'ลบ',
    );
    if (ok != true) return;

    try {
      await widget.apiService.deleteNotification(item.id!);
      if (!mounted) return;
      context.showSuccessSnackBar('ลบประกาศเรียบร้อย');
      _load();
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final canAdd = Perm.add(Perm.notification);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ประกาศประชาสัมพันธ์',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: canAdd ? () => _openDialog() : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มประกาศ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.addColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isDesktop || !canAdd
          ? null
          : FloatingActionButton(
              onPressed: () => _openDialog(),
              backgroundColor: AppTheme.addColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _card(_items[i], isDesktop),
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              currentPage: _currentPage,
              totalPages: _totalPages < 1 ? 1 : _totalPages,
              pageSize: _pageSize,
              summary: 'ทั้งหมด $_totalItems ประกาศ',
              onPageChanged: (p) {
                _currentPage = p;
                _load();
              },
              onPageSizeChanged: (s) {
                _pageSize = s;
                _currentPage = 0;
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) {
                _currentPage = 0;
                _load();
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาจากหัวเรื่อง',
                prefixIcon: const Icon(Icons.search, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                filled: true,
                fillColor: AppTheme.fieldFillColor,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              initialValue: _statusFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'สถานะ',
                labelStyle: const TextStyle(fontSize: 13),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                filled: true,
                fillColor: AppTheme.fieldFillColor,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                DropdownMenuItem(value: '1', child: Text('ใช้งาน')),
                DropdownMenuItem(value: '2', child: Text('ไม่ใช้งาน')),
              ],
              onChanged: (v) {
                _statusFilter = v;
                _currentPage = 0;
                _load();
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _currentPage = 0;
              _load();
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('ค้นหา'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(NotificationItem item, bool isDesktop) {
    final active = item.isActive;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.successColor.withValues(alpha: 0.12)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'ใช้งาน' : 'ไม่ใช้งาน',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: active
                          ? AppTheme.successColor
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (Perm.edit(Perm.notification))
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    tooltip: 'แก้ไข',
                    onPressed: () => _openDialog(item: item),
                  ),
                if (Perm.remove(Perm.notification))
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    tooltip: 'ลบ',
                    onPressed: () => _delete(item),
                  ),
              ],
            ),
            if ((item.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.message!,
                maxLines: isDesktop ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _meta(Icons.event, item.periodLabel ?? 'ไม่กำหนดช่วงเวลา'),
                _meta(Icons.sort, 'ลำดับ ${item.sequence ?? 0}'),
                if ((item.createdBy ?? '').isNotEmpty)
                  _meta(Icons.person_outline, item.createdBy!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'ยังไม่มีประกาศ',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
