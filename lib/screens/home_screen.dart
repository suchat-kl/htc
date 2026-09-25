import 'dart:core';
import 'package:flutter/material.dart';
import 'package:highway_training/models/ticker_message.dart';
import 'package:highway_training/providers/auth_provider.dart';
import 'package:highway_training/services/api_service.dart';
import '../config/theme.dart';
import '../widgets/facebook_page_embed.dart';
import 'booking_edit_screen.dart';
import 'room_rates_screen.dart';
import '../widgets/footer.dart';
import 'package:highway_training/models/home_stats.dart';
import 'package:highway_training/models/notification_item.dart';
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

  /// ประกาศประชาสัมพันธ์ที่ยังอยู่ในช่วงวันที่ ว่างได้ถ้ายังไม่มีใครลง
  List<NotificationItem> _notifications = [];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadTickerMessages();
    _loadStats();
    _loadNotifications();
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

  /// ประกาศประชาสัมพันธ์ โหลดไม่ได้ก็ซ่อนส่วนนี้ไป ไม่ขึ้น error ให้คนนอกเห็น
  Future<void> _loadNotifications() async {
    try {
      final list = await _apiService.getActiveNotifications();
      if (mounted) setState(() => _notifications = list);
    } catch (e) {
      if (AppLogger.on) AppLogger.d('โหลดประกาศหน้าแรกไม่สำเร็จ: $e');
    }
  }

  // Load ticker messages from API
  Future<void> _loadTickerMessages() async {
    try {
      if (AppLogger.on) AppLogger.d('🔄 Loading ticker messages...');
      final messages = await _apiService.getActiveTickerMessages();
      if (AppLogger.on) {
        AppLogger.d('📥 Ticker messages loaded: ${messages.length}');
      }

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
          _buildBookingCta(context, isDesktop),
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
                Icon(
                  Icons.apartment,
                  size: isDesktop ? 52 : 38,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                SizedBox(height: isDesktop ? 14 : 10),
                Text(
                  'ศูนย์พัฒนาทรัพยากรบุคคลงานทาง',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 34 : 24,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isDesktop ? 10 : 8),
                Text(
                  'กรมทางหลวง  อำเภอศรีราชา จังหวัดชลบุรี',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontSize: isDesktop ? 17 : 14,
                    shadows: const [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isDesktop ? 12 : 10),
                Text(
                  'ห้องพัก ห้องประชุม และห้องกิจกรรม สำหรับการฝึกอบรมและสัมมนา',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontSize: isDesktop ? 15 : 13,
                    shadows: const [
                      Shadow(blurRadius: 6, color: Colors.black54),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
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
      onTap: () => setState(() {
        _isTickerPaused = !_isTickerPaused;
        if (!_isTickerPaused) _startTickerAutoScroll();
      }),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondaryColor.withValues(alpha: 0.1),
              AppTheme.secondaryColor.withValues(alpha: 0.2),
              AppTheme.secondaryColor.withValues(alpha: 0.1),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.secondaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 12 : 10,
          horizontal: isDesktop ? 32 : 16,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 12 : 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign,
                    color: Colors.white,
                    size: isDesktop ? 18 : 14,
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  Text(
                    'ประกาศ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 12),
            Expanded(
              child: SizedBox(
                height: isDesktop ? 24 : 20,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_tickerMessages.isNotEmpty &&
                          !_isTickerPaused &&
                          mounted) {
                        _startTickerAutoScroll();
                      }
                    });
                    return SingleChildScrollView(
                      controller: _tickerScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          for (int repeat = 0; repeat < 5; repeat++) ...[
                            for (
                              int i = 0;
                              i < _tickerMessages.length;
                              i++
                            ) ...[
                              Text(
                                _tickerMessages[i],
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  // fontSize: isDesktop ? 20 : 12  //use default
                                  fontSize:
                                      _tickerMessagesData[i].fontSize ??
                                      (isDesktop ? 20 : 12), // ✅ Use fontSize
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Icon(
                                  Icons.fiber_manual_record,
                                  size: 6,
                                  color: AppTheme.secondaryColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
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
                onTap: () => setState(() {
                  _isTickerPaused = !_isTickerPaused;
                  if (!_isTickerPaused) _startTickerAutoScroll();
                }),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isTickerPaused ? Icons.play_arrow : Icons.pause,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
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
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 20,
        isDesktop ? 32 : 24,
        isDesktop ? 32 : 20,
        isDesktop ? 24 : 20,
      ),
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
                fontSize: isDesktop ? 13 : 12,
                color: AppTheme.textSecondary,
              ),
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
            offset: const Offset(0, 3),
          ),
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
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 32 : 24,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  unit,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: isDesktop ? 13 : 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 6 : 4),
          Text(
            label,
            style: TextStyle(fontSize: isDesktop ? 14 : 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===================== การ์ดเมนูจอง =====================

  /// การ์ดเรียกให้ไปจองห้อง วางไว้ตรงกลางหน้าให้เห็นชัดที่สุด
  ///
  /// พาไปหน้าจองตัวเดียวกับเมนู "จอง" ในแถบเมนูด้านข้าง ไม่ได้ทำฟอร์มซ้ำ
  /// จอกว้างวางภาพไว้ซ้าย ข้อความขวา จอแคบวางภาพไว้บนแล้วข้อความอยู่ล่าง
  Widget _buildBookingCta(BuildContext context, bool isDesktop) {
    final image = ClipRRect(
      borderRadius: isDesktop
          ? const BorderRadius.horizontal(left: Radius.circular(18))
          : const BorderRadius.vertical(top: Radius.circular(18)),
      child: SizedBox(
        width: isDesktop ? 340 : double.infinity,
        height: isDesktop ? 220 : 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/meeting.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppTheme.primaryDark),
            ),
            // ไล่สีบาง ๆ ให้ภาพกลืนกับพื้นการ์ด ไม่ตัดกันเป็นสองก้อน
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isDesktop ? Alignment.centerLeft : Alignment.topCenter,
                  end: isDesktop
                      ? Alignment.centerRight
                      : Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.primaryDark.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final text = Padding(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      child: Column(
        crossAxisAlignment: isDesktop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_available,
                  size: isDesktop ? 26 : 22,
                  color: AppTheme.onSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'จองห้องพักและห้องกิจกรรม',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 24 : 19,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 12 : 10),
          Text(
            'กรอกแบบฟอร์มจองออนไลน์ได้ทันที\nเลือกวันที่ ประเภทผู้จอง ห้องพัก และรายการอาหาร',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: isDesktop ? 15 : 13,
              height: 1.5,
            ),
            textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          ElevatedButton.icon(
            onPressed: () => _openBooking(context),
            icon: const Icon(Icons.edit_calendar, size: 20),
            label: const Text('เริ่มจองห้อง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: AppTheme.onSecondaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 22,
                vertical: isDesktop ? 16 : 12,
              ),
              textStyle: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 20,
        0,
        isDesktop ? 32 : 20,
        isDesktop ? 40 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            elevation: 6,
            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openBooking(context),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppTheme.primaryDark, AppTheme.accentColor],
                  ),
                ),
                child: isDesktop
                    ? Row(
                        children: [
                          image,
                          Expanded(child: text),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [image, text],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// เปิดหน้าจอง หน้าเดียวกับเมนู "จอง" ในแถบเมนูด้านข้าง
  void _openBooking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingEditScreen(apiService: _apiService),
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
        horizontal: isDesktop ? 32 : 20,
        vertical: isDesktop ? 40 : 28,
      ),
      child: Column(
        children: [
          Text(
            'ข่าวประชาสัมพันธ์',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: isDesktop ? 24 : 20),
          ),
          SizedBox(height: isDesktop ? 8 : 6),
          Text(
            'ข่าวสารและภาพกิจกรรมจากเพจของศูนย์ฯ',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: isDesktop ? 24 : 18),
          // ประกาศของศูนย์ฯ เองอยู่บนสุด ตามด้วยข่าวจากเพจ Facebook
          // ประกาศเหมาะกับเรื่องที่เป็นทางการและมีวันหมดอายุ
          // ส่วนเพจใช้ลงข่าวและภาพกิจกรรมซึ่งศูนย์ฯ โพสต์อยู่แล้ว
          if (_notifications.isNotEmpty) ...[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    for (final n in _notifications)
                      _buildNotificationCard(n, isDesktop),
                  ],
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 28 : 20),
          ],
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

  /// การ์ดประกาศหนึ่งใบ
  Widget _buildNotificationCard(NotificationItem n, bool isDesktop) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      // ห้ามใส่ borderRadius คู่กับ Border ที่สีไม่เท่ากันทุกด้าน Flutter จะ assert
      // ตอน paint แถบสีเหลืองด้านซ้ายจึงทำเป็นกล่องซ้อนข้างใน ไม่ใช่ขอบของกล่องนี้
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        // ลบความหนาของขอบออก มุมข้างในจึงพอดีกับมุมข้างนอก
        borderRadius: BorderRadius.circular(11),
        // แถบสีต้องสูงเท่าเนื้อหา แต่การ์ดอยู่ในหน้าที่เลื่อนได้ซึ่งความสูงไม่จำกัด
        // ใช้ stretch เฉย ๆ ไม่ได้ ต้องให้ Row รู้ความสูงก่อน
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppTheme.secondaryColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 20 : 16),
                  child: _buildNotificationBody(n, isDesktop),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// เนื้อในการ์ดประกาศ แยกออกมาเพื่อไม่ให้ย่อหน้าลึกจนอ่านยาก
  Widget _buildNotificationBody(NotificationItem n, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.campaign,
              size: isDesktop ? 22 : 20,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                n.title ?? '-',
                style: TextStyle(
                  fontSize: isDesktop ? 17 : 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if ((n.message ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            n.message!,
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        if ((n.periodLabel ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                n.periodLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===================== ห้องพักและห้องกิจกรรม =====================

  Widget _buildRoomSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 20,
        vertical: isDesktop ? 40 : 28,
      ),
      child: Column(
        children: [
          Text(
            'ห้องพักและห้องกิจกรรม',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: isDesktop ? 24 : 20),
          ),
          SizedBox(height: isDesktop ? 8 : 6),
          Text(
            'กดที่การ์ดเพื่อดูราคาห้องทั้งหมด',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: AppTheme.textSecondary,
            ),
          ),
          SizedBox(height: isDesktop ? 28 : 20),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildRoomCard(
                'assets/images/vip.png',
                'ห้องพักวีไอพี',
                'ห้องพักสำหรับผู้บริหารและวิทยากร',
                isDesktop,
              ),
              _buildRoomCard(
                'assets/images/normal.png',
                'ห้องพักมาตรฐาน',
                'ห้องพักสำหรับผู้เข้ารับการอบรม',
                isDesktop,
              ),
              _buildRoomCard(
                'assets/images/meeting.png',
                'ห้องประชุมและห้องกิจกรรม',
                'รองรับการอบรม สัมมนา และกิจกรรมกลุ่ม',
                isDesktop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
    String asset,
    String title,
    String description,
    bool isDesktop,
  ) {
    final width = isDesktop ? 300.0 : 260.0;
    final imageHeight = isDesktop ? 180.0 : 150.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoomRatesScreen()),
        ),
        child: Ink(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
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
                    child: Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'ดูราคาห้อง',
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: isDesktop ? 16 : 14,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
