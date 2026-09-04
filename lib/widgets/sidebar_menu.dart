// import 'dart:ui' as html;
// ignore: deprecated_member_use
// import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:highway_training/screens/booking_edit_screen.dart';
import 'package:highway_training/screens/booking_list_screen.dart';
import 'package:highway_training/screens/commodity_report_screen.dart';
import 'package:highway_training/screens/commodity_screen.dart';
import 'package:highway_training/screens/commodityin_screen.dart';
import 'package:highway_training/screens/contact_screen.dart';
import 'package:highway_training/screens/documentstatus_screen.dart';
import 'package:highway_training/screens/employee_screen.dart';
import 'package:highway_training/screens/equipment_screen.dart';
import 'package:highway_training/screens/facility_screen.dart';
import 'package:highway_training/screens/facilities_screen.dart';
import 'package:highway_training/screens/foodtype_screen.dart';
import 'package:highway_training/screens/maintenance_screen.dart';
import 'package:highway_training/screens/organization_screen.dart';
import 'package:highway_training/screens/part_screen.dart';
import 'package:highway_training/screens/room_rates_screen.dart';
import 'package:highway_training/screens/room_screen.dart';
import 'package:highway_training/screens/roomtype_screen.dart';
import 'package:highway_training/screens/section_screen.dart';
import 'package:highway_training/screens/statuscheck_screen.dart';
import 'package:highway_training/screens/tpart_screen.dart';
// import 'package:highway_training/screens/home_screen.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/utils/snackbar_helper.dart';
import 'package:highway_training/widgets/change_password_dialog.dart';
import 'package:highway_training/widgets/register_user_dialog.dart';
import 'package:highway_training/widgets/reset_password_dialog.dart';
import 'package:highway_training/widgets/ticker_message_dialog.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
// import '../widgets/user_profile_widget.dart';
import '../widgets/login_dialog.dart';

// import '../utils/event_bus.dart';
// import 'package:highway_training/screens/home_screen.dart'; // Add this import

class SidebarMenu extends StatefulWidget {
  final AuthProvider authProvider;
  final VoidCallback? onTickerSaved; // ✅ Add callback
  const SidebarMenu({
    super.key,
    required this.authProvider,
    this.onTickerSaved,
  });
  // const SidebarMenu({super.key, required this.authProvider, required Null Function() onTickerSaved});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  // Track expanded state for submenus
  final Set<String> _expandedMenus = {};

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Drawer(
      width: _getDrawerWidth(screenWidth),
      child: Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _buildResponsiveDrawer(
              context,
              constraints,
            ); // ✅ Single method
            // if (constraints.maxWidth > 400) {
            //   return _buildWideDrawer(context, constraints);
            // } else {
            //   return _buildNarrowDrawer(context, constraints);
            // }
          },
        ),
      ),
    );
  }

  // Combined responsive drawer method
  Widget _buildResponsiveDrawer(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final isWide = constraints.maxWidth > 400;

    return Column(
      children: [
        // User profile or login section
        if (widget.authProvider.isLoggedIn)
          isWide
              ? _buildUserProfileHeader(context)
              : _buildCompactUserHeader(context)
        else
          _buildLoginPrompt(context, compact: !isWide),

        // Menu items
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(vertical: isWide ? 8 : 4),
            children: [
              // Main menu
              if (isWide)
                _buildMenuSection(
                  context,
                  title: 'เมนูหลัก',
                  items: [
                    _MenuItemData(
                      Icons.home,
                      'หน้าหลัก',
                      () => Navigator.pop(context),
                    ),
                  ],
                ) //is wide
              else ...[
                _buildMenuItem(
                  context,
                  icon: Icons.home,
                  title: 'หน้าหลัก',
                  onTap: () => {
                    Navigator.pop(context),
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) =>
                    //         BookingEditScreen(apiService: ApiService()),
                    //   ),
                    // ),
                  },
                  compact: true,
                ),
              ], //not wide
              //add menu

              //add menu

              // Download with submenu
              // _buildExpandableMenuItem(
              //   context,
              //   icon: Icons.download,
              //   title: 'ดาวน์โหลดเอกสาร',
              //   menuKey: 'downloads',
              //   compact: !isWide,
              //   children: [
              //     _SubMenuItemData(
              //       Icons.description,
              //       'คู่มือการใช้งาน',
              //       () => Navigator.pop(context),
              //     ),
              //     _SubMenuItemData(
              //       Icons.book,
              //       'เอกสารประกอบการอบรม',
              //       () => Navigator.pop(context),
              //     ),
              //     _SubMenuItemData(
              //       Icons.assignment_outlined,
              //       'แบบฟอร์ม',
              //       () => Navigator.pop(context),
              //     ),
              //   ],
              // ),

              // Operations menu (USER role)
              if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
                // if (isWide) ...[
                const Divider(indent: 16, endIndent: 16),
                _buildMenuItem(
                  context,
                  icon: Icons.lock_reset,
                  title: 'เปลี่ยนรหัสผ่าน',
                  onTap: () => {
                    Navigator.pop(context),
                    _showChangePasswordDialog(context),
                  },
                  compact: true,
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'รายการหลัก',
                  menuKey: 'master',
                  children: [
                    _SubMenuItemData(Icons.room, 'สถานะห้องพัก', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StatusCheckScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.date_range, 'สถานะการจอง', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentStatusScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.restaurant, 'กลุ่มรายการอาหาร', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FoodtypeScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.bed, 'เครื่องนอน-ของใช้', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommodityScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.bed, 'สิ่งอำนวยความสะดวก', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FacilityScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.bed, 'ประเภทห้อง', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RoomtypeScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.bed, 'ห้อง', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.build, 'วัสดุซ่อมบำรุง', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PartScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.business, 'รหัสหน่วยงาน', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrganizationScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.group, 'กลุ่ม', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SectionScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.people, 'บุคลากร', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EmployeeScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                  ], //master
                ),

                //  _MenuItemData(Icons.lock_reset, 'เปลี่ยนรหัสผ่าน', () {
                //   Navigator.pop(context);
                //   _showChangePasswordDialog(context);
                // }),
                const Divider(indent: 16, endIndent: 16),
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'การดำเนินงาน',
                  menuKey: 'operations',
                  children: [
                    _SubMenuItemData(Icons.bed, 'ใบรื้อเครื่องนอน', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommodityReportScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(
                      Icons.receipt_long,
                      'บันทึกรับจ่ายของใช้',
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommodityInScreen(
                              apiService: ApiService(),
                              authProvider: widget.authProvider,
                            ),
                          ),
                        );
                      },
                    ),
                    _SubMenuItemData(Icons.build_circle, 'แจ้งซ่อม', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaintenanceScreen(
                            apiService: ApiService(),
                            authProvider: widget.authProvider,
                          ),
                        ),
                      );
                    }),
                    _SubMenuItemData(
                      Icons.handyman,
                      'บันทึกรับจ่ายวัสดุซ่อมบำรุง',
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TpartScreen(
                              apiService: ApiService(),
                              authProvider: widget.authProvider,
                            ),
                          ),
                        );
                      },
                    ),
                    _SubMenuItemData(Icons.headset_mic, 'รายการขอใช้โสตฯ', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EquipmentScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                    _SubMenuItemData(Icons.campaign, 'ข้อความวิ่ง', () {
                      Navigator.pop(context);
                      _showTickerMessageDialog(context);
                    }),
                  ],
                ),
                //]
                /*  else //not wide
                ...[
                  const Divider(indent: 16, endIndent: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.lock_reset,
                    title: 'เปลี่ยนรหัสผ่าน',
                    onTap: () => {
                      Navigator.pop(context),
                      _showChangePasswordDialog(context),
                    },
                    compact: true,
                  ),
                  _buildExpandableMenuItem(
                    context,
                    icon: Icons.settings,
                    title: 'Master',
                    menuKey: 'master',
                    children: [
                      _SubMenuItemData(Icons.bed, 'เครื่องนอน-ของใช้', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CommodityScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                      _SubMenuItemData(Icons.bed, 'สิ่งอำนวยความสะดวก', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FacilityScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                     
                      _SubMenuItemData(Icons.bed, 'ประเภทห้อง', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RoomtypeScreen(apiService: ApiService()),
                          ),
                        );
                      }),

                      _SubMenuItemData(Icons.bed, 'ห้อง', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RoomScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                      _SubMenuItemData(Icons.build, 'วัสดุซ่อมบำรุง', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PartScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                       _SubMenuItemData(Icons.business, 'รหัสหน่วยงาน', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrganizationScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                       _SubMenuItemData(Icons.group, 'กลุ่ม', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SectionScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                       _SubMenuItemData(Icons.people, 'บุคลากร', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EmployeeScreen(apiService: ApiService()),
                          ),
                        );
                      }),
                    ],//master
                  ),
                  _buildExpandableMenuItem(
                    context,
                    icon: Icons.settings,
                    title: 'การดำเนินงาน',
                    menuKey: 'operations',
                    compact: true,
                    children: [
                       _SubMenuItemData(Icons.bed, 'ใบรื้อเครื่องนอน', () {
                        Navigator.pop(context);
                          Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CommodityReportScreen(apiService: ApiService()),
                          ),
                        );
                       }),
                       _SubMenuItemData(
                        Icons.receipt_long,
                        'บันทึกรับจ่ายของใช้',
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CommodityInScreen(apiService: ApiService()),
                            ),
                          );
                        },
                      ),
                      _SubMenuItemData(Icons.campaign, 'ข้อความวิ่ง', () {
                        Navigator.pop(context);
                        _showTickerMessageDialog(context);
                      }),
                    ],
                  ),
                ],*/
                //not wide
              ],
              // Admin menu items
              if (widget.authProvider.isAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                // if (isWide)
                _buildMenuSection(
                  context,
                  title: 'เมนูผู้ดูแลระบบ',
                  titleColor: AppTheme.secondaryColor,
                  items: [
                    _MenuItemData(Icons.person_add, 'สร้างผู้ใช้งาน', () {
                      Navigator.pop(context);
                      _showRegisterUserDialog(context);
                    }),
                    _MenuItemData(
                      Icons.admin_panel_settings,
                      'กำหนดรหัสผ่านใหม่',
                      () {
                        Navigator.pop(context);
                        _showResetPasswordDialog(context);
                      },
                    ),
                  ],
                ),
                /*  else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'เมนูผู้ดูแลระบบ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.person_add,
                    title: 'สร้างผู้ใช้งาน',
                    onTap: () => {
                      Navigator.pop(context),
                      _showRegisterUserDialog(context),
                    },
                    compact: true,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.admin_panel_settings,
                    title: 'กำหนดรหัสผ่านใหม่',
                    onTap: () => {
                      Navigator.pop(context),
                      _showResetPasswordDialog(context),
                    },
                    compact: true,
                  ),
                ], */
              ],

              const Divider(indent: 16, endIndent: 16),

              _buildMenuItem(
                context,
                icon: Icons.date_range,
                title: 'จอง',
                onTap: () => {
                  Navigator.pop(context),
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BookingEditScreen(apiService: ApiService()),
                    ),
                  ),
                },
                compact: true,
              ),
              const Divider(indent: 16, endIndent: 16),
              _buildMenuItem(
                context,
                icon: Icons.date_range,
                title: 'รายการการจอง',
                onTap: () => {
                  Navigator.pop(context),
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingListScreen(
                        authProvider: widget.authProvider,
                        apiService: ApiService(),
                      ),
                    ),
                  ),
                },
                compact: true,
              ),
              const Divider(indent: 16, endIndent: 16),
              // Add in the menu items
              _buildExpandableMenuItem(
                context,
                icon: Icons.info,
                title: 'เกี่ยวกับเรา',
                menuKey: 'about_us',
                children: [
                  _SubMenuItemData(Icons.hotel, 'ราคาห้อง', () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoomRatesScreen(),
                      ),
                    );
                  }),
                  _SubMenuItemData(Icons.contact_phone, 'ติดต่อเรา', () {
                    Navigator.pop(context); // ปิด Drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    );
                  }),
                  _SubMenuItemData(Icons.spa, 'สิ่งอำนวยความสะดวก', () {
                    Navigator.pop(context); // ปิด Drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FacilitiesScreen(),
                      ),
                    );
                  }),
                ],
              ),
              //  if (isWide)
              /*  _buildMenuSection(
                  context,
                  title: 'เกี่ยวกับเรา',
                  items: [
                    _MenuItemData(
                      Icons.price_check,
                      'ราคาห้อง',
                      () {
                        Navigator.pop(context);}
                    ),
                    _MenuItemData(
                      Icons.help,
                      'ติดต่อเรา',
                      () => Navigator.pop(context),
                    ),
                    _MenuItemData(
                      Icons.tv,
                      'สิ่งอำนวยความสะดวก',
                      () => Navigator.pop(context),
                    ),
                  ],
                )
                */
              /* else ...[
                _buildMenuItem(
                  context,
                  icon: Icons.contact_mail,
                  title: 'ติดต่อเรา',
                  onTap: () => Navigator.pop(context),
                  compact: true,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.help,
                  title: 'ช่วยเหลือ',
                  onTap: () => Navigator.pop(context),
                  compact: true,
                ),
              ],
*/
              // Version info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'เวอร์ชัน 1.0.0',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getDrawerWidth(double screenWidth) {
    if (screenWidth > 1200) {
      return 360;
    } else if (screenWidth > 800) {
      return 320;
    } else if (screenWidth > 600) {
      return 300;
    } else {
      return screenWidth * 0.85;
    }
  }

  // Toggle submenu expansion
  void _toggleSubmenu(String menuKey) {
    setState(() {
      if (_expandedMenus.contains(menuKey)) {
        _expandedMenus.remove(menuKey);
      } else {
        _expandedMenus.add(menuKey);
      }
    });
  }

  /*
  // Wide drawer for desktop/tablet
  Widget _buildWideDrawer(BuildContext context, BoxConstraints constraints) {
    return Column(
      children: [
        if (widget.authProvider.isLoggedIn)
          _buildUserProfileHeader(context)
        else
          _buildLoginPrompt(context),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildMenuSection(
                context,
                title: 'เมนูหลัก',
                items: [
                  _MenuItemData(Icons.home, 'หน้าหลัก', () {
                    Navigator.pop(context);
                    // Navigate to home
                  }),
                  _MenuItemData(Icons.school, 'หลักสูตรฝึกอบรม', () {
                    Navigator.pop(context);
                    // Navigate to training
                  }),
                  _MenuItemData(Icons.calendar_today, 'ปฏิทินการอบรม', () {
                    Navigator.pop(context);
                  }),
                  _MenuItemData(Icons.person_add, 'ลงทะเบียน', () {
                    Navigator.pop(context);
                  }),
                  _MenuItemData(Icons.assignment, 'ผลการอบรม', () {
                    Navigator.pop(context);
                  }),
                  if (widget.authProvider.isLoggedIn &&
                      widget.authProvider.hasRole('USER')) ...[
                    _MenuItemData(Icons.lock_reset, 'เปลี่ยนรหัสผ่าน', () {
                      Navigator.pop(context);
                      _showChangePasswordDialog(context);
                    }),
                  ],
                ],
              ),

              const Divider(indent: 16, endIndent: 16),
              if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
                // Download menu with SUBMENU
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'Operations',
                  menuKey: 'operations',
                  children: [
                    _SubMenuItemData(Icons.description, 'ข้อความวิ่ง', () {
                      Navigator.pop(context);
                      // Handle download
                      _showTickerMessageDialog(context);
                    }),
                    _SubMenuItemData(Icons.book, 'เอกสารประกอบการอบรม', () {
                      Navigator.pop(context);
                    }),
                    _SubMenuItemData(
                      Icons.assignment_outlined,
                      'แบบฟอร์มลงทะเบียน',
                      () {
                        Navigator.pop(context);
                      },
                    ),
                    _SubMenuItemData(Icons.gavel, 'ระเบียบและข้อบังคับ', () {
                      Navigator.pop(context);
                    }),
                    _SubMenuItemData(Icons.picture_as_pdf, 'รายงานประจำปี', () {
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ],

              // Master Data section
              if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Operations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'Master',
                  menuKey: 'master',
                  children: [
                    _SubMenuItemData(Icons.bed, 'เครื่องนอน-ของใช้', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommodityScreen(apiService: ApiService()),
                        ),
                      );
                    }),
                  ],
                ),
              ],



              // Admin menu items
              if (widget.authProvider.isAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                _buildMenuSection(
                  context,
                  title: 'เมนูผู้ดูแลระบบ',
                  titleColor: AppTheme.secondaryColor,
                  items: [
                    _MenuItemData(Icons.person_add, 'สร้างผู้ใช้งาน', () {
                      Navigator.pop(context);
                      _showRegisterUserDialog(context);
                    }),
                    _MenuItemData(
                      Icons.admin_panel_settings,
                      'กำหนดรหัสผ่านใหม่',
                      () {
                        Navigator.pop(context);
                        _showResetPasswordDialog(context);
                      },
                    ),
                    _MenuItemData(Icons.menu_book, 'จัดการหลักสูตร', () {
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ],

              const Divider(indent: 16, endIndent: 16),
              _buildMenuSection(
                context,
                title: 'อื่นๆ',
                items: [
                  _MenuItemData(Icons.contact_mail, 'ติดต่อเรา', () {
                    Navigator.pop(context);
                  }),
                  _MenuItemData(Icons.help, 'ช่วยเหลือ', () {
                    Navigator.pop(context);
                  }),
                  _MenuItemData(Icons.info, 'เกี่ยวกับ', () {
                    Navigator.pop(context);
                  }),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'เวอร์ชัน 1.0.0',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
*/
  void _showResetPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResetPasswordDialog(
        username: widget.authProvider.username ?? '',
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

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      // showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangePasswordDialog(
        username: widget.authProvider.username ?? '',
        apiService: ApiService(),
      ),
    );
    // Check mounted before using context
    if (!context.mounted) return;

    if (result == true) {
      context.showSuccessSnackBar('เปลี่ยนรหัสผ่านสำเร็จ');
      debugPrint('เปลี่ยนรหัสผ่านสำเร็จ');
      // Optional: Force logout after password change for security
      _showLogoutConfirmation(context);
    }
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
              widget.authProvider.logout();
            },
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  // In the state class:
  void _showTickerMessageDialog(BuildContext context) {
    // Navigator.pop(context);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) =>
              TickerMessageDialog(apiService: ApiService()),
        ).then((result) {
          if (result == true && context.mounted) {
            context.showSuccessSnackBar('บันทึกข้อความวิ่งสำเร็จ');

            // ✅ Simple: Just refresh the ticker

            // ✅ Show manual refresh hint
            // Future.delayed(const Duration(seconds: 2), () {
            //   if (context.mounted) {
            //     context.showInfoSnackBar(
            //       'หากข้อความไม่เปลี่ยนแปลง กรุณารีเฟรชหน้าเว็บ (F5)',
            //     );
            //   }
            // });
          }
        });
      }
    });
  }

  // void reloadPage() {
  //   js.context.callMethod('reloadPage', []);
  // }
  // void _showReloadConfirmation(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (dialogContext) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Row(
  //         children: [
  //           Icon(Icons.refresh, color: Colors.blue),
  //           SizedBox(width: 10),
  //           Text('รีโหลดหน้าเว็บ'),
  //         ],
  //       ),
  //       content: const Text(
  //         'บันทึกข้อความวิ่งสำเร็จ\n\nต้องการรีโหลดหน้าเว็บเพื่อแสดงผลทันทีหรือไม่?',
  //         style: TextStyle(fontSize: 14),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(dialogContext),
  //           child: const Text('ภายหลัง'),
  //         ),
  //         ElevatedButton.icon(
  //           onPressed: () {
  //             Navigator.pop(dialogContext);
  //             html.window.location.reload();
  //           },
  //           icon: const Icon(Icons.refresh, size: 18),
  //           label: const Text('รีโหลดเลย'),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.blue,
  //             foregroundColor: Colors.white,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  /*
  // Narrow drawer for mobile
  Widget _buildNarrowDrawer(BuildContext context, BoxConstraints constraints) {
    return Column(
      children: [
        if (widget.authProvider.isLoggedIn)
          _buildCompactUserHeader(context)
        else
          _buildLoginPrompt(context, compact: true),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _buildMenuItem(
                context,
                icon: Icons.home,
                title: 'หน้าหลัก',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              _buildMenuItem(
                context,
                icon: Icons.school,
                title: 'หลักสูตรฝึกอบรม',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              _buildMenuItem(
                context,
                icon: Icons.calendar_today,
                title: 'ปฏิทินการอบรม',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              _buildMenuItem(
                context,
                icon: Icons.person_add,
                title: 'ลงทะเบียน',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              _buildMenuItem(
                context,
                icon: Icons.assignment,
                title: 'ผลการอบรม',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
                _buildMenuItem(
                  context,
                  icon: Icons.lock_reset,
                  title: 'เปลี่ยนรหัสผ่าน',
                  onTap: () => {
                    Navigator.pop(context),
                    _showChangePasswordDialog(context),
                  },
                  compact: true,
                ),

                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Operations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'การดำเนินงาน',
                  menuKey: 'operations',
                  children: [
                    _SubMenuItemData(Icons.campaign, 'ข้อความวิ่ง', () {
                      Navigator.pop(context);
                      _showTickerMessageDialog(context);
                    }),
                  ],
                ),
              ],



              // Download with submenu (compact)
              _buildExpandableMenuItem(
                context,
                icon: Icons.download,
                title: 'ดาวน์โหลดเอกสาร',
                menuKey: 'downloads',
                compact: true,
                children: [
                  _SubMenuItemData(Icons.description, 'คู่มือการใช้งาน', () {
                    Navigator.pop(context);
                  }),
                  _SubMenuItemData(Icons.book, 'เอกสารประกอบการอบรม', () {
                    Navigator.pop(context);
                  }),
                  _SubMenuItemData(Icons.assignment_outlined, 'แบบฟอร์ม', () {
                    Navigator.pop(context);
                  }),
                ],
              ),


//test master
if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Operations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _buildExpandableMenuItem(
                  context,
                  icon: Icons.settings,
                  title: 'Master',
                  menuKey: 'master',
                  children: [
                    _SubMenuItemData(Icons.bed, 'เครื่องนอน-ของใช้', () {
                        Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommodityScreen(apiService: ApiService()),
                      ),
                    );
                    }),
                  ],
                ),
            ],


//test master

              // Master Data section
              /*if (widget.authProvider.isLoggedIn &&
                  widget.authProvider.hasRole('USER')) ...[
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    'Master',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.bed,
                  title: 'เครื่องนอน-ของใช้',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommodityScreen(apiService: ApiService()),
                      ),
                    );
                  },
                ),
              ],
*/
              if (widget.authProvider.isAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'เมนูผู้ดูแลระบบ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_add,
                  title: 'สร้างผู้ใช้งาน',
                  onTap: () => {
                    Navigator.pop(context),
                    _showRegisterUserDialog(context),
                  },
                  compact: true,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.people,
                  title: 'กำหนดรหัสผ่านใหม่',
                  onTap: () => {
                    Navigator.pop(context),
                    _showResetPasswordDialog(context),
                  },
                  compact: true,
                ),
              ],

              const Divider(indent: 16, endIndent: 16),
              _buildMenuItem(
                context,
                icon: Icons.contact_mail,
                title: 'ติดต่อเรา',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
              _buildMenuItem(
                context,
                icon: Icons.help,
                title: 'ช่วยเหลือ',
                onTap: () => Navigator.pop(context),
                compact: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
*/
  // Expandable menu item with submenu
  /* Widget _buildExpandableMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String menuKey,
    required List<_SubMenuItemData> children,
    bool compact = false,
  }) {
    final isExpanded = _expandedMenus.contains(menuKey);

    return Column(
      children: [
        // Parent menu item
        ListTile(
          leading: Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
            ),
            child: Icon(
              icon,
              color: isExpanded
                  ? AppTheme.secondaryColor
                  : AppTheme.primaryColor,
              size: compact ? 20 : 22,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: compact ? 14 : 15,
              fontWeight: isExpanded ? FontWeight.bold : FontWeight.w500,
              color: isExpanded ? AppTheme.primaryColor : AppTheme.textPrimary,
            ),
          ),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.chevron_right,
              size: compact ? 18 : 20,
              color: isExpanded ? AppTheme.primaryColor : Colors.grey.shade400,
            ),
          ),
          dense: compact,
          contentPadding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 2 : 4,
          ),
          onTap: () => _toggleSubmenu(menuKey),
          hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 6 : 8),
          ),
        ),

        // Submenu items with animation
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: EdgeInsets.only(
              left: compact ? 56 : 64,
              right: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              border: Border(
                left: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: children.map((subItem) {
                return ListTile(
                  leading: Icon(
                    subItem.icon,
                    size: compact ? 16 : 18,
                    color: AppTheme.textSecondary,
                  ),
                  title: Text(
                    subItem.title,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 12,
                  ),
                  visualDensity: VisualDensity.compact,
                  onTap: subItem.onTap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 4 : 6),
                  ),
                  hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
                );
              }).toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
*/
  // User profile header for wide drawer
  Widget _buildUserProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: Text(
              widget.authProvider.initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.authProvider.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (widget.authProvider.username != null)
            Text(
              widget.authProvider.username!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.authProvider.highestRole,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await widget.authProvider.logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('ออกจากระบบ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact user header
  Widget _buildCompactUserHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              widget.authProvider.initials,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authProvider.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.authProvider.highestRole,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.authProvider.logout();
            },
            icon: Icon(
              Icons.logout,
              color: Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // Login prompt
  Widget _buildLoginPrompt(BuildContext context, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
            ),
            child: Icon(
              Icons.account_balance,
              color: AppTheme.primaryColor,
              size: compact ? 30 : 40,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            'ระบบฝึกอบรม',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'กรมทางหลวง',
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 14,
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) =>
                      LoginDialog(authProvider: widget.authProvider),
                );
              },
              icon: Icon(Icons.login, size: compact ? 18 : 20),
              label: Text(
                'เข้าสู่ระบบ',
                style: TextStyle(fontSize: compact ? 14 : 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Menu section with title
  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    Color? titleColor,
    required List<_MenuItemData> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: titleColor ?? Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map(
          (item) => _buildMenuItem(
            context,
            icon: item.icon,
            title: item.title,
            onTap: item.onTap,
          ),
        ),
      ],
    );
  }

  // Regular menu item
  /*Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return ListTile(
      leading: Container(
        width: compact ? 36 : 40,
        height: compact ? 36 : 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: compact ? 20 : 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: compact ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: compact ? 18 : 20,
        color: Colors.grey.shade400,
      ),
      dense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 2 : 4,
      ),
      onTap: onTap,
      hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
    );
  }
  */
  // Regular menu item - FIXED
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 2 : 4,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(compact ? 8 : 10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: compact ? 20 : 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: compact ? 18 : 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Expandable menu item with submenu - FIXED
  Widget _buildExpandableMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String menuKey,
    required List<_SubMenuItemData> children,
    bool compact = false,
  }) {
    final isExpanded = _expandedMenus.contains(menuKey);

    return Column(
      children: [
        // Parent menu item
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleSubmenu(menuKey),
            borderRadius: BorderRadius.circular(compact ? 6 : 8),
            hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 20,
                vertical: compact ? 2 : 4,
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Icon(
                      icon,
                      color: isExpanded
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                      size: compact ? 20 : 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: isExpanded
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isExpanded
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: compact ? 18 : 20,
                      color: isExpanded
                          ? AppTheme.primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Submenu items with animation
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: EdgeInsets.only(
              left: compact ? 56 : 64,
              right: compact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              border: Border(
                left: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: children.map((subItem) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: subItem.onTap,
                    borderRadius: BorderRadius.circular(compact ? 4 : 6),
                    hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
                    splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 16,
                        vertical: compact ? 8 : 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            subItem.icon,
                            size: compact ? 16 : 18,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subItem.title,
                              style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: compact ? 12 : 14,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// Data classes for menu items
class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _MenuItemData(this.icon, this.title, this.onTap);
}

class _SubMenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  _SubMenuItemData(this.icon, this.title, this.onTap);
}
