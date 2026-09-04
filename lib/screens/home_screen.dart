import 'dart:core';
import 'package:flutter/material.dart';
import 'package:highway_training/models/ticker_message.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/services/api_service.dart';
import '../config/theme.dart';
import '../widgets/news_card.dart';
import '../widgets/footer.dart';
import 'package:highway_training/utils/logger.dart';

class HomeScreen extends StatefulWidget {
  final AuthProvider authProvider;
  // ✅ ADD THIS STATIC KEY
  
  const HomeScreen({super.key, required this.authProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
// Store full TickerMessage objects with fontSize
List<TickerMessage> _tickerMessagesData = [];
  final ScrollController _tickerScrollController = ScrollController();
  bool _isTickerPaused = false;

  List<String> _tickerMessages = [];
  // ignore: unused_field
  bool _isLoadingTicker = true;

  final List<Map<String, dynamic>> _bannerData = [
    {
      'title': 'ยินดีต้อนรับสู่ระบบศูนย์พัฒนาทรัพยากรบุคคลงานทาง',
      'subtitle': 'พัฒนาบุคลากรด้วยหลักสูตรมาตรฐาน เพื่อการพัฒนาโครงสร้างพื้นฐานของประเทศ',
      'color': AppTheme.primaryColor,
    },
    {
      'title': 'หลักสูตรฝึกอบรมออนไลน์',
      'subtitle': 'เรียนรู้ได้ทุกที่ทุกเวลา ด้วยระบบ E-Learning ที่ทันสมัย',
      'color': AppTheme.accentColor,
    },
    {
      'title': 'ลงทะเบียนอบรมวันนี้',
      'subtitle': 'รับสิทธิพิเศษสำหรับผู้ลงทะเบียนล่วงหน้า',
      'color': AppTheme.secondaryColor,
    },
  ];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
    _loadTickerMessages();
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(seconds: 100), () {
      if (mounted) {
        if (_currentPage < _bannerData.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      }
    });
  }

  // Load ticker messages from API
  Future<void> _loadTickerMessages() async {
    try {
      AppLogger.d('🔄 Loading ticker messages...');
      final messages = await _apiService.getActiveTickerMessages();
      AppLogger.d('📥 Ticker messages loaded: ${messages.length}');

      if (mounted) {
        setState(() {
          if (messages.isNotEmpty) {
            // Store full TickerMessage objects instead of just strings
            _tickerMessagesData = messages
                .where((m) => m.message.isNotEmpty)
                .toList();

            // For backward compatibility
            _tickerMessages = _tickerMessagesData
                .map((m) => m.displayText)
                .toList();
          } else {
            _tickerMessagesData = [];
            _tickerMessages = [];
          }
          _isLoadingTicker = false;
        });

        if (_tickerMessages.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _startTickerAutoScroll();
            }
          });
        }
      }
    } catch (e) {
      AppLogger.e('❌ Error loading ticker messages: $e');
      if (mounted) {
        setState(() {
          _tickerMessagesData = [];
          _tickerMessages = [];
          _isLoadingTicker = false;
        });
      }
    }
  }

  // Auto scroll - SIMPLE & RELIABLE
  void _startTickerAutoScroll() {
    if (!mounted || _isTickerPaused || _tickerMessages.isEmpty) return;
    if (!_tickerScrollController.hasClients) return;

    final position = _tickerScrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    if (maxScroll <= 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _startTickerAutoScroll();
      });
      return;
    }

    if (currentScroll >= maxScroll - 2) {
      _tickerScrollController.jumpTo(0);
    } else {
      _tickerScrollController.jumpTo(currentScroll + 1);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _startTickerAutoScroll();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tickerScrollController.dispose();
    super.dispose();
  }

  Future<void> refreshTickerMessages() async {
    await _loadTickerMessages();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTickerBar(context, isDesktop),
          _buildBannerSection(context, isDesktop),
          Padding(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Wrap(
              spacing: isDesktop ? 24 : 16,
              runSpacing: isDesktop ? 24 : 16,
              alignment: WrapAlignment.center,
              children: [
                _buildStatCard(icon: Icons.people, value: '15,000+', label: 'ผู้เข้ารับการอบรม', color: AppTheme.primaryColor, isDesktop: isDesktop),
                _buildStatCard(icon: Icons.menu_book, value: '50+', label: 'หลักสูตรฝึกอบรม', color: AppTheme.accentColor, isDesktop: isDesktop),
                _buildStatCard(icon: Icons.calendar_today, value: '200+', label: 'รอบการอบรมต่อปี', color: AppTheme.secondaryColor, isDesktop: isDesktop),
                _buildStatCard(icon: Icons.star, value: '98%', label: 'ความพึงพอใจ', color: Colors.orange, isDesktop: isDesktop),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
            child: Row(
              children: [
                Text('ข่าวสารล่าสุด', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: isDesktop ? 24 : 20)),
                const Spacer(),
                TextButton(onPressed: () {}, child: Text('ดูทั้งหมด', style: TextStyle(fontSize: isDesktop ? 16 : 14))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: isDesktop ? 320 : 280,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
              children: [
                NewsCard(title: 'เปิดรับสมัครฝึกอบรมหลักสูตรใหม่', date: '15 มิ.ย. 2567', description: 'หลักสูตรการบริหารจัดการโครงการทางหลวง...', imageUrl: 'assets/images/news1.jpg', onTap: () {}, isDesktop: isDesktop),
                NewsCard(title: 'สรุปผลการอบรมประจำปี 2567', date: '10 มิ.ย. 2567', description: 'ภาพรวมความสำเร็จในการพัฒนาบุคลากร...', imageUrl: 'assets/images/news2.jpg', onTap: () {}, isDesktop: isDesktop),
                NewsCard(title: 'การพัฒนาหลักสูตรออนไลน์', date: '5 มิ.ย. 2567', description: 'ระบบ E-Learning สำหรับบุคลากรทางหลวง...', imageUrl: 'assets/images/news3.jpg', onTap: () {}, isDesktop: isDesktop),
                NewsCard(title: 'สัมมนาวิชาการด้านความปลอดภัย', date: '1 มิ.ย. 2567', description: 'งานสัมมนาประจำปีด้านความปลอดภัยบนทางหลวง...', imageUrl: 'assets/images/news1.jpg', onTap: () {}, isDesktop: isDesktop),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            color: AppTheme.backgroundColor,
            child: Column(
              children: [
                Text('หลักสูตรฝึกอบรมยอดนิยม', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: isDesktop ? 24 : 20)),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 24, runSpacing: 24, alignment: WrapAlignment.center,
                  children: [
                    _buildTrainingCard('ความปลอดภัยในการทำงานบนทางหลวง', 'เรียนรู้มาตรฐานความปลอดภัยและการจัดการความเสี่ยง', Icons.security, isDesktop: isDesktop),
                    _buildTrainingCard('เทคโนโลยีก่อสร้างทางหลวงสมัยใหม่', 'นวัตกรรมและเทคโนโลยีในการก่อสร้างทางหลวง', Icons.engineering, isDesktop: isDesktop),
                    _buildTrainingCard('การบริหารจัดการงบประมาณโครงการ', 'การวางแผนและควบคุมงบประมาณอย่างมีประสิทธิภาพ', Icons.account_balance_wallet, isDesktop: isDesktop),
                  ],
                ),
              ],
            ),
          ),
          const CustomFooter(),
        ],
      ),
    );
  }

  // Banner Section
  Widget _buildBannerSection(BuildContext context, bool isDesktop) {
    return Stack(
      children: [
        SizedBox(
          height: isDesktop ? 500 : 350,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _bannerData.length,
            itemBuilder: (context, index) => Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                  colors: [
                    _bannerData[index]['color'] as Color,
                    (_bannerData[index]['color'] as Color).withValues(alpha: 0.7),
                    AppTheme.accentColor.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: isDesktop ? 60 : 40, color: Colors.white.withValues(alpha: 0.8)),
                      SizedBox(height: isDesktop ? 16 : 12),
                      Text('ยินดีต้อนรับสู่ระบบศูนย์พัฒนาทรัพยากรบุคคลงานทาง', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isDesktop ? 32 : 24), textAlign: TextAlign.center),
                      SizedBox(height: isDesktop ? 12 : 8),
                      Text('พัฒนาบุคลากรด้วยหลักสูตรมาตรฐาน\nเพื่อการพัฒนาโครงสร้างพื้นฐานของประเทศ', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70, fontSize: isDesktop ? 16 : 14), textAlign: TextAlign.center),
                      SizedBox(height: isDesktop ? 20 : 16),
                      isDesktop
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.school), label: const Text('ดูหลักสูตรทั้งหมด'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16))),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add), label: const Text('ลงทะเบียนอบรม'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16))),
                            ])
                          : Column(children: [
                              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.school, size: 20), label: const Text('ดูหลักสูตรทั้งหมด'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, padding: const EdgeInsets.symmetric(vertical: 12)))),
                              const SizedBox(height: 8),
                              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add, size: 20), label: const Text('ลงทะเบียนอบรม'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(vertical: 12)))),
                            ]),
                    ],
                  ),
                ),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_bannerData.length, (index) => Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.5))))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Ticker Bar
  Widget _buildTickerBar(BuildContext context, bool isDesktop) {
    if (_tickerMessages.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() { _isTickerPaused = !_isTickerPaused; if (!_isTickerPaused) _startTickerAutoScroll(); }),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.secondaryColor.withValues(alpha: 0.1), AppTheme.secondaryColor.withValues(alpha: 0.2), AppTheme.secondaryColor.withValues(alpha: 0.1)]),
          border: Border(bottom: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.3), width: 1)),
        ),
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 10, horizontal: isDesktop ? 32 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.secondaryColor, borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.campaign, color: Colors.white, size: isDesktop ? 18 : 14),
                SizedBox(width: isDesktop ? 6 : 4),
                Text('ประกาศ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isDesktop ? 14 : 12)),
              ]),
            ),
            SizedBox(width: isDesktop ? 16 : 12),
            Expanded(
              child: SizedBox(
                height: isDesktop ? 24 : 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_tickerMessages.isNotEmpty && !_isTickerPaused && mounted) _startTickerAutoScroll();
                    });
                    return SingleChildScrollView(
                      controller: _tickerScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          for (int repeat = 0; repeat < 5; repeat++) ...[
                            for (int i = 0; i < _tickerMessages.length; i++) ...[
                              Text(_tickerMessages[i], style: TextStyle(color: AppTheme.textPrimary, 
                              // fontSize: isDesktop ? 20 : 12  //use default
                              fontSize: _tickerMessagesData[i].fontSize ?? (isDesktop ? 20 : 12),  // ✅ Use fontSize
                              )),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Icon(Icons.fiber_manual_record, size: 6, color: AppTheme.secondaryColor.withValues(alpha: 0.5))),
                            ],
                          ],
                          SizedBox(width: constraints.maxWidth * 2),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: () => setState(() { _isTickerPaused = !_isTickerPaused; if (!_isTickerPaused) _startTickerAutoScroll(); }),
                borderRadius: BorderRadius.circular(20),
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Icon(_isTickerPaused ? Icons.play_arrow : Icons.pause, size: 20, color: AppTheme.primaryColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String value, required String label, required Color color, required bool isDesktop}) {
    return Container(
      width: isDesktop ? 220 : 160, padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [
        Icon(icon, size: isDesktop ? 40 : 32, color: color),
        SizedBox(height: isDesktop ? 12 : 8),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold, fontSize: isDesktop ? 28 : 22)),
        SizedBox(height: isDesktop ? 8 : 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isDesktop ? 14 : 12), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildTrainingCard(String title, String description, IconData icon, {required bool isDesktop}) {
    return Container(
      width: isDesktop ? 300 : 280, padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: AppTheme.primaryColor, size: isDesktop ? 32 : 28)),
        SizedBox(height: isDesktop ? 16 : 12),
        Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: isDesktop ? 16 : 14)),
        SizedBox(height: isDesktop ? 8 : 6),
        Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isDesktop ? 14 : 12)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {}, child: Text('รายละเอียด', style: TextStyle(fontSize: isDesktop ? 14 : 12)))),
      ]),
    );
  }
}