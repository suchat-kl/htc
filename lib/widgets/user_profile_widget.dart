import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class UserProfileWidget extends StatelessWidget {
  final AuthProvider authProvider;

  const UserProfileWidget({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // User Avatar
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
          const SizedBox(height: 12),

          // User Name
          Text(
            authProvider.displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          if (authProvider.email != null)
            Text(
              authProvider.email!,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(height: 12),

          // Highest Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor,
                  AppTheme.secondaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              authProvider.highestRole,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // All Roles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: authProvider.roleDisplayNames.map((role) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Menu Items
          _buildMenuItem(
            icon: Icons.person,
            title: 'ข้อมูลส่วนตัว',
            onTap: () {
              // Navigate to profile page
            },
          ),
          _buildMenuItem(
            icon: Icons.school,
            title: 'หลักสูตรของฉัน',
            onTap: () {
              // Navigate to my courses
            },
          ),
          _buildMenuItem(
            icon: Icons.assignment,
            title: 'ประวัติการอบรม',
            onTap: () {
              // Navigate to training history
            },
          ),
          if (authProvider.isAdmin || authProvider.isDirector) ...[
            const Divider(),
            const Text(
              'เมนูผู้ดูแล',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildMenuItem(
              icon: Icons.dashboard,
              title: 'แดชบอร์ด',
              onTap: () {
                // Navigate to admin dashboard
              },
            ),
            _buildMenuItem(
              icon: Icons.people,
              title: 'จัดการผู้ใช้',
              onTap: () {
                // Navigate to user management
              },
            ),
            _buildMenuItem(
              icon: Icons.menu_book,
              title: 'จัดการหลักสูตร',
              onTap: () {
                // Navigate to course management
              },
            ),
          ],
          const Divider(),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'ออกจากระบบ',
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () async {
              await authProvider.logout();
              // Check mounted before using context
              if (!context.mounted) return;
              Navigator.pop(context); // Close drawer
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: textColor ?? AppTheme.textPrimary,
        ),
      ),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
