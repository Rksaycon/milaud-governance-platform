// ignore_for_file: unused_element, unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
// 7-day rain forecast (Open-Meteo) via the shared rain forecast provider —
// single data layer for both the Flood Alert and Rain Forecast screens.
import '../../../providers/rain_forecast_provider.dart';
import '../../../features/rain_forecast/models/weather_data_models.dart';
import '../../../features/rain_forecast/risk/rain_risk_classifier.dart';
import '../rain_forecast/rain_forecast_screen.dart';

// ─── BRAND PALETTE — delegates to AppColors (single source of truth) ───
class FloodColors {
  static Color get heritagePurple => AppColors.heritagePurple;
  static Color get riverFlow => AppColors.riverFlow;
  static Color get deepAnchor => AppColors.deepAnchor;
  static const Color warmHearth = AppColors.warmHearth;
  static const Color cardWhite = AppColors.cardWhite;

  // Flood severity — matches api.py's flood_risk levels: Low/Moderate/High/Severe
  static const Color safe = Color(0xFF22C55E);
  static const Color alert = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color severe = Color(0xFF991B1B);
  static const Color safeBg = Color(0xFFF0FDF4);
  static const Color alertBg = Color(0xFFFFFBEB);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color severeBg = Color(0xFFFEE2E2);

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heritagePurple, deepAnchor],
      );

  static const LinearGradient safeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
  );
}

class FloodAlertScreen extends ConsumerStatefulWidget {
  const FloodAlertScreen({super.key});

  @override
  ConsumerState<FloodAlertScreen> createState() => _FloodAlertScreenState();
}

class _FloodAlertScreenState extends ConsumerState<FloodAlertScreen> {
  bool _isDark = false;
  ColorScheme? _cs;

  AppColorScheme get _colors => AppColors.of(context);
  Color get _scaffoldBg =>
      _isDark ? AppColors.dark.background : AppColors.warmHearth;
  Color get _cardBg =>
      _isDark ? AppColors.dark.cardSurface : AppColors.cardWhite;
  Color get _titleText => _colors.textPrimary;
  Color get _bodyText => _colors.textSecondary;
  Color get _mutedText => _colors.textMuted;

  final RefreshController _refreshController = RefreshController();

  // NOTE — _alerts and _safetyTips below are still placeholder/mock
  // data. Nothing in api.py provides per-station river-monitoring
  // readings, so there's no real backend to wire these to yet.
  late List<Map<String, dynamic>> _alerts;
  late List<Map<String, dynamic>> _safetyTips;
  int _expandedTipIndex = -1;

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  /// Sums hourly precipitation (mm) for forecast intervals within the next
  /// 12 hours from now. Returns null when there are no usable hourly records.
  double? _next12hRainfall(List<WeatherHour> hourly) {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(hours: 12));
    double sum = 0.0;
    var count = 0;
    for (final h in hourly) {
      final t = DateTime.tryParse(h.time);
      if (t == null) continue;
      if (t.isAfter(now) && t.isBefore(cutoff)) {
        sum += (h.precipitationMm ?? h.rainMm ?? h.showersMm ?? 0.0);
        count += 1;
      }
    }
    return count > 0 ? sum : null;
  }

  /// Risk classification label for the 7-day daily outlook, or null when no
  /// daily data is available.
  String? _riskLabel(WeatherForecastData? data) {
    if (data == null || data.daily.isEmpty) return null;
    final rule = RainRiskClassifier.classifyRainOutlook(
      daily: data.daily,
      location: data.location,
    );
    return rule.label;
  }

  /// Recommended action text derived from the forecast risk label — never
  /// presented as an official PAGASA warning.
  String _recommendedAction(String? label) {
    if (label == null) return 'Unable to assess rain outlook right now.';
    final l = label.toLowerCase();
    if (l.contains('severe')) {
      return 'Heavy rainfall expected over several days; elevated runoff and flash-flood potential. Follow official alerts.';
    }
    if (l.contains('high')) {
      return 'Heavy rainfall expected; elevated runoff and flash-flood potential. Monitor official advisories.';
    }
    if (l.contains('moderate')) {
      return 'Moderate rainfall expected; watch low-lying areas and small streams.';
    }
    if (l.contains('light') || l.contains('low') || l.contains('isolated')) {
      return 'Light rain possible on a few days; not expected to cause runoff issues.';
    }
    if (l.contains('unavailable') || l.contains('no measurable')) {
      return 'No measurable rain expected in the next 7 days.';
    }
    return 'Monitor official weather updates.';
  }

  void _initMockData() {
    _alerts = [
      {
        'title': 'Bicol River Monitoring',
        'level': 'Normal',
        'color': FloodColors.safe,
        'bgColor': FloodColors.safeBg,
        'icon': Icons.waves_rounded,
        'updated': '30 minutes ago',
        'station': 'Station 1 - Poblacion',
      },
      {
        'title': 'Milaor Creek',
        'level': 'Normal',
        'color': FloodColors.safe,
        'bgColor': FloodColors.safeBg,
        'icon': Icons.water_drop_rounded,
        'updated': '1 hour ago',
        'station': 'Station 2 - San Roque',
      },
      {
        'title': 'San Francisco River',
        'level': 'Alert',
        'color': FloodColors.alert,
        'bgColor': FloodColors.alertBg,
        'icon': Icons.warning_rounded,
        'updated': '2 hours ago',
        'station': 'Station 3 - Capucnasan',
      },
    ];

    _safetyTips = [
      {
        'title': 'During Flood Warnings',
        'icon': Icons.shield_rounded,
        'tips': [
          'Move to higher ground immediately.',
          'Avoid walking or driving through flood waters.',
          'Stay tuned to local news for updates.',
          'Prepare emergency kit with food, water, and medicines.',
        ],
      },
      {
        'title': 'Emergency Contacts',
        'icon': Icons.contact_phone_rounded,
        'tips': [
          'MDRRMO: (054) 123-4567',
          'Emergency Hotline: 911',
          'Barangay Hall: (054) 123-4568',
          'Rescue Team: 0912-345-6789',
        ],
      },
      {
        'title': 'Evacuation Routes',
        'icon': Icons.map_rounded,
        'tips': [
          'Milaor Central School - Primary evacuation center',
          'Barangay San Roque Covered Court',
          'Milaor Municipal Hall - Command center',
          'Follow designated routes posted in your barangay.',
        ],
      },
    ];
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    await ref.read(rainForecastProvider.notifier).refresh();
    if (mounted) _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _cs = Theme.of(context).colorScheme;

    final state = ref.watch(rainForecastProvider);
    final data = state.data;

    final next12hRain = _next12hRainfall(data?.hourly ?? const []);
    final riskLabel = _riskLabel(data);
    final evacuationAdvisory = riskLabel != null &&
        (riskLabel.toLowerCase().contains('severe') ||
            riskLabel.toLowerCase().contains('high'));
    final checkedAt = state.lastUpdated;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        header: WaterDropMaterialHeader(
          backgroundColor: FloodColors.heritagePurple,
          color: AppColors.neutralWhite,
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 40.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeroStatusCard(),
                  SizedBox(height: 24.h),
                  _buildQuickStatsRow(),
                  SizedBox(height: 24.h),
                  _buildRainForecastSection(),
                  SizedBox(height: 24.h),
                  _buildForecastSection(),
                  SizedBox(height: 24.h),
                  _buildSectionHeader(
                      'Safety Information', Icons.info_outline_rounded),
                  SizedBox(height: 12.h),
                  ..._safetyTips
                      .asMap()
                      .entries
                      .map((e) => _buildSafetyAccordion(e.value, e.key)),
                  SizedBox(height: 24.h),
                  _buildEmergencyActions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SLIVER APP BAR ────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140.h,
      pinned: true,
      elevation: 0,
      backgroundColor: FloodColors.heritagePurple,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: FloodColors.headerGradient),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FLOOD MONITORING',
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutralWhite
                                    .withValues(alpha: 0.54),
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              'Milaor Alert System',
                              style: GoogleFonts.poppins(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutralWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // _buildRefreshButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Maps api.py's flood_risk levels onto this screen's color language.
  Color _riskColor(String risk) => switch (risk.toLowerCase()) {
        'low' => FloodColors.safe,
        'moderate' => FloodColors.alert,
        'high' => FloodColors.danger,
        'severe' => FloodColors.severe,
        _ => FloodColors.heritagePurple,
      };

  IconData _riskIcon(String risk) => switch (risk.toLowerCase()) {
        'low' => Icons.check_circle_rounded,
        'moderate' => Icons.warning_amber_rounded,
        'high' => Icons.dangerous_rounded,
        'severe' => Icons.report_rounded,
        _ => Icons.info_rounded,
      };

  // ─── HERO STATUS CARD ──────────────────────────────────
  // FIX — used to show a fabricated "river level in meters vs a danger
  // threshold" gauge with no real data behind it at all. Now driven by
  // your weather API's live rain-risk snapshot (see _fetchRainRisk()) —
  // shows a loading/unavailable state honestly instead of a fake number
  // when that hasn't succeeded yet.
  Widget _buildHeroStatusCard() {
    final status = ref.read(rainForecastProvider).status;
    final hasData = ref.read(rainForecastProvider).hasData;

    if ((status == RainForecastStatus.initial ||
            status == RainForecastStatus.loading) &&
        !hasData) {
      return _buildHeroPlaceholder(
        icon: Icons.cloud_sync_rounded,
        message: 'Checking live rain forecast…',
        showSpinner: true,
      );
    }

    // Offline with no cached data at all.
    if (status == RainForecastStatus.offline && !hasData) {
      return _buildHeroPlaceholder(
        icon: Icons.cloud_off_rounded,
        message: 'No internet connection and no cached forecast.\n'
            'Please check your connection or monitor official PAGASA advisories.',
        showSpinner: false,
      );
    }

    // Error with no cached data.
    if (status == RainForecastStatus.error && !hasData) {
      final msg =
          ref.read(rainForecastProvider).message ?? 'Unable to load forecast.';
      return _buildHeroPlaceholder(
        icon: Icons.error_outline_rounded,
        message: msg,
        showSpinner: false,
      );
    }

    final data = ref.read(rainForecastProvider).data;
    if (data == null) {
      return _buildHeroPlaceholder(
        icon: Icons.cloud_off_rounded,
        message: 'Live rain forecast unavailable right now.\n'
            'Please monitor official PAGASA weather advisories.',
        showSpinner: false,
      );
    }

    final next12hRain = _next12hRainfall(data.hourly);
    final riskLabel = _riskLabel(data);
    final statusText = riskLabel ?? 'Unavailable';
    final percentage = ((next12hRain ?? 0.0) / 50).clamp(0.0, 1.0);
    final statusColor = _riskColor(statusText);
    final glowColor = statusColor.withValues(alpha: 0.3);
    final statusIcon = _riskIcon(statusText);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: FloodColors.heritagePurple.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Status Badge & Title ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Status',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: _bodyText,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 28.h),
          // ─── Circular Gauge ───
          SizedBox(
            width: 170.w,
            height: 170.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170.w,
                  height: 170.w,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 12.w,
                    backgroundColor: AppColors.neutralGray200,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(next12hRain ?? 0.0).toStringAsFixed(0)}mm',
                      style: GoogleFonts.poppins(
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w800,
                        color: _titleText,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'expected, next 12h (forecast)',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: _mutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          // ─── Status Text — the API's own recommended_action, not a
          // canned message, so it actually reflects this situation ───
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 5.h),
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: glowColor, blurRadius: 8, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _recommendedAction(statusText),
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildHeroPlaceholder({
    required IconData icon,
    required String message,
    required bool showSpinner,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: FloodColors.heritagePurple.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (showSpinner)
            SizedBox(
              width: 32.w,
              height: 32.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(FloodColors.heritagePurple),
              ),
            )
          else
            Icon(icon, size: 40.sp, color: _mutedText),
          SizedBox(height: 16.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13.sp, color: _mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── QUICK STATS ROW ───────────────────────────────────
  Widget _buildQuickStatsRow() {
    final data = ref.read(rainForecastProvider).data;
    final next12hRain = _next12hRainfall(data?.hourly ?? const []);
    final riskLabel = _riskLabel(data);
    final evacuationAdvisory = riskLabel != null &&
        (riskLabel.toLowerCase().contains('severe') ||
            riskLabel.toLowerCase().contains('high'));
    final checkedAt = ref.read(rainForecastProvider).lastUpdated;
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
          icon: evacuationAdvisory
              ? Icons.directions_run_rounded
              : Icons.home_rounded,
          label: 'Advisory',
          value: data == null
              ? '—'
              : (evacuationAdvisory ? 'EVACUATE' : 'STAY PUT'),
          color:
              evacuationAdvisory ? FloodColors.danger : FloodColors.riverFlow,
        )),
        SizedBox(width: 12.w),
        Expanded(
            child: _buildStatCard(
          icon: Icons.access_time_rounded,
          label: 'Checked',
          value: checkedAt == null ? '—' : _formatTime(checkedAt),
          color: FloodColors.heritagePurple,
        )),
        SizedBox(width: 12.w),
        Expanded(
            child: _buildStatCard(
          icon: Icons.water_drop_rounded,
          label: 'Rainfall (12h)',
          value:
              next12hRain == null ? '—' : '${next12hRain.toStringAsFixed(0)}mm',
          color: const Color(0xFF0EA5E9),
        )),
      ],
    );
  }

  // ─── RAIN FORECAST SECTION ─────────────────────────────────
  // Data-driven section powered by the shared rain forecast provider.
  // Shows forecast precipitation (not physical rain-gauge measurements)
  // with an honest fallback when data is unavailable.
  Widget _buildRainForecastSection() {
    final state = ref.watch(rainForecastProvider);
    final data = state.data;
    final status = state.status;
    final hasData = state.hasData;

    // Loading with no data yet.
    if ((status == RainForecastStatus.initial ||
            status == RainForecastStatus.loading) &&
        !hasData) {
      return _buildRainForecastPlaceholder(
        message: 'Loading rain forecast…',
        showSpinner: true,
      );
    }

    // Offline with cached data — show it but mark as offline.
    if (status == RainForecastStatus.offline && hasData && data != null) {
      return _buildRainForecastContent(data, offline: true);
    }

    // Offline with no data.
    if (status == RainForecastStatus.offline && !hasData) {
      return _buildRainForecastPlaceholder(
        message: 'No internet connection and no cached forecast.\n'
            'Please check your connection or monitor official PAGASA weather advisories.',
        showSpinner: false,
      );
    }

    // Error with no data.
    if (status == RainForecastStatus.error && !hasData) {
      return _buildRainForecastPlaceholder(
        message: state.message ??
            'Unable to load forecast.\n'
                'Please monitor official PAGASA weather advisories.',
        showSpinner: false,
      );
    }

    // No data at all.
    if (data == null) {
      return _buildRainForecastPlaceholder(
        message: 'Live rain forecast unavailable right now.\n'
            'Please monitor official PAGASA weather advisories.',
        showSpinner: false,
      );
    }

    return _buildRainForecastContent(data, offline: false);
  }

  Widget _buildRainForecastPlaceholder({
    required String message,
    required bool showSpinner,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RainForecastScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE9E1F5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloudy_snowing,
                  color: Color(0xFF643EB5),
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rain Forecast',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24005B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EBFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Forecast',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF643EB5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Monitor rainfall conditions to help you prepare for possible flooding.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF6B6575),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (showSpinner)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF643EB5)),
                      ),
                    )
                  else
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF643EB5),
                      size: 22,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF4C229C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRainForecastContent(WeatherForecastData data,
      {required bool offline}) {
    final next12hRain = _next12hRainfall(data.hourly);
    final riskLabel = _riskLabel(data);
    final lastUpdated = ref.read(rainForecastProvider).lastUpdated;
    final updatedText = lastUpdated == null
        ? 'Updating...'
        : 'Updated ${DateFormat('MMM d, h:mm a').format(lastUpdated)}';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RainForecastScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE9E1F5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloudy_snowing,
                  color: Color(0xFF643EB5),
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rain Forecast',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24005B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EBFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    offline ? 'Offline' : 'Forecast',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF643EB5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Monitor rainfall conditions to help you prepare for possible flooding.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF6B6575),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Next 12h rainfall (forecast)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4C229C),
                          ),
                        ),
                      ),
                      Text(
                        next12hRain == null
                            ? '—'
                            : '${next12hRain.toStringAsFixed(1)} mm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C229C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Rainfall outlook',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4C229C),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          riskLabel ?? 'Unavailable',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _riskColor(riskLabel ?? 'low'),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Last updated',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4C229C),
                          ),
                        ),
                      ),
                      Text(
                        updatedText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4C229C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (offline) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Showing cached data — connection unavailable.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF4C229C),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Values are Open-Meteo forecast model estimates for the area — '
                    'not physical rain-gauge measurements. Monitor official PAGASA advisories.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF4C229C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralBlack.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: _titleText,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FORECAST SECTION ──────────────────────────────────
  // FIX — used to render a fabricated hourly river-level bar chart
  // (Now/3h/6h/12h/24h) with invented numbers behind every point.
  // api.py's /weather/rain-risk gives one current snapshot, not an
  // hourly timeline, so this is now a "Live Rain Risk Assessment" panel
  // showing the real fields that snapshot actually has — an evacuation
  // badge when relevant, and the backend's own disclaimer note — instead
  // of pretending to have forecast granularity that doesn't exist.
  Widget _buildForecastSection() {
    final data = ref.read(rainForecastProvider).data;
    if (data == null) return const SizedBox.shrink();

    final next12hRain = _next12hRainfall(data.hourly);
    final riskLabel = _riskLabel(data);
    final riskColor = _riskColor(riskLabel ?? 'low');
    final evacuationAdvisory = riskLabel != null &&
        (riskLabel.toLowerCase().contains('severe') ||
            riskLabel.toLowerCase().contains('high'));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(28.r),
        // boxShadow: [
        //   BoxShadow(
        //     color: FloodColors.heritagePurple.withValues(alpha: 0.06),
        //     blurRadius: 24,
        //     offset: const Offset(0, 10),
        //   ),
        // ],
      ),
      // child: Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     Row(
      //       children: [
      //         //  Expanded(
      //         // child: Text(
      //         //   'Live Rain Risk Assessment',
      //         //   overflow: TextOverflow.ellipsis,
      //         //   style: GoogleFonts.poppins(
      //         //     fontSize: 18.sp,
      //         //     fontWeight: FontWeight.w700,
      //         //     color: _titleText,
      //         //   ),
      //         // ),
      //         //   ),
      //         SizedBox(width: 8.w),
      //         Container(
      //           padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      //           decoration: BoxDecoration(
      //             color: _scaffoldBg,
      //             borderRadius: BorderRadius.circular(100.r),
      //           ),
      //           // child: Text(
      //           //   'Open-Meteo forecast',
      //           //   style: GoogleFonts.inter(
      //           //     fontSize: 12.sp,
      //           //     fontWeight: FontWeight.w600,
      //           //     color: FloodColors.heritagePurple,
      //           //   ),
      //           // ),
      //         ),
      //       ],
      //     ),
      //     SizedBox(height: 18.h),
      //     if (evacuationAdvisory) ...[
      //       Container(
      //         width: double.infinity,
      //         padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      //         decoration: BoxDecoration(
      //           color: FloodColors.danger.withValues(alpha: 0.1),
      //           borderRadius: BorderRadius.circular(14.r),
      //           border: Border.all(
      //               color: FloodColors.danger.withValues(alpha: 0.35)),
      //         ),
      //         child: Row(
      //           children: [
      //             Icon(Icons.directions_run_rounded,
      //                 color: FloodColors.danger, size: 20.sp),
      //             SizedBox(width: 10.w),
      //             Expanded(
      //               child: Text(
      //                 'Evacuation advisory in effect',
      //                 style: GoogleFonts.poppins(
      //                   fontSize: 13.sp,
      //                   fontWeight: FontWeight.w700,
      //                   color: FloodColors.danger,
      //                 ),
      //               ),
      //             ),
      //           ],
      //         ),
      //       ),
      //       SizedBox(height: 16.h),
      //     ],
      //     Row(
      //       children: [
      //         Container(
      //           padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      //           decoration: BoxDecoration(
      //             color: riskColor.withValues(alpha: 0.1),
      //             borderRadius: BorderRadius.circular(100.r),
      //           ),
      //           child: Text(
      //             '${(riskLabel ?? 'Low').toUpperCase()} RISK',
      //             style: GoogleFonts.poppins(
      //               fontSize: 12.sp,
      //               fontWeight: FontWeight.w700,
      //               color: riskColor,
      //               letterSpacing: 0.5,
      //             ),
      //           ),
      //         ),
      //         SizedBox(width: 10.w),
      //         Expanded(
      //           child: Text(
      //             '${(next12hRain ?? 0.0).toStringAsFixed(0)}mm expected in the next 12h (forecast)',
      //             style: GoogleFonts.inter(fontSize: 12.sp, color: _mutedText),
      //           ),
      //         ),
      //       ],
      //     ),
      //     SizedBox(height: 12.h),
      //     Text(
      //       _recommendedAction(riskLabel),
      //       style: GoogleFonts.inter(
      //           fontSize: 11.sp, color: _mutedText, height: 1.5),
      //     ),
      //   ],
      // ),
    );
  }

  // ─── SECTION HEADER ────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: FloodColors.heritagePurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: FloodColors.heritagePurple, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: _titleText,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }

  // ─── SAFETY ACCORDION ──────────────────────────────────
  Widget _buildSafetyAccordion(Map<String, dynamic> tip, int index) {
    final isExpanded = _expandedTipIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralBlack.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: () => setState(() {
            _expandedTipIndex = isExpanded ? -1 : index;
          }),
          child: AnimatedContainer(
            duration: 300.ms,
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color:
                            FloodColors.heritagePurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        tip['icon'] as IconData,
                        color: FloodColors.heritagePurple,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(
                        tip['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: _titleText,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: 300.ms,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _mutedText,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: EdgeInsets.only(top: 16.h, left: 56.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (tip['tips'] as List<String>)
                          .map((t) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(top: 4.h),
                                      width: 6.w,
                                      height: 6.w,
                                      decoration: BoxDecoration(
                                        color: FloodColors.heritagePurple,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Text(
                                        t,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          color: _bodyText,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: 300.ms,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── EMERGENCY ACTIONS ─────────────────────────────────
  Widget _buildEmergencyActions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FloodColors.deepAnchor,
            FloodColors.heritagePurple,
          ],
        ),
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: FloodColors.heritagePurple.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AppColors.warning, size: 24),
              SizedBox(width: 8.w),
              Text(
                'EMERGENCY ACTIONS',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralWhite.withValues(alpha: 0.54),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Need immediate help?',
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralWhite,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Call\nEmergency',
                  color: FloodColors.danger,
                  onTap: () =>
                      _showMessage(context, 'Calling emergency hotline...'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.campaign_rounded,
                  label: 'Report\nFlood',
                  color: const Color(0xFFF59E0B),
                  onTap: () =>
                      _showMessage(context, 'Opening flood report form...'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_location_rounded,
                  label: 'Share\nLocation',
                  color: const Color(0xFF0EA5E9),
                  onTap: () =>
                      _showMessage(context, 'Sharing your location...'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.neutralWhite.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 18.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
                color: AppColors.neutralWhite.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.neutralWhite, size: 22.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralWhite,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _colors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              alert['title'],
              style: GoogleFonts.poppins(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: _titleText,
              ),
            ),
            SizedBox(height: 16.h),
            _buildDetailRow('Status', alert['level'], alert['color'] as Color),
            SizedBox(height: 12.h),
            _buildDetailRow(
                'Station', alert['station'], FloodColors.heritagePurple),
            SizedBox(height: 12.h),
            _buildDetailRow(
                'Last Updated', alert['updated'], AppColors.neutralGray500),
            SizedBox(height: 20.h),
            Text(
              'Residents in this area are advised to monitor water levels and follow safety guidelines issued by MDRRMO.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: _bodyText,
                height: 1.6,
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14.sp, color: _mutedText),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }
}
