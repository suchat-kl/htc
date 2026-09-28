import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_admin.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/permission.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/register_user_dialog.dart';

/// แก้ไขผู้ใช้งาน — เมนูผู้ดูแลระบบ (หน้าจอ USR_EDIT)
///
/// หน้าตาแบบเดียวกับหน้ารายการหลัก: ค้นหา ตาราง แก้ไขในหน้าต่าง และแบ่งหน้า
/// แก้ทีละบัญชีในหน้าต่าง เพราะมีบทบาทหลายตัวและสถานะที่ต้องยืนยัน ไม่เหมาะแก้ในตาราง
/// ไม่มีปุ่มลบ ตารางในระบบไม่มี FK cascade ลบแล้วข้อมูลที่อ้างถึงบัญชีจะค้าง ให้ระงับการใช้งานแทน
class UserEditScreen extends StatefulWidget {
  final ApiService apiService;
  const UserEditScreen({super.key, required this.apiService});

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  List<UserAdmin> _users = [];
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 10;
  String? _keyword;
  String _status = 'all';

  final TextEditingController _searchController = TextEditingController();

  // ความกว้างของแต่ละคอลัมน์ ใช้ร่วมกันทั้งหัวตารางและแถวข้อมูล
  static const double _wUsername = 150;
  static const double _wRoles = 230;
  static const double _wThaid = 150;
  static const double _wStatus = 100;
  static const double _wAction = 80;
  static const double _minTableWidth = 1000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.searchAdminUsers(
        keyword: _keyword,
        status: _status,
        page: _currentPage,
        size: _pageSize,
      );
      if (!mounted) return;
      final list = (result['users'] as List?) ?? const [];
      setState(() {
        _users = list
            .map((j) => UserAdmin.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _runSearch() {
    final k = _searchController.text.trim();
    setState(() {
      _keyword = k.isEmpty ? null : k;
      _currentPage = 0;
    });
    _loadData();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _keyword = null;
      _currentPage = 0;
    });
    _loadData();
  }

  /// เปิดหน้าต่างแก้ไข โหลดข้อมูลเต็มก่อน (รายการมีเลขบัตรแบบปิดบางส่วน)
  Future<void> _edit(UserAdmin u) async {
    try {
      final full = await widget.apiService.getAdminUser(u.id);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _UserEditDialog(user: full, apiService: widget.apiService),
      );
      if (saved == true) _loadData();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _add() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterUserDialog(apiService: widget.apiService),
    );
    if (created == true) _loadData();
  }

  Widget _tableHeader(double fs) {
    final style = TextStyle(
      fontSize: fs,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryColor,
    );
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          SizedBox(
            width: _wUsername,
            child: Text('ชื่อผู้ใช้', style: style),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('ชื่อ-สกุล / หน่วยงาน', style: style)),
          const SizedBox(width: 8),
          SizedBox(
            width: _wRoles,
            child: Text('บทบาท', style: style),
          ),
          SizedBox(
            width: _wThaid,
            child: Text('ThaID', style: style),
          ),
          SizedBox(
            width: _wStatus,
            child: Text('สถานะ', style: style),
          ),
          SizedBox(
            width: _wAction,
            child: Text('จัดการ', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _row(UserAdmin u, int index, double fs, double iconSize) {
    final sub = [
      u.position,
      u.department,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : AppTheme.fieldFillColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _wUsername,
            child: Text(
              u.username,
              style: TextStyle(fontSize: fs, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: TextStyle(fontSize: fs)),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: fs - 2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _wRoles,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final r in u.roles)
                  _chip(AuthProvider.roleName(r), AppTheme.primaryColor),
              ],
            ),
          ),
          SizedBox(
            width: _wThaid,
            child: u.thaidLinked
                ? Tooltip(
                    message: u.idcard!,
                    child: _chip('ผูกแล้ว', AppTheme.successColor),
                  )
                : Text(
                    'ยังไม่ผูก',
                    style: TextStyle(
                      fontSize: fs - 1,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
          SizedBox(
            width: _wStatus,
            child: !u.active
                ? _chip('ระงับ', AppTheme.dangerColor)
                : u.locked
                ? _chip('ล็อก', AppTheme.warningColor)
                : _chip('ใช้งาน', AppTheme.successColor),
          ),
          SizedBox(
            width: _wAction,
            child: Center(
              child: Tooltip(
                message: 'แก้ไข',
                child: InkWell(
                  onTap: Perm.view(Perm.userEdit) ? () => _edit(u) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit, size: iconSize, color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isLargeScreen = screenWidth > 1400;
    final headerFontSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final bodyFontSize = isLargeScreen ? 16.0 : (isDesktop ? 15.0 : 14.0);
    final iconSize = isLargeScreen ? 22.0 : (isDesktop ? 20.0 : 18.0);
    final canAdd = Perm.view('USR_CREATE');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'ปิด',
        ),
        title: Text(
          'แก้ไขผู้ใช้งาน',
          style: TextStyle(
            fontSize: headerFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          if (canAdd)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _add,
                icon: Icon(Icons.person_add, size: iconSize),
                label: Text(
                  'เพิ่มผู้ใช้งาน',
                  style: TextStyle(fontSize: bodyFontSize),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.addColor,
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
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 20 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width: isLargeScreen
                        ? 300
                        : (isDesktop ? 260 : double.infinity),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: bodyFontSize),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาชื่อผู้ใช้ ชื่อ-สกุล หรืออีเมล...',
                        prefixIcon: Icon(Icons.search, size: iconSize),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.fieldFillColor,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isDesktop ? 12 : 8,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: iconSize),
                                tooltip: 'ล้างคำค้น',
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.searchColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 20,
                        vertical: isDesktop ? 16 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(fontSize: bodyFontSize),
                    ),
                    child: const Text('ค้นหา'),
                  ),
                  SizedBox(
                    width: isDesktop ? 200 : double.infinity,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.fieldFillColor,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: isDesktop ? 12 : 8,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          isDense: true,
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            color: Colors.black87,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('สถานะ: ทั้งหมด'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('ใช้งาน'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('ระงับ'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null || v == _status) return;
                            setState(() {
                              _status = v;
                              _currentPage = 0;
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.manage_accounts_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ไม่พบข้อมูล',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth < _minTableWidth
                                ? _minTableWidth
                                : constraints.maxWidth;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: w,
                                child: Column(
                                  children: [
                                    _tableHeader(bodyFontSize),
                                    for (var i = 0; i < _users.length; i++)
                                      _row(
                                        _users[i],
                                        i,
                                        bodyFontSize,
                                        iconSize,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          // แถบแบ่งหน้ามาตรฐาน
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              totalPages: _totalPages,
              pageSize: _pageSize,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                _loadData();
              },
              onPageSizeChanged: (size) {
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
    );
  }
}

// ============ DIALOG ============
class _UserEditDialog extends StatefulWidget {
  final UserAdmin user;
  final ApiService apiService;

  const _UserEditDialog({required this.user, required this.apiService});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user.fullName);
  late final _email = TextEditingController(text: widget.user.email);
  late final _position = TextEditingController(text: widget.user.position);
  late final _department = TextEditingController(text: widget.user.department);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _idcard = TextEditingController(text: widget.user.idcard);
  late final Set<String> _roles = {...widget.user.roles};
  late bool _active = widget.user.active;
  late bool _locked = widget.user.locked;

  List<String> _allRoles = [];
  bool _saving = false;
  String? _error;

  bool get _canEdit => Perm.edit(Perm.userEdit);

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _position,
      _department,
      _phone,
      _idcard,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await widget.apiService.getRoles();
      if (!mounted) return;
      setState(() {
        _allRoles = roles
            .map((r) => r['name'] ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        // บทบาทที่บัญชีถืออยู่แต่ไม่อยู่ในรายการ ให้เห็นและเอาออกได้
        for (final r in _roles) {
          if (!_allRoles.contains(r)) _allRoles.add(r);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _allRoles = [..._roles]);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roles.isEmpty) {
      setState(() => _error = 'กรุณาเลือกบทบาทอย่างน้อย 1 บทบาท');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.updateAdminUser(
        UserAdmin(
          id: widget.user.id,
          username: widget.user.username,
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          position: _position.text.trim(),
          department: _department.text.trim(),
          phone: _phone.text.trim(),
          idcard: _idcard.text.replaceAll(RegExp(r'[^0-9]'), ''),
          roles: _roles.toList(),
          active: _active,
          locked: _locked,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      context.showSuccessSnackBar('บันทึกข้อมูลผู้ใช้เรียบร้อย');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
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
        width: isDesktop ? 620 : double.infinity,
        constraints: const BoxConstraints(maxWidth: 680),
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
                    child: const Icon(
                      Icons.manage_accounts,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'แก้ไขผู้ใช้งาน: ${widget.user.username}',
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      _field(
                        'ชื่อ-นามสกุล',
                        _fullName,
                        validator: (v) => (v ?? '').trim().length < 3
                            ? 'กรุณากรอกชื่อ-นามสกุล อย่างน้อย 3 ตัวอักษร'
                            : null,
                      ),
                      _field(
                        'อีเมล',
                        _email,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) =>
                            RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch((v ?? '').trim())
                            ? null
                            : 'รูปแบบอีเมลไม่ถูกต้อง',
                      ),
                      _field('ตำแหน่ง', _position),
                      _field('หน่วยงาน', _department),
                      _field(
                        'เบอร์โทรศัพท์',
                        _phone,
                        keyboard: TextInputType.phone,
                      ),
                      _field(
                        'เลขบัตรประชาชน (ไม่บังคับ ใส่แล้วเข้าสู่ระบบด้วย ThaID ได้)',
                        _idcard,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                          if (d.isEmpty) return null;
                          if (d.length != 13) {
                            return 'เลขบัตรประชาชนต้องมี 13 หลัก';
                          }
                          if (!Util.isValidThaiId(d)) {
                            return 'เลขบัตรประชาชนไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'บทบาท',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _allRoles.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: LinearProgressIndicator(),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final r in _allRoles)
                                  FilterChip(
                                    label: Text(AuthProvider.roleName(r)),
                                    tooltip: r,
                                    selected: _roles.contains(r),
                                    onSelected: _canEdit
                                        ? (v) => setState(() {
                                            v
                                                ? _roles.add(r)
                                                : _roles.remove(r);
                                          })
                                        : null,
                                  ),
                              ],
                            ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดใช้งานบัญชี'),
                        subtitle: Text(
                          _active
                              ? 'ใช้งานได้ตามปกติ'
                              : 'ระงับแล้ว เข้าสู่ระบบไม่ได้ และถูกออกจากระบบทันทีเมื่อบันทึก',
                        ),
                        value: _active,
                        activeThumbColor: AppTheme.successColor,
                        onChanged: _canEdit
                            ? (v) => setState(() => _active = v)
                            : null,
                      ),
                      if (widget.user.locked)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('บัญชีถูกล็อก'),
                          subtitle: const Text(
                            'ล็อกจากการใส่รหัสผ่านผิดหลายครั้ง ปิดเพื่อปลดล็อก',
                          ),
                          value: _locked,
                          activeThumbColor: AppTheme.warningColor,
                          onChanged: _canEdit
                              ? (v) => setState(() => _locked = v)
                              : null,
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.cancelColor,
                                side: const BorderSide(
                                  color: AppTheme.cancelColor,
                                ),
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
                              onPressed: _saving || !_canEdit ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.saveColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('บันทึก'),
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
    TextEditingController c, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: c,
            enabled: _canEdit,
            keyboardType: keyboard,
            validator: validator,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppTheme.fieldFillColor,
              isDense: true,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
