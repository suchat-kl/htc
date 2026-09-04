import 'package:flutter/material.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/utils/snackbar_helper.dart';
import 'package:highway_training/widgets/change_password_dialog.dart';
import 'package:highway_training/widgets/register_user_dialog.dart';
import 'package:highway_training/widgets/reset_password_dialog.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/login_dialog.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final AuthProvider authProvider;

  const CustomHeader({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 4,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance,
              color: AppTheme.primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ระบบศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Highway Training System',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Welcome message when logged in
        if (authProvider.isLoggedIn && MediaQuery.of(context).size.width > 600)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'ยินดีต้อนรับ, ${authProvider.displayName}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),

        // Language switch
        // TextButton.icon(
        //   onPressed: () {},
        //   icon: const Icon(Icons.language, color: Colors.white),
        //   label: const Text('TH/EN', style: TextStyle(color: Colors.white)),
        // ),
        // const SizedBox(width: 8),

        // Search
        // IconButton(
        //   icon: const Icon(Icons.search, color: Colors.white),
        //   onPressed: () {},
        // ),

        // User Profile / Login
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: authProvider.isLoggedIn
              ? _buildUserMenu(context)
              : _buildLoginButton(context),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton.icon(
        onPressed: () => _showLoginDialog(context),
        icon: const Icon(Icons.person, color: Colors.white, size: 20),
        label: const Text(
          'เข้าสู่ระบบ',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Text(
                authProvider.initials,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // User Name
            Text(
              authProvider.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            _showProfileDialog(context);
            break;
          case 'change_password':
            // Navigator.pop(context); // Close popup menu
            _showChangePasswordDialog(context);
            break;
          case 'register_user':
            _showRegisterUserDialog(context);
            break;
          case 'resetPwd':
            // Navigate to admin panel
            _showResetPasswordDialog(context);
            break;
          case 'logout':
            await authProvider.logout();

            // Check mounted before using context
            if (context.mounted) {
              context.showSuccessSnackBar('ออกจากระบบเรียบร้อย');
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(
              //     content: Text('ออกจากระบบเรียบร้อย'),
              //     backgroundColor: Colors.green,
              //     behavior: SnackBarBehavior.floating,
              //     duration: Duration(seconds: 3),
              //   ),
              // );
            }
            break;
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          // User info header
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (authProvider.username != null)
                  Text(
                    authProvider.username!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    authProvider.highestRole,
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 12),
                Text('ข้อมูลส่วนตัว'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'change_password',
            child: Row(
              children: [
                Icon(Icons.lock_reset, color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 12),
                Text('เปลี่ยนรหัสผ่าน'),
              ],
            ),
          ),
          if (authProvider.isAdmin) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              enabled: false,
              child: Text(
                'เมนูผู้ดูแลระบบ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const PopupMenuItem(
              value: 'register_user',
              child: Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text('สร้างผู้ใช้งาน'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'resetPwd',
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text('กำหนดรหัสผ่านใหม่'),
                ],
              ),
            ),
          ],
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                const SizedBox(width: 12),
                Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ];
        return items;
      },
    );
  }

  void _showRegisterUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RegisterUserDialog(apiService: ApiService()),
    ).then((result) {
      if (result == true && context.mounted) {
        context.showSuccessSnackBar('สร้างผู้ใช้งานสำเร็จ');
      }
    });
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangePasswordDialog(
        username: authProvider.username ?? '',
        apiService: ApiService(),
      ),
    ).then((result) {
      if (result == true && context.mounted) {
        context.showSuccessSnackBar('เปลี่ยนรหัสผ่านสำเร็จ');
        // Optional: Force logout after password change for security
        _showLogoutConfirmation(context);
      }
    });
  }

  void _showResetPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResetPasswordDialog(
        username: authProvider.username ?? '',
        apiService: ApiService(),
      ),
    ).then((result) {
      if (result == true && context.mounted) {
        context.showSuccessSnackBar('กำหนดรหัสผ่านใหม่สำเร็จ');
        // Optional: Force logout after password change for security
        _showLogoutConfirmation(context);
      }
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('คำแนะนำด้านความปลอดภัย'),
        content: const Text(
          'เพื่อความปลอดภัย แนะนำให้ออกจากระบบและเข้าสู่ระบบใหม่ด้วยรหัสผ่านใหม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ภายหลัง'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  // Fixed: Async gap handling
  Future<void> _showLoginDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LoginDialog(authProvider: authProvider),
    );

    // Check mounted before using context
    if (!context.mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ยินดีต้อนรับ คุณ${authProvider.displayName}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ข้อมูลผู้ใช้'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                authProvider.initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('ชื่อ: ${authProvider.displayName}'),
            if (authProvider.username != null)
              Text('ผู้ใช้งาน: ${authProvider.username}'),
            const SizedBox(height: 8),
            Text('บทบาท: ${authProvider.roleDisplayNames.join(", ")}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
