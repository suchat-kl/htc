import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highway_training/screens/home_screen.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:highway_training/widgets/header.dart';
import 'package:highway_training/widgets/sidebar_menu.dart';
import 'package:highway_training/providers/auth_provider.dart';
// import 'package:intl/date_symbol_data_file.dart';
// import 'package:intl/intl.dart';
import 'config/theme.dart';
// import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
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
    widget.authProvider.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
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
  void _onTabChanged(int index) {
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
    return Scaffold(
      appBar: CustomHeader(authProvider: widget.authProvider),
      drawer: SidebarMenu(
        authProvider: widget.authProvider,
        // onTickerSaved: () {
        //   debugPrint('📢 onTickerSaved callback!');
        //   // Switch to home tab and refresh
        //   _onTabChanged(0);
        // },
      ),

      body: _buildBody(),
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
        return const Center(child: Text('หลักสูตรฝึกอบรม'));
      case 2:
        return const Center(child: Text('ข่าวสาร'));
      case 3:
        return const Center(child: Text('ติดต่อเรา'));
      default:
        return const Center(child: Text('ไม่พบหน้า'));
    }
  }
}
