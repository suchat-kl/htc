import 'dart:core';
import 'package:flutter/material.dart';
import 'package:highway_training/models/ticker_message.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/services/api_service.dart';
import '../config/theme.dart';
import '../widgets/facebook_page_embed.dart';
import '../widgets/footer.dart';
import 'package:highway_training/models/home_stats.dart';
import 'package:highway_training/utils/logger.dart';

class HomeScreen extends StatefulWidget {
  final AuthProvider authProvider;
  // ✅ ADD THIS STATIC KEY
  
  const HomeScreen({super.key, required this.authProvider});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
// Store full TickerMessage objects with fontSize
List<TickerMessage> _tickerMessagesData = [];
  final ScrollController _tickerScrollController = ScrollController();
  bool _isTickerPaused = false;

  List<String> _tickerMessages = [];
  // ignore: unused_field
  bool _isLoadingTicker = true;

  /// ตัวเลขสรุปจากฐานข้อมูลจริง null = ยังโหลดไม่เสร็จหรือโหลดไม่ได้
  HomeStats? _stats;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadTickerMessages();
    _loadStats();
  }

  /// ตัวเลขสรุปบนหน้าแรก โหลดไม่ได้ก็ซ่อนแถบไปเลย ไม่ขึ้น error ให้ผู้ใช้ทั่วไปเห็น
  Future<void> _loadStats() async {
    try {
      final stats = await _apiService.getHomeStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('โหลดสถิติหน้าแรกไม่สำเร็จ: $e');
    }
  }

  // Load ticker messages from API
  Future<void> _loadTickerMessages() async {
    try {
      if (AppLogger.on) AppLogger.d('🔄 Loading ticker messages...');
      final messages = await _apiService.getActiveTickerMessages();
      if (AppLogger.on) AppLogger.d('📥 Ticker messages loaded: ${messages.length}');

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
      if (AppLogger.on) AppLogger.e('❌ Error loading ticker messages: $e');
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
          _buildStatsSection(context, isDesktop),
          _buildNewsSection(context, isDesktop),
          _buildRoomSection(context, isDesktop),
          const CustomFooter(),
        ],
      ),
    );
  }

  // Banner Section
  /// แถบภาพหัวหน้าแรก ใช้ภาพวิวหน้าศูนย์ฯ ภาพเดียวกับระบบเดิม
  ///
  /// ภาพคัดลอกมาเก็บใน assets ไม่ได้ลิงก์ไปที่เซิร์ฟเวอร์ระบบเดิม
  /// ถ้าลิงก์ไว้ วันที่ระบบเดิมถูกปิด หน้าแรกจะกลายเป็นช่องว่างทันที
  ///
  /// มีชั้นไล่สีทับภาพเพื่อให้ตัวหนังสือสีขาวอ่านออกทุกส่วนของภาพ
  Widget _buildBannerSection(BuildContext context, bool isDesktop) {
    final height = isDesktop ? 460.0 : 320.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/view.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            // ภาพหายก็ยังเห็นหัวเรื่อง ไม่ปล่อยให้ทั้งแถบพัง
            errorBuilder: (_, _, _) => Container(color: AppTheme.primaryColor),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment,
                    size: isDesktop ? 52 : 38,
                    color: Colors.white.withValues(alpha: 0.9)),
                SizedBox(height: isDesktop ? 14 : 10),
                Text('ศูนย์พัฒนาทรัพยากรบุคคลงานทาง',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 34 : 24,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                    textAlign: TextAlign.center),
                SizedBox(height: isDesktop ? 10 : 8),
                Text('กรมทางหลวง  อำเภอศรีราชา จังหวัดชลบุรี',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontSize: isDesktop ? 17 : 14,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                    textAlign: TextAlign.center),
                SizedBox(height: isDesktop ? 12 : 10),
                Text('ห้องพัก ห้องประชุม และห้องกิจกรรม สำหรับการฝึกอบรมและสัมมนา',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontSize: isDesktop ? 15 : 13,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
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

  // ===================== สถิติจากข้อมูลจริง =====================

  /// แถบตัวเลขสรุป ซ่อนทั้งแถบถ้าโหลดไม่ได้ ดีกว่าโชว์เลขศูนย์ลอย ๆ ให้เข้าใจผิด
  Widget _buildStatsSection(BuildContext context, bool isDesktop) {
    final st = _stats;
    if (st == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 20, isDesktop ? 32 : 24,
          isDesktop ? 32 : 20, isDesktop ? 24 : 20),
      child: Column(
        children: [
          Wrap(
            spacing: isDesktop ? 24 : 16,
            runSpacing: isDesktop ? 24 : 16,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard(
                icon: Icons.hotel,
                value: st.lodgingFree.toString(),
                unit: 'จาก ${st.lodgingTotal} ห้อง',
                label: 'ห้องพักว่างวันนี้',
                color: AppTheme.primaryColor,
                isDesktop: isDesktop,
              ),
              _buildStatCard(
                icon: Icons.meeting_room,
                value: st.activityFree.toString(),
                unit: 'จาก ${st.activityTotal} ห้อง',
                label: 'ห้องกิจกรรมว่างวันนี้',
                color: AppTheme.accentColor,
                isDesktop: isDesktop,
              ),
              _buildStatCard(
                icon: Icons.event_available,
                value: st.bookingsThisMonth.toString(),
                unit: 'ใบจอง',
                label: st.monthLabel.isEmpty
                    ? 'การจองเดือนนี้'
                    : 'การจองเดือน${st.monthLabel}',
                color: AppTheme.secondaryColor,
                isDesktop: isDesktop,
              ),
            ],
          ),
          if (st.asOfDate.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ข้อมูล ณ วันที่ ${st.asOfDate}',
              style: TextStyle(
                  fontSize: isDesktop ? 13 : 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    required bool isDesktop,
  }) {
    return Container(
      width: isDesktop ? 240 : 150,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: isDesktop ? 34 : 26, color: color),
          SizedBox(height: isDesktop ? 12 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 32 : 24)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(unit,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isDesktop ? 13 : 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 6 : 4),
          Text(label,
              style: TextStyle(fontSize: isDesktop ? 14 : 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ===================== ข่าวประชาสัมพันธ์ =====================

  /// ดึงจากเพจ Facebook ของศูนย์ฯ เพราะระบบไม่มีตารางข่าวของตัวเอง
  /// และศูนย์ฯ ประกาศข่าวที่เพจอยู่แล้ว จะได้ไม่ต้องลงข่าวสองที่
  Widget _buildNewsSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 20, vertical: isDesktop ? 40 : 28),
      child: Column(
        children: [
          Text('ข่าวประชาสัมพันธ์',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: isDesktop ? 24 : 20)),
          SizedBox(height: isDesktop ? 8 : 6),
          Text('ข่าวสารและภาพกิจกรรมจากเพจของศูนย์ฯ',
              style: TextStyle(
                  fontSize: isDesktop ? 14 : 12, color: AppTheme.textSecondary)),
          SizedBox(height: isDesktop ? 24 : 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FacebookPageEmbed(height: isDesktop ? 460 : 380),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== ห้องพักและห้องกิจกรรม =====================

  Widget _buildRoomSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 20, vertical: isDesktop ? 40 : 28),
      child: Column(
        children: [
          Text('ห้องพักและห้องกิจกรรม',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: isDesktop ? 24 : 20)),
          SizedBox(height: isDesktop ? 8 : 6),
          Text('ดูรายละเอียดและราคาได้ที่เมนู เกี่ยวกับเรา',
              style: TextStyle(
                  fontSize: isDesktop ? 14 : 12, color: AppTheme.textSecondary)),
          SizedBox(height: isDesktop ? 28 : 20),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildRoomCard('assets/images/vip.png', 'ห้องพักวีไอพี',
                  'ห้องพักสำหรับผู้บริหารและวิทยากร', isDesktop),
              _buildRoomCard('assets/images/normal.png', 'ห้องพักมาตรฐาน',
                  'ห้องพักสำหรับผู้เข้ารับการอบรม', isDesktop),
              _buildRoomCard(
                  'assets/images/meeting.png',
                  'ห้องประชุมและห้องกิจกรรม',
                  'รองรับการอบรม สัมมนา และกิจกรรมกลุ่ม',
                  isDesktop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
      String asset, String title, String description, bool isDesktop) {
    final width = isDesktop ? 300.0 : 260.0;
    final imageHeight = isDesktop ? 180.0 : 150.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Image.asset(
              asset,
              width: width,
              height: imageHeight,
              fit: BoxFit.cover,
              // ภาพหายก็ยังแสดงการ์ดได้ ไม่ให้ทั้งหน้าพัง
              errorBuilder: (_, _, _) => Container(
                width: width,
                height: imageHeight,
                color: AppTheme.primaryPale,
                child: Icon(Icons.image_outlined,
                    size: 40,
                    color: AppTheme.primaryColor.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 16 : 14)),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
