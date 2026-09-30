import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:highway_training/screens/contact_screen.dart';
import 'package:highway_training/screens/home_screen.dart';
import 'package:highway_training/screens/training_screen.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:highway_training/widgets/header.dart';
import 'package:highway_training/widgets/change_password_dialog.dart';
import 'package:highway_training/services/api_service.dart';
import 'package:highway_training/widgets/sidebar_menu.dart';
import 'package:highway_training/providers/auth_provider.dart';
// import 'package:intl/date_symbol_data_file.dart';
// import 'package:intl/intl.dart';
import 'config/theme.dart';
// import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== กันข้อมูลรั่วลง browser console ตอน production =====
  // AppLogger ถูก tree-shake ออกไปแล้วตั้งแต่ตอน compile (ดู lib/utils/logger.dart)
  // สองบล็อกนี้เป็นตาข่ายชั้นสุดท้าย เผื่อมี debugPrint หลุดเข้ามาใหม่
  // หรือมาจาก package ภายนอกที่เราคุมไม่ได้
  if (kReleaseMode) {
    // ปิด debugPrint ทุกจุด รวมถึงของ framework และ package อื่น
    debugPrint = (String? message, {int? wrapWidth}) {};

    // Flutter จะ dump stack trace ลง console เองเมื่อเกิด error แม้ใน release
    // อันนี้เป็นคนละกลไกกับ AppLogger จึงต้องดักแยก
    FlutterError.onError = (FlutterErrorDetails details) {};
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Force load Thai font
  // GoogleFonts.config.allowRuntimeFetching = true;

  // Pre-cache the font
  // await GoogleFonts.pendingFonts([
  //   GoogleFonts.sarabun(),
  //   GoogleFonts.notoSansThai(),
  // ]);
  // Initialize auth and load session
  final authProvider = AuthProvider();
  await authProvider.loadSession();
  // Initialize Thai locale
  // initializeDateFormatting('th_TH', 'th');

  // For newer Flutter versions
  // Intl.defaultLocale = 'th';
  // initializeDateFormatting('th_TH', 'th');

  runApp(HighwayTrainingApp(authProvider: authProvider));
}

class HighwayTrainingApp extends StatefulWidget {
  final AuthProvider authProvider;

  const HighwayTrainingApp({super.key, required this.authProvider});

  @override
  State<HighwayTrainingApp> createState() => _HighwayTrainingAppState();
}

class _HighwayTrainingAppState extends State<HighwayTrainingApp> {
  @override
  void initState() {
    super.initState();
    // Listen for auth state changes
    widget.authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    // ต้องถอด listener ออก ไม่งั้น AuthProvider (มีอายุยืนกว่า State นี้)
    // จะยังถือ closure ที่อ้างถึง State ที่ถูก dispose ไปแล้วอยู่
    widget.authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบศูนย์พัฒนาทรัพยากรบุคคลงานทาง กรมทางหลวง',
      debugShowCheckedModeBanner: false,
      // 1. Enable Thai locale globally or per widget
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('en', 'US'), Locale('th', 'TH')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // locale: const Locale('th'),
      // supportedLocales: const [Locale('th'), Locale('en')],
      // localizationsDelegates: const [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      theme: AppTheme.lightTheme,
      home: MainNavigation(authProvider: widget.authProvider),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final AuthProvider authProvider;

  const MainNavigation({super.key, required this.authProvider});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  /// ตรึงเมนูไว้ข้างซ้าย จำไว้ในเบราว์เซอร์ (localStorage ไม่หายตอนออกจากระบบ
  /// ต่างจาก secure storage ที่ถูกล้างทุกครั้งที่ออกจากระบบ)
  static const String _pinnedKey = 'htc_menu_pinned';
  bool _menuPinned = _readPinned();

  /// ตอนตรึง: true = แสดงเฉพาะไอคอน กดปุ่มหรือไอคอนกลุ่มเมนูแล้วขยายเห็นชื่อ
  bool _menuCollapsed = true;

  /// ตรึงเมนูได้เฉพาะจอกว้าง จอแคบ (มือถือ/แท็บเล็ตแนวตั้ง) ใช้เมนูเลื่อนออกแบบเดิม
  static const double _pinMinWidth = 900;

  /// ตอนตรึง หน้าจอที่เปิดจากเมนูไปอยู่ใน navigator นี้ (ด้านขวาของเมนู) เมนูจึงยังเห็นอยู่
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();

  static bool _readPinned() {
    try {
      return html.window.localStorage[_pinnedKey] == '1';
    } catch (_) {
      return false;
    }
  }

  void _togglePinned() {
    setState(() {
      _menuPinned = !_menuPinned;
      _menuCollapsed = true;
    });
    try {
      html.window.localStorage[_pinnedKey] = _menuPinned ? '1' : '0';
    } catch (_) {}
  }

  /// กำลังเปิดหน้าบังคับเปลี่ยนรหัสผ่านอยู่ กันเปิดซ้อน
  bool _forcingPasswordChange = false;

  @override
  void initState() {
    super.initState();
    // ตรวจทุกครั้งที่สถานะเข้าสู่ระบบเปลี่ยน ครอบคลุมทั้งปุ่มเข้าสู่ระบบที่แถบบน เมนูข้าง
    // และการกู้ session ตอนเปิดหน้าเว็บใหม่
    widget.authProvider.addListener(_checkMustChangePassword);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkMustChangePassword(),
    );
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_checkMustChangePassword);
    super.dispose();
  }

  /// ยังใช้รหัสผ่านตั้งต้น: เปิดหน้าเปลี่ยนรหัสผ่านที่ปิดไม่ได้ เลือกได้แค่เปลี่ยนหรือออกจากระบบ
  void _checkMustChangePassword() {
    if (_forcingPasswordChange || !widget.authProvider.mustChangePassword) {
      return;
    }
    _forcingPasswordChange = true;
    // รอให้หน้าต่างเข้าสู่ระบบปิดก่อน แล้วค่อยเปิดหน้าเปลี่ยนรหัสผ่าน
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.authProvider.mustChangePassword) {
        _forcingPasswordChange = false;
        return;
      }
      // ยังมีหน้าต่างอื่นเปิดทับอยู่ (เช่นหน้าต่างเข้าสู่ระบบที่ยังโหลดสิทธิ์ไม่เสร็จ) รอให้ปิดก่อน
      // ถ้าเปิดซ้อนไป หน้าต่างเข้าสู่ระบบจะ pop ตัวบนสุด = หน้าเปลี่ยนรหัสผ่านทิ้งแทนตัวเอง
      // แล้วค้างหมุนอยู่ (เจอจริง 28 ก.ย. 2569)
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
        _forcingPasswordChange = false;
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkMustChangePassword,
        );
        return;
      }
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangePasswordDialog(
          username: widget.authProvider.username ?? '',
          apiService: ApiService(),
          forced: true,
        ),
      );
      _forcingPasswordChange = false;
      if (changed != true) {
        await widget.authProvider.logout();
      }
    });
  }

  void _onTabChanged(int index) {
    // ตรึงเมนูอยู่: ปิดหน้าที่เปิดค้างในพื้นที่ด้านขวา ให้เห็นแท็บที่เลือก
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      _currentIndex = index;
    });

    // When switching to home tab (index 0), refresh ticker
    if (index == 0) {
      // Small delay to ensure widget is built
      Future.delayed(const Duration(milliseconds: 100), () {
        // HomeScreen.homeKey.currentState?.refreshTicker();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPin = MediaQuery.of(context).size.width >= _pinMinWidth;
    final docked = _menuPinned && canPin;

    return Scaffold(
      appBar: CustomHeader(authProvider: widget.authProvider),
      // ตรึงอยู่ไม่มี drawer ปุ่มเมนูที่แถบบนจึงหายไป ใช้ปุ่มบนแถบเมนูข้างแทน
      drawer: docked
          ? null
          : SidebarMenu(
              authProvider: widget.authProvider,
              canPin: canPin,
              onTogglePinned: _togglePinned,
            ),

      body: docked
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SidebarMenu(
                  authProvider: widget.authProvider,
                  docked: true,
                  collapsed: _menuCollapsed,
                  canPin: true,
                  contentNavigator: _contentNav,
                  onToggleCollapsed: () =>
                      setState(() => _menuCollapsed = !_menuCollapsed),
                  onTogglePinned: _togglePinned,
                ),
                // หน้าจอจากเมนูเปิดซ้อนอยู่ในนี้ หน้าแรกคือแท็บที่เลือกอยู่ (อัปเดตตาม _currentIndex)
                Expanded(
                  child: Navigator(
                    key: _contentNav,
                    pages: [
                      MaterialPage(
                        key: const ValueKey('main-tab'),
                        child: _buildBody(),
                      ),
                    ],
                    onDidRemovePage: (_) {},
                  ),
                ),
              ],
            )
          : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabChanged, // Use the new method,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'หน้าหลัก',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'ฝึกอบรม',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'ข่าวสาร',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.contact_mail),
                if (widget.authProvider.isLoggedIn)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'ติดต่อ',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          // key: HomeScreen.homeKey,
          authProvider: widget.authProvider,
        );
      case 1:
        return const TrainingScreen(embedded: true);
      case 2:
        // ยังไม่มีหน้าข่าวสารแยก — ข่าวล่าสุดแสดงอยู่ใน HomeScreen
        return const Center(child: Text('ข่าวสาร'));
      case 3:
        return const ContactScreen(embedded: true);
      default:
        return const Center(child: Text('ไม่พบหน้า'));
    }
  }
}
