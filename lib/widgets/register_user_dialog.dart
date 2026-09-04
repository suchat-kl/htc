import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:highway_training/utils/logger.dart';

class RegisterUserDialog extends StatefulWidget {
  final ApiService apiService;

  const RegisterUserDialog({super.key, required this.apiService});

  @override
  State<RegisterUserDialog> createState() => _RegisterUserDialogState();
}

class _RegisterUserDialogState extends State<RegisterUserDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  List<Map<String, String>> _availableRoles = [];
   List<String> _selectedRoles = ['USER']; // Default role
// _selectedRoles.add("USER");
  // Password validation
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordStrength);
    _loadRoles();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await widget.apiService.getRoles();
      if (mounted) {
        setState(() {
          _availableRoles = roles;
        });
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.d('Error loading roles: $e');
    }
  }

  void _validatePasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoles.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาเลือกอย่างน้อย 1 บทบาท';
      });
      return;
    }

    if (!_hasMinLength ||
        !_hasUppercase ||
        !_hasLowercase ||
        !_hasDigit ||
        !_hasSpecialChar) {
      setState(() {
        _errorMessage = 'กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
     final result = await widget.apiService.registerUser(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        position: _positionController.text.trim(),
        department: _departmentController.text.trim(),
        phone: _phoneController.text.trim(),
        roles: _selectedRoles,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        context.showSuccessSnackBar('สร้างผู้ใช้งานสำเร็จ');
         // Show success dialog with user details
        _showSuccessDialog(result);
        _resetForm();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      if (mounted) {
        context.showErrorSnackBar(_errorMessage!);
      }
    }
  }
void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _usernameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _positionController.clear();
    _departmentController.clear();
    _phoneController.clear();
    setState(() {
      _selectedRoles = ['USER'];
      _errorMessage = null;
      _hasMinLength = false;
      _hasUppercase = false;
      _hasLowercase = false;
      _hasDigit = false;
      _hasSpecialChar = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 650 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxWidth: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDesktop),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 16),
                      ],
                      _buildFullNameField(isDesktop),
                      const SizedBox(height: 16),
                      _buildUsernameField(isDesktop),
                      const SizedBox(height: 16),
                      _buildEmailField(isDesktop),
                      const SizedBox(height: 16),
                      _buildPasswordField(isDesktop),
                      const SizedBox(height: 16),
                      _buildPasswordRequirements(isDesktop),
                      const SizedBox(height: 16),
                      _buildPositionField(isDesktop),
                      const SizedBox(height: 16),
                      _buildDepartmentField(isDesktop),
                      const SizedBox(height: 16),
                      _buildPhoneField(isDesktop),
                      const SizedBox(height: 16),
                      _buildRolesSelection(isDesktop),
                      const SizedBox(height: 24),
                      _buildActionButtons(isDesktop),
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

  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 45 : 38,
            height: isDesktop ? 45 : 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_add,
              color: AppTheme.primaryColor,
              size: isDesktop ? 24 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สร้างผู้ใช้งาน',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'สำหรับผู้ดูแลระบบ',
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close, color: Colors.red.shade700, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField(bool isDesktop) {
    return _buildTextField(
      label: 'ชื่อ-นามสกุล',
      hint: 'กรอกชื่อ-นามสกุล',
      icon: Icons.person,
      controller: _fullNameController,
      isDesktop: isDesktop,
      validator: (v) => v?.isEmpty == true ? 'กรุณากรอกชื่อ-นามสกุล' : null,
    );
  }

  Widget _buildUsernameField(bool isDesktop) {
    return _buildTextField(
      label: 'ชื่อผู้ใช้',
      hint: 'กรอกชื่อผู้ใช้',
      icon: Icons.account_circle,
      controller: _usernameController,
      isDesktop: isDesktop,
      validator: (v) => v?.isEmpty == true ? 'กรุณากรอกชื่อผู้ใช้' : null,
    );
  }

  Widget _buildEmailField(bool isDesktop) {
    return _buildTextField(
      label: 'อีเมล',
      hint: 'กรอกอีเมล',
      icon: Icons.email,
      controller: _emailController,
      isDesktop: isDesktop,
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v?.isEmpty == true) return 'กรุณากรอกอีเมล';
        if (!v!.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รหัสผ่าน',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          enabled: !_isLoading,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'กรอกรหัสผ่าน',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_passwordController.text.isNotEmpty)
                  _buildStrengthIndicator(),
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: TextStyle(fontSize: isDesktop ? 16 : 14),
        ),
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUppercase) strength++;
    if (_hasLowercase) strength++;
    if (_hasDigit) strength++;
    if (_hasSpecialChar) strength++;

    Color color;
    String text;
    if (strength <= 2) {
      color = Colors.red;
      text = 'อ่อน';
    } else if (strength <= 3) {
      color = Colors.orange;
      text = 'ปานกลาง';
    } else if (strength <= 4) {
      color = Colors.blue;
      text = 'ดี';
    } else {
      color = Colors.green;
      text = 'ดีมาก';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เงื่อนไขการตั้งรหัสผ่าน',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(
            'อย่างน้อย 8 ตัวอักษร',
            _hasMinLength,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีตัวอักษรพิมพ์ใหญ่ (A-Z)',
            _hasUppercase,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีตัวอักษรพิมพ์เล็ก (a-z)',
            _hasLowercase,
            isDesktop,
          ),
          _buildRequirementItem('มีตัวเลข (0-9)', _hasDigit, isDesktop),
          _buildRequirementItem(
            'มีอักขระพิเศษ (!@#\$%^&*)',
            _hasSpecialChar,
            isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: isDesktop ? 18 : 16,
            color: isValid ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionField(bool isDesktop) {
    return _buildTextField(
      label: 'ตำแหน่ง',
      hint: 'กรอกตำแหน่ง',
      icon: Icons.work,
      controller: _positionController,
      isDesktop: isDesktop,
      validator: (v) => v?.isEmpty == true ? 'กรุณากรอกตำแหน่ง' : null,
    );
  }

  Widget _buildDepartmentField(bool isDesktop) {
    return _buildTextField(
      label: 'หน่วยงาน',
      hint: 'กรอกหน่วยงาน',
      icon: Icons.business,
      controller: _departmentController,
      isDesktop: isDesktop,
      validator: (v) => v?.isEmpty == true ? 'กรุณากรอกหน่วยงาน' : null,
    );
  }

  Widget _buildPhoneField(bool isDesktop) {
    return _buildTextField(
      label: 'เบอร์โทรศัพท์',
      hint: 'กรอกเบอร์โทรศัพท์',
      icon: Icons.phone,
      controller: _phoneController,
      isDesktop: isDesktop,
      keyboardType: TextInputType.phone,
      validator: (v) => v?.isEmpty == true ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
    );
  }

  Widget _buildRolesSelection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'บทบาท (Roles)',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: Column(
            children: [
              // Selected roles chips
              if (_selectedRoles.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedRoles.map((roleCode) {
                    final roleName =
                        _availableRoles.firstWhere(
                          (r) => r['code'] == roleCode,
                          orElse: () => {'name': roleCode},
                        )['name'] ??
                        roleCode;
                    return Chip(
                      label: Text(
                        roleName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedRoles.remove(roleCode);
                        });
                      },
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Role checkboxes
              ...(_availableRoles.isEmpty
                  ? [const Center(child: CircularProgressIndicator())]
                  : _availableRoles.map((role) {
                      final code = role['code'] ?? '';
                      final name = role['name'] ?? code;
                      return CheckboxListTile(
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          'Code: $code',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        value: _selectedRoles.contains(code),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedRoles.add(code);
                            } else {
                              _selectedRoles.remove(code);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                        checkColor: Colors.white,
                      );
                    })),
            ],
          ),
        ),
        if (_selectedRoles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'กรุณาเลือกอย่างน้อย 1 บทบาท',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required bool isDesktop,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !_isLoading,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: TextStyle(fontSize: isDesktop ? 16 : 14),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: isDesktop ? 50 : 44,
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: Text(
                'ยกเลิก',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: isDesktop ? 50 : 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'สร้างผู้ใช้งาน',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
  // Add this method to RegisterUserDialog class
  void _showSuccessDialog(Map<String, dynamic> result) {
    final username = result['username'] ?? '';
    final fullName = result['full_name'] ?? '';
    final email = result['email'] ?? '';
    final roles = List<String>.from(result['roles'] ?? []);

    String roleNames = roles
        .map((r) {
          final role = _availableRoles.firstWhere(
            (ar) => ar['code'] == r,
            orElse: () => {'name': r.toString()},
          );
          return role['name'] ?? r.toString();
        })
        .join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 12),
            Text(
              'สร้างผู้ใช้งานสำเร็จ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('ชื่อผู้ใช้', username),
            const SizedBox(height: 8),
            _buildInfoRow('ชื่อ-นามสกุล', fullName),
            const SizedBox(height: 8),
            _buildInfoRow('อีเมล', email),
            const SizedBox(height: 8),
            _buildInfoRow('บทบาท', roleNames),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
