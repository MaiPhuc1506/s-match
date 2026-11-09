import '../widgets/dashboard_motion.dart';

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/network/api_client.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/widgets/logout_dialog.dart';
import '../../facility/screens/add_edit_facility_screen.dart';
import '../../facility/screens/facility_detail_screen.dart';
import '../../facility/screens/facility_list_screen.dart';
import '../../facility/widgets/facility_card.dart';
import '../data/dashboard_repository.dart';
import '../widgets/dashboard_assets.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/dashboard_widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    required this.role,
    this.preview = false,
    this.initialTab = 0,
  });
  final DashboardRole role;
  final bool preview;
  final int initialTab;
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _motionVisit = DashboardMotionVisit();
  late Future<DashboardData> _data;
  late int _tab;
  String _period = '7 Days',
      _adminPeriod = '6 Months',
      _bookingFilter = 'All',
      _facilityFilter = 'All',
      _query = '';
  bool _owners = false;
  int _facilityIndex = 0;
  int? _selectedFacilityId;
  final DateTime _demoDate = DateUtils.dateOnly(DateTime.now());
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _scroll = ScrollController();
  final _search = TextEditingController();
  DashboardPalette get p => DashboardPalette(widget.role);
  bool get _authorized =>
      ApiClient.instance.token != null &&
      dashboardRoleName(AuthService.instance.currentUser?['role']) ==
          (p.admin ? 'ADMIN' : 'COURT_OWNER');

  Future<bool> _canOpenManagement() async {
    if (_authorized) return true;
    await _info(
      'Sign In Required',
      const DashboardSessionException().toString(),
    );
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 3);
    if (widget.role == DashboardRole.owner && widget.initialTab == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _account();
      });
    }

    _data = _fetchData();
  }

  Future<DashboardData> _fetchData() => ref
      .read(dashboardRepositoryProvider)
      .load(
        widget.role,
        preview: widget.preview,
        period: p.admin ? _adminPeriod : _period,
        facilityId: _selectedFacilityId,
        bookingDate: _date,
      );

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _data = _fetchData();
  });
  void _select(int value) {
    if (!p.admin && value == 4) {
      _account();
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _tab = value;
      _query = '';
      _search.clear();
    });
  }

  void _openDemoData() {
    Navigator.of(context).push(
      AppMotion.route<void>(
        DashboardScreen(role: widget.role, preview: true),
        name: '/${widget.role.name}-dashboard-demo',
      ),
    );
  }

  void _back() {
    if (_tab != 0) {
      _select(0);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _info(String title, String message) async {
    await dashboardOptions(context, p, title, [], subtitle: message);
  }

  Future<void> _periodPicker() async {
    final value = await dashboardOptions(
      context,
      p,
      'Select Period',
      p.admin
          ? ['3 Months', '6 Months', 'This Year']
          : ['7 Days', 'This Month', 'This Year'],
      subtitle: widget.preview
          ? 'Illustrative analytics · changing the period does not query a live analytics API.'
          : 'Select a reporting period to refresh live analytics.',
    );
    if (value != null && mounted) {
      setState(() {
        if (p.admin) {
          _adminPeriod = value;
        } else {
          _period = value;
        }
        _data = _fetchData();
      });
    }
  }

  Future<void> _account() async {
    if (!widget.preview && (!await _canOpenManagement() || !mounted)) return;
    final action = await dashboardOptions(
      context,
      p,
      p.admin ? 'Admin Account' : 'Owner Account',
      [if (!p.admin) 'Manage Facilities', 'Log Out'],
    );
    if (!mounted) return;
    if (action == 'Log Out') {
      if (widget.preview) {
        _info('Preview', 'No account is logged out from a UI preview.');
      } else {
        await showLogoutConfirmationDialog(context);
      }
    } else if (action == 'Manage Facilities') {
      _manageFacilities();
    }
  }

  Future<void> _manageFacilities() async {
    if (widget.preview) {
      await _info(
        'Manage Facilities',
        'UI preview only. Log in as Court Owner to manage your facilities.',
      );
      return;
    }
    if (!await _canOpenManagement() || !mounted) return;
    final tab = await Navigator.push<int>(
      context,
      AppMotion.route(
        FacilityListScreen(
          onNavigateTab: (index) => Navigator.pop(context, index),
        ),
      ),
    );
    if (mounted) {
      _reload();
      if (tab != null) _select(tab);
    }
  }

  Future<void> _facilityDetail(DashboardFacility f) async {
    if (widget.preview) {
      await _info(
        f.name,
        '${f.courts} courts · ${f.status ?? 'Status unavailable'}\n${f.address}\nPreview only; no facility is modified.',
      );
      return;
    }
    if (!await _canOpenManagement() || !mounted) return;
    await Navigator.push(
      context,
      AppMotion.route(
        FacilityDetailScreen(
          facility: FacilityCardItem(
            id: f.id,
            name: f.name,
            address: f.address,
            courtCount: f.courts,
            operatingHours: 'Chưa thiết lập',
            contactPhone: f.phone,
            description: f.description,
          ),
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _addFacility() async {
    if (widget.preview) {
      await _info(
        'Add Facility',
        'UI preview only. Log in to create a facility.',
      );
      return;
    }
    if (!await _canOpenManagement() || !mounted) return;
    await Navigator.push(
      context,
      AppMotion.route(const AddEditFacilityScreen()),
    );
    if (mounted) _reload();
  }

  String _number(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  bool get _isToday => DateUtils.isSameDay(_date, DateTime.now());
  String get _shortDate =>
      '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_date.weekday - 1]}, ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_date.month - 1]} ${_date.day}';
  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (mounted && date != null) {
      setState(() {
        _date = date;
        _data = _fetchData();
      });
    }
  }

  String get _title => p.admin
      ? [
          'Platform Overview',
          'User Management',
          'Facility Management',
          'System Analytics',
        ][_tab]
      : ['Your courts today', 'Court Map', 'Bookings', 'Owner Analytics'][_tab];

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          SizedBox(height: math.max(52, MediaQuery.paddingOf(context).top)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DashboardReveal(
                visit: _motionVisit,
                id: 'header',
                down: true,
                child: _header(),
              ),
            ),
          ),
          if (widget.preview && p.admin)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Material(
                color: p.soft,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: p.brand, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo data · No real payments',
                          style: p.text(
                            12,
                            weight: FontWeight.w600,
                            color: p.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<DashboardData>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(color: p.brand),
                  );
                }
                if (snapshot.hasError) return _error(snapshot.error!);
                final data = snapshot.requireData;
                return RefreshIndicator(
                  color: p.brand,
                  onRefresh: () async {
                    _reload();
                    try {
                      await _data;
                    } catch (_) {
                      // FutureBuilder displays the failure and retry action.
                    }
                  },
                  child: SingleChildScrollView(
                    key: ValueKey(
                      'dashboard-content-${widget.role.name}-$_tab',
                    ),
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in _content(data).asMap().entries)
                              if (entry.value is SizedBox)
                                entry.value
                              else
                                DashboardReveal(
                                  key: ValueKey('$_tab-${entry.key}'),
                                  visit: _motionVisit,
                                  id: '$_tab-${entry.key}',
                                  delay: (entry.key ~/ 2 % 4) * 90,
                                  child: entry.value,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: DashboardBottomNavigation(
        palette: p,
        index: _tab,
        onChanged: _select,
      ),
    ),
  );

  Widget _header() => SizedBox(
    height:
        (_tab == 0 ? 72.0 : 60.0) *
        math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: _tab == 0 ? 20 : 8),
      child: Row(
        children: [
          if (_tab != 0 || (widget.preview && Navigator.canPop(context)))
            DashboardControl(
              label: 'Back',
              onTap: _back,
              child: DashboardAsset(
                'detail.imgIconBack',
                size: 22,
                color: p.brand,
              ),
            ),
          if (_tab != 0 || (widget.preview && Navigator.canPop(context)))
            const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tab == 0) ...[
                  Text(
                    p.admin ? 'S-MATCH ADMIN' : 'COURT OWNER',
                    style: p
                        .text(10, weight: FontWeight.w600, color: p.muted)
                        .copyWith(letterSpacing: .8),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.text(_tab == 0 ? 22 : 20, weight: FontWeight.w600),
                ),
                if (widget.preview && !p.admin) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Demo data · No real payments',
                    style: p.text(10, color: p.muted),
                  ),
                ],
              ],
            ),
          ),
          if (_tab == 0 && !widget.preview && kDebugMode)
            DashboardControl(
              label: 'View demo data',
              onTap: _openDemoData,
              child: Icon(Icons.preview_outlined, size: 22, color: p.brand),
            ),
          if (_tab == 0)
            DashboardControl(
              label: 'Notifications',
              onTap: () => _info(
                'Notifications',
                'No new notifications. A notifications API is not available yet.',
              ),
              child: DashboardAsset(
                'owner.imgFrame3',
                size: 22,
                color: p.brand,
              ),
            ),
          if (!p.admin && _tab == 1)
            DashboardControl(
              label: 'Schedule Filters',
              onTap: () => dashboardOptions(
                context,
                p,
                'Schedule Filters',
                ['All Courts', 'Indoor', 'Outdoor'],
                subtitle: 'Demo schedule · the live Owner schedule API is not available.',
              ),
              child: DashboardAsset('courts.imgIconFilter', size: 22),
            ),
          if (p.admin && (_tab == 1 || _tab == 2))
            DashboardControl(
              label: _tab == 1 ? 'Add User' : 'Add Facility',
              onTap: _tab == 1
                  ? () => _info(
                      'Add User',
                      'Account provisioning is not exposed by the current API. No account will be created.',
                    )
                  : _addFacility,
              child: DashboardAsset(
                'users.imgIconPlus',
                size: 22,
                color: p.brand,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _error(Object error) {
    final message = error is DashboardSessionException
        ? error.toString()
        : error is DioException && error.response?.statusCode == 403
        ? 'Your account does not have access to this dashboard.'
        : 'Unable to load dashboard data. Check your connection and try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: p.text(14)),
            const SizedBox(height: 16),
            TextButton(onPressed: _reload, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _gap([double size = 16]) => SizedBox(height: size);
  Widget _note(String value) => Text(value, style: p.text(11, color: p.muted));
  Widget _empty(String title, String body) => DashboardCard(
    palette: p,
    child: Column(
      children: [
        Text(title, style: p.text(16, weight: FontWeight.w600)),
        _gap(8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: p.text(12, color: p.muted),
        ),
      ],
    ),
  );
  Widget _button(String title, VoidCallback onTap) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: p.brand,
      side: BorderSide(color: p.brand),
      minimumSize: const Size.fromHeight(52),
      shape: const StadiumBorder(),
    ),
    child: Text(
      title,
      style: p.text(14, weight: FontWeight.w600, color: p.brand),
    ),
  );

  String _currency(num? value) =>
      value == null ? 'Unavailable' : '${_number(value.round())}đ';

  String _compactCurrency(num? value) {
    if (value == null) return '—';
    if (value >= 1000000) {
      final m = (value / 1000000).toStringAsFixed(2);
      return '${m}Mđ';
    }
    return '${_number(value.round())}đ';
  }

  String _percent(double? value) {
    if (value == null) return '—';
    final rounded = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$rounded%';
  }

  List<Widget> _content(DashboardData data) {
    if (p.admin) {
      return switch (_tab) {
        0 => _adminOverview(data),
        1 => _users(data),
        2 => _facilities(data),
        _ => _systemAnalytics(data),
      };
    }
    return switch (_tab) {
      0 => _ownerOverview(data),
      1 => _schedule(data),
      2 => _bookings(data),
      _ => _ownerAnalytics(data),
    };
  }

  Widget _hero({
    required String title,
    String? value,
    required String detail,
    VoidCallback? onTap,
  }) => Material(
    color: p.brand,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap ?? () => _select(3),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: p.admin ? 108 : 140),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: p.text(
                      p.admin ? 20 : 12,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (value != null) ...[
                    _gap(6),
                    DashboardCount(
                      value,
                      style: p.text(
                        30,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  _gap(6),
                  Padding(
                    padding: const EdgeInsets.only(right: 52),
                    child: Text(
                      detail,
                      style: p.text(
                        11,
                        weight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 18,
              bottom: 14,
              child: Opacity(
                opacity: .45,
                child: DashboardAsset('owner.imgImage', size: 64),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _ownerOverview(DashboardData data) {
    final analytics = data.analytics;
    final live = !data.preview;
    final day = data.preview && DateUtils.isSameDay(_date, _demoDate)
        ? data.ownerDay
        : null;
    final upcoming = live
        ? data.bookings
              .where(
                (b) =>
                    (b.status == 'Confirmed' || b.status == 'Pending') &&
                    (b.startTime?.isAfter(DateTime.now()) ?? true),
              )
              .toList()
        : day?.upcoming ?? <DashboardBooking>[];
    final next = upcoming.isNotEmpty ? upcoming.first : null;
    return [
      DashboardSelector(
        data.facilities.isEmpty
            ? 'No facilities'
            : live && _selectedFacilityId == null
            ? 'All facilities'
            : data
                  .facilities[_facilityIndex.clamp(
                    0,
                    data.facilities.length - 1,
                  )]
                  .name,
        palette: p,
        onTap: () async {
          if (data.facilities.isEmpty) return;
          final choice = await dashboardOptions(context, p, 'Switch Facility', [
            if (live) 'All facilities',
            ...data.facilities.map((f) => f.name),
          ]);
          if (mounted && choice != null) {
            final idx = data.facilities.indexWhere((f) => f.name == choice);
            setState(() {
              _facilityIndex = idx < 0 ? 0 : idx;
              _selectedFacilityId = idx < 0 ? null : data.facilities[idx].id;
              _data = _fetchData();
            });
          }
        },
      ),
      _gap(),
      Row(
        children: [
          SizedBox(
            width: 84,
            height: 44,
            child: FilledButton(
              onPressed: () => setState(() {
                _date = DateUtils.dateOnly(DateTime.now());
                _data = _fetchData();
              }),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: p.brand,
                foregroundColor: Colors.white,
                textStyle: p.text(13, weight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text('Today'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DashboardSelector(
              _shortDate,
              icon: 'owner.todayCalendar',
              chevron: 'owner.todayChevron',
              palette: p,
              onTap: _chooseDate,
            ),
          ),
        ],
      ),
      _gap(),
      _hero(
        title: _isToday ? 'Available now' : 'Court availability',
        value: day == null
            ? '—'
            : '${day.availableCourts} / ${day.totalCourts} courts',
        detail: day == null
            ? (live
                  ? 'Current court availability is not available yet.'
                  : 'No demo snapshot for the selected date.')
            : '${day.inUseCourts} in use · ${day.maintenanceCourts} under maintenance',
        onTap: () => _select(1),
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DashboardMetric(
              _isToday ? 'Bookings today' : 'Bookings on date',
              live
                  ? _number(data.bookings.length)
                  : day == null
                  ? '—'
                  : _number(day.bookingCount),
              live
                  ? '${upcoming.length} upcoming'
                  : day == null
                  ? 'Not available'
                  : '${day.upcoming.length} upcoming',
              palette: p,
              icon: 'owner.imgIconCalendar',
              onTap: () => _select(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DashboardMetric(
              'Next booking',
              next == null ? '—' : next.time.split('–').first,
              next?.court ?? 'No upcoming booking available',
              palette: p,
              icon: 'owner.imgIconCalendar',
              onTap: next == null ? null : () => _openBooking(next),
            ),
          ),
        ],
      ),
      _gap(),
      Row(
        children: [
          Expanded(
            child: Text(
              _isToday ? 'Upcoming today' : 'Upcoming · $_shortDate',
              style: p.text(16, weight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _select(2),
            style: TextButton.styleFrom(
              foregroundColor: p.brand,
              minimumSize: const Size(72, 44),
            ),
            child: const Text('View all'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        _empty(
          'No upcoming bookings available',
          live
              ? 'No bookings for the selected date and facility.'
              : 'Choose Today to return to the sample day.',
        )
      else
        for (final booking in upcoming.take(2)) ...[
          _bookingCard(booking, compact: true),
          const SizedBox(height: 12),
        ],
      _gap(),
      Text('Monthly performance', style: p.text(16, weight: FontWeight.w600)),
      _gap(),
      _hero(
        title: live ? 'Gross Booked Value' : 'Booking Value',
        value: live
            ? _currency(analytics?.grossBookedRevenue)
            : _currency(DashboardFixtures.grossBookedValue),
        detail: live
            ? 'Confirmed & completed booking value · $_period'
            : '↑ 12.8% vs last month · This Month',
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DashboardMetric(
              'Bookings',
              live
                  ? (analytics?.totalBookings != null
                        ? _number(analytics!.totalBookings!)
                        : '—')
                  : _number(DashboardFixtures.bookingCount),
              live
                  ? '${analytics?.confirmedBookings ?? 0} confirmed · $_period'
                  : '↑ 8.4% this month',
              palette: p,
              icon: 'owner.imgIconCalendar',
              onTap: () => _select(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DashboardMetric(
              'Occupancy',
              live
                  ? _percent(analytics?.occupancyRatePercent)
                  : _percent(DashboardFixtures.occupancyPercent),
              'Scheduled court time',
              palette: p,
              icon: 'metric.occupancy',
              onTap: () => _select(3),
            ),
          ),
        ],
      ),
      _gap(),
      DashboardTrendChart(
        palette: p,
        period: _period,
        onPeriod: _periodPicker,
        series: analytics?.trendSeries,
        live: live,
      ),
      _gap(),
      _note(
        live
            ? 'Live analytics · gross booked value from confirmed/completed bookings. Collected payment revenue is unavailable.'
            : 'Demo figures · illustrative booking value, occupancy and trends. No real payments processed.',
      ),
    ];
  }

  List<Widget> _adminOverview(DashboardData data) {
    final analytics = data.analytics;
    final live = !data.preview;
    return [
      _hero(
        title: 'S-Match Analytics',
        detail: 'Monitor your badminton community',
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DashboardMetric(
              'Total Players',
              _number(data.playerCount),
              'Registered players',
              palette: p,
              icon: 'owner.imgVector',
              onTap: () {
                setState(() => _owners = false);
                _select(1);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DashboardMetric(
              'Court Owners',
              _number(data.ownerCount),
              'Owner accounts',
              palette: p,
              icon: 'admin.imgIconCalendar1',
              onTap: () {
                setState(() => _owners = true);
                _select(1);
              },
            ),
          ),
        ],
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DashboardMetric(
              'Registered Courts',
              '${data.courtCount}',
              'Across all facilities',
              palette: p,
              icon: 'admin.imgIconCalendar2',
              onTap: () => _select(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DashboardMetric(
              'Total Bookings',
              live
                  ? (analytics?.totalBookings != null
                        ? _number(analytics!.totalBookings!)
                        : '—')
                  : '2,410',
              live ? 'Bookings in $_adminPeriod' : 'All-time bookings · demo',
              palette: p,
              icon: 'owner.imgIconCalendar',
              onTap: () => _select(3),
            ),
          ),
        ],
      ),
      _gap(),
      DashboardTrendChart(
        palette: p,
        period: _adminPeriod,
        onPeriod: _periodPicker,
        growth: true,
        series: analytics?.trendSeries,
        live: live,
      ),
      _gap(),
      _note(
        data.preview
            ? 'UI preview · all values and records are illustrative.'
            : 'Live API · users, courts, booking totals and revenue trend.',
      ),
    ];
  }

  List<Widget> _ownerAnalytics(DashboardData data) {
    final analytics = data.analytics;
    final live = !data.preview;
    return [
      DashboardSelector(
        data.preview && _period == '7 Days' ? 'This Month' : _period,
        palette: p,
        onTap: _periodPicker,
      ),
      _gap(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DashboardMetric(
              'Bookings',
              live
                  ? (analytics?.totalBookings != null
                        ? _number(analytics!.totalBookings!)
                        : '—')
                  : _number(DashboardFixtures.bookingCount),
              live ? _period : 'This month',
              palette: p,
              icon: 'owner.imgIconCalendar',
              compact: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DashboardMetric(
              'Value',
              live
                  ? _compactCurrency(analytics?.grossBookedRevenue)
                  : _compactCurrency(DashboardFixtures.grossBookedValue),
              live ? _period : 'This month',
              palette: p,
              icon: 'metric.value',
              compact: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DashboardMetric(
              'Occupancy',
              live
                  ? _percent(analytics?.occupancyRatePercent)
                  : _percent(DashboardFixtures.occupancyPercent),
              live ? _period : 'This month',
              palette: p,
              icon: 'metric.occupancy',
              compact: true,
            ),
          ),
        ],
      ),
      _gap(),
      DashboardTrendChart(
        palette: p,
        period: _period,
        onPeriod: _periodPicker,
        series: analytics?.trendSeries,
        live: live,
      ),
      _gap(),
      DashboardPeakChart(palette: p, courts: analytics?.courts, live: live),
      _gap(),
      _note(
        live
            ? 'Live analytics · gross booked value, occupancy and court utilization.'
            : 'Demo figures · illustrative booking value and court usage. No real payments processed.',
      ),
    ];
  }

  List<Widget> _systemAnalytics(DashboardData data) {
    final analytics = data.analytics;
    final live = !data.preview;
    return [
      DashboardSelector(_adminPeriod, palette: p, onTap: _periodPicker),
      _gap(),
      DashboardTrendChart(
        palette: p,
        period: _adminPeriod,
        onPeriod: _periodPicker,
        growth: true,
        series: analytics?.trendSeries,
        live: live,
      ),
      _gap(),
      DashboardStatusChart(
        palette: p,
        courts: analytics?.courts,
        totalCourts: data.courtCount,
        live: live,
      ),
      _gap(),
      _note(
        live ? 'Live analytics · booking trend and court operational status.' : 'Illustrative series · user growth and court approval status are not provided by the current APIs.',
      ),
    ];
  }

  Widget _searchField(String hint) => TextField(
    controller: _search,
    onChanged: (q) => setState(() => _query = q.toLowerCase().trim()),
    style: p.text(12),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: p.text(12, color: p.muted),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(13),
        child: DashboardAsset('users.imgIconSearch', size: 18, color: p.muted),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: p.border),
      ),
    ),
  );
  Widget _filters(
    List<String> labels,
    String value,
    ValueChanged<String> select,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: DashboardPill(
              label,
              palette: p,
              selected: value == label,
              onTap: () => select(label),
            ),
          ),
      ],
    ),
  );

  List<Widget> _bookings(DashboardData data) {
    final rows = data.bookings.where(
      (b) =>
          (!data.preview || DateUtils.isSameDay(_date, _demoDate)) &&
          (_bookingFilter == 'All' || b.status == _bookingFilter) &&
          '${b.court} ${b.player}'.toLowerCase().contains(_query),
    );
    return [
      _searchField('Search by name or court...'),
      _gap(),
      _filters(
        ['All', 'Confirmed', 'Pending', 'Cancelled'],
        _bookingFilter,
        (v) => setState(() => _bookingFilter = v),
      ),
      _gap(),
      Text(
        _isToday ? 'Today · $_shortDate' : _shortDate,
        style: p.text(14, weight: FontWeight.w600),
      ),
      _gap(),
      if (rows.isEmpty)
        _empty(
          'No bookings',
          'No bookings match your search or selected status.',
        )
      else
        ...rows.expand((b) => [_bookingCard(b), _gap()]),
      _gap(),
      _note(
        data.preview
            ? 'UI preview · sample bookings only.'
            : 'No live booking records are substituted with samples.',
      ),
    ];
  }

  void _openBooking(DashboardBooking booking) => Navigator.push(
    context,
    AppMotion.route(OwnerBookingDetailScreen(booking: booking)),
  );

  Widget _bookingCard(DashboardBooking b, {bool compact = false}) =>
      DashboardCard(
        palette: p,
        padding: const EdgeInsets.all(14),
        onTap: () => _openBooking(b),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 48 : 66),
          child: Row(
            children: [
              DashboardAsset('bookings.imgIconCourt', size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact ? '${b.court} · ${b.time}' : b.court,
                      style: p.text(14, weight: FontWeight.w600),
                    ),
                    _gap(4),
                    Text(
                      compact
                          ? '${b.player} · ${b.status}'
                          : '${b.player} · ${b.time}',
                      style: p.text(12, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  if (!compact)
                    DashboardPill(b.status, palette: p, status: true),
                  _gap(4),
                  DashboardAsset('bookings.imgIconRight', size: 16),
                ],
              ),
            ],
          ),
        ),
      );

  List<Widget> _users(DashboardData data) {
    final users = data.people
        .where(
          (u) =>
              u.role == (_owners ? 'COURT_OWNER' : 'PLAYER') &&
              u.name.toLowerCase().contains(_query),
        )
        .toList();
    return [
      _filters(
        [
          'Players (${_number(data.playerCount)})',
          'Owners (${_number(data.ownerCount)})',
        ],
        _owners
            ? 'Owners (${_number(data.ownerCount)})'
            : 'Players (${_number(data.playerCount)})',
        (v) => setState(() => _owners = v.startsWith('Owners')),
      ),
      _gap(),
      _searchField('Search user...'),
      _gap(),
      if (users.isEmpty) _empty('No users found', 'Try another name or role.'),
      ...users.expand(
        (u) => [
          DashboardCard(
            palette: p,
            padding: const EdgeInsets.all(14),
            onTap: () => _info(
              u.name,
              '${_owners ? 'Court Owner' : 'Player'}${u.status == null ? '' : ' · ${u.status}'}\n${data.preview ? 'UI preview only.' : 'The API provides name and role only. Status editing is unavailable.'}',
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Row(
                children: [
                  if (u.avatar != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        dashboardAssets[u.avatar]!,
                        width: 44,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 48,
                      decoration: BoxDecoration(
                        color: p.soft,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          u.name.isEmpty ? '?' : u.name.characters.first,
                          style: p.text(
                            18,
                            weight: FontWeight.w600,
                            color: p.brand,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          style: p.text(14, weight: FontWeight.w600),
                        ),
                        _gap(4),
                        Text(
                          '${_owners ? 'Court Owner' : 'Player'} · ${u.status ?? 'Status unavailable'}',
                          style: p.text(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DashboardAsset(
                    'users.imgIconRight',
                    size: 16,
                    color: p.muted,
                  ),
                ],
              ),
            ),
          ),
          _gap(),
        ],
      ),
      _note(
        data.preview ? 'UI preview · sample users.' : 'Live users · status and administrative write operations are not exposed by the API.',
      ),
    ];
  }

  List<Widget> _facilities(DashboardData data) {
    String filterLabel(String value) => data.preview
        ? '$value (${value == 'All'
              ? 186
              : value == 'Pending'
              ? 28
              : 14})'
        : value == 'All'
        ? 'All (${data.facilities.length})'
        : value;
    final rows = data.facilities.where(
      (f) =>
          (_facilityFilter == 'All' || f.status == _facilityFilter) &&
          f.name.toLowerCase().contains(_query),
    );
    return [
      _filters(
        ['All', 'Pending', 'Inactive'].map(filterLabel).toList(),
        filterLabel(_facilityFilter),
        (v) => setState(() => _facilityFilter = v.split(' ').first),
      ),
      _gap(),
      _searchField('Search facility...'),
      _gap(),
      if (rows.isEmpty)
        _empty(
          'No facilities found',
          !data.preview && _facilityFilter != 'All'
              ? 'Facility approval status is not provided by the current API.'
              : 'Try another name or status.',
        ),
      ...rows.expand(
        (f) => [
          DashboardCard(
            palette: p,
            padding: const EdgeInsets.all(14),
            onTap: () => _facilityDetail(f),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      dashboardAssets['facilities.imgFacilityReusedCourtPhoto']!,
                      width: 64,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: p.text(14, weight: FontWeight.w600),
                        ),
                        _gap(4),
                        Text(
                          '${f.courts} courts · ${f.status ?? 'Status unavailable'}',
                          style: p.text(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DashboardAsset(
                    'facilities.imgIconRight',
                    size: 16,
                    color: p.muted,
                  ),
                ],
              ),
            ),
          ),
          _gap(),
        ],
      ),
      _note(
        data.preview ? 'UI preview · sample facilities.' : 'Live facilities · facility photos and approval status are not supplied by the API. A reference thumbnail is shown.',
      ),
    ];
  }

  List<Widget> _schedule(DashboardData data) => [
    DashboardSelector(_shortDate, palette: p, onTap: _chooseDate),
    _gap(),
    if (!data.preview) ...[
      if (data.bookings.isEmpty)
        _empty('No bookings', 'No bookings for this date and facility.'),
      ...data.bookings.expand((b) => [_bookingCard(b), _gap()]),
    ] else
      DashboardScheduleGrid(
        palette: p,
        onBooked: () => Navigator.push(
          context,
          AppMotion.route(
            const OwnerBookingDetailScreen(
              booking: DashboardBooking(
                'Court 01',
                'Nguyen Van A',
                '18:00–19:00',
                'Confirmed',
                '120,000đ',
              ),
            ),
          ),
        ),
      ),
    _gap(),
    if (data.preview)
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final entry in [
            ('Available', const Color(0xFFE0F3E7)),
            ('Booked', const Color(0xFFFCE6E4)),
            ('Event', const Color(0xFFF2E4F7)),
            ('Locked', const Color(0xFFD6DCD8)),
          ])
            SizedBox(
              width: 76,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: entry.$2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    entry.$1,
                    style: p.text(10, weight: FontWeight.w500, color: p.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    _gap(),
    _note(
      data.preview
          ? 'Tap a booking to view its details. Demo schedule.'
          : 'Owner schedule API required.',
    ),
    _gap(),
    _button('Manage Facilities', _manageFacilities),
  ];
}

class DashboardScheduleGrid extends StatelessWidget {
  const DashboardScheduleGrid({
    super.key,
    required this.palette,
    required this.onBooked,
  });
  final DashboardPalette palette;
  final VoidCallback onBooked;
  static const _states = [
    [0, 0, 0, 0],
    [0, 0, 1, 0],
    [1, 1, 0, 0],
    [0, 0, 2, 1],
    [0, 3, 3, 3],
    [1, 3, 3, 3],
    [0, 3, 3, 3],
  ];
  @override
  Widget build(BuildContext context) => DashboardCard(
    palette: palette,
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                'Time',
                style: palette.text(11, color: palette.muted),
              ),
            ),
            for (var c = 0; c < 4; c++)
              Expanded(
                child: Center(
                  child: Text(
                    'C${c + 1}',
                    style: palette.text(12, weight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var r = 0; r < 7; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(r + 6).toString().padLeft(2, '0')}:00',
                    style: palette.text(11, color: palette.muted),
                  ),
                ),
                for (var c = 0; c < 4; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        label:
                            'Court ${c + 1}, ${r + 6}:00, ${['Available', 'Booked', 'Event', 'Locked'][_states[r][c]]}',
                        button: _states[r][c] == 1,
                        child: InkWell(
                          onTap: _states[r][c] == 1 ? onBooked : null,
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: [
                                const Color(0xFFE0F3E7),
                                const Color(0xFFFCE6E4),
                                const Color(0xFFF2E4F7),
                                const Color(0xFFD6DCD8),
                              ][_states[r][c]],
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: _states[r][c] == 3
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: CustomPaint(
                                      painter: _HatchPainter(),
                                    ),
                                  )
                                : _states[r][c] == 2
                                ? const Center(
                                    child: DashboardAsset(
                                      'courts.imgFrame4',
                                      size: 18,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .6)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OwnerBookingDetailScreen extends StatelessWidget {
  const OwnerBookingDetailScreen({super.key, required this.booking});
  final DashboardBooking booking;
  @override
  Widget build(BuildContext context) {
    const p = DashboardPalette(DashboardRole.owner);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: p.background,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 60,
          titleSpacing: 6,
          title: Text(
            'Booking Details',
            style: p.text(20, weight: FontWeight.w600),
          ),
          leading: DashboardControl(
            label: 'Back',
            onTap: () => Navigator.pop(context),
            child: DashboardAsset('detail.imgIconBack', size: 22),
          ),
          actions: [
            DashboardControl(
              label: 'Booking Actions',
              onTap: () => dashboardOptions(
                context,
                p,
                'Booking Actions',
                [],
                subtitle: 'UI preview only. No booking will be changed.',
              ),
              child: const DashboardAsset('detail.imgIconMore', size: 22),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        dashboardAssets['detail.imgCourtReusedPhotograph']!,
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x9905644F)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 16,
                        child: Text(
                          booking.court,
                          style: p.text(
                            24,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DashboardCard(
                palette: p,
                child: Column(
                  children: [
                    for (final row in [
                      ('detail.imgIconCalendar', 'Tuesday, Nov 3, 2026'),
                      ('detail.imgIconClock', '${booking.time} · 1 hour'),
                      ('detail.imgVector', booking.player),
                      ('detail.imgVector1', '+84 901234567'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            DashboardAsset(row.$1, size: 18),
                            const SizedBox(width: 12),
                            Expanded(child: Text(row.$2, style: p.text(13))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Booking Status', style: p.text(14))),
                  DashboardPill(booking.status, palette: p, status: true),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: p.text(14, weight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    booking.total,
                    style: p.text(20, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'UI preview · sample booking. Contact and booking updates are not connected to a live Owner API.',
                style: p.text(11, color: p.muted),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.brand,
                side: BorderSide(color: p.brand),
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: () => dashboardOptions(
                context,
                p,
                'Contact Player',
                [],
                subtitle:
                    '${booking.player}\n+84 901234567\nSample contact · no call is placed.',
              ),
              child: const Text('Contact Player'),
            ),
          ),
        ),
      ),
    );
  }
}
