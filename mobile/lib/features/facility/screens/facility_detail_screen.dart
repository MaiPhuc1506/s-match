import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';
import '../widgets/court_schedule_grid.dart';
import '../widgets/facility_card.dart';
import 'add_edit_court_screen.dart';
import 'add_edit_facility_screen.dart';
import 'operating_hours_screen.dart';

class FacilityDetailScreen extends StatefulWidget {
  final FacilityCardItem facility;

  const FacilityDetailScreen({super.key, required this.facility});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  int _selectedTabIndex = 0; // 0 = Court Schedule, 1 = Facility Info
  int _selectedDateIndex = 0;
  late int _courtCount;
  late String _operatingHoursText;
  List<Map<String, dynamic>> _courts = [];
  int? _updatingSlotId;

  @override
  void initState() {
    super.initState();
    _courtCount = widget.facility.courtCount > 0
        ? widget.facility.courtCount
        : 4;
    _operatingHoursText = widget.facility.operatingHours.isEmpty
        ? 'Chưa thiết lập'
        : widget.facility.operatingHours;
    _loadFacilityData();
  }

  Future<void> _loadFacilityData() async {
    final data = await FacilityService.instance.getFacilityDetails(
      widget.facility.id,
    );
    if (!mounted || data == null) return;
    setState(() {
      if (data['courts'] != null && data['courts'] is List) {
        _courts = (data['courts'] as List)
            .map((court) => Map<String, dynamic>.from(court as Map))
            .toList();
        _courtCount = _courts.isNotEmpty ? _courts.length : 4;
      }
      if (data['operatingHours'] is List) {
        final hours = data['operatingHours'] as List;
        _operatingHoursText = 'Chưa thiết lập';
        if (hours.isNotEmpty && hours.first is Map) {
          final first = hours.first;
          final open = first['openTime'];
          final close = first['closeTime'];
          if (open is String &&
              close is String &&
              RegExp(r'^\d{2}:\d{2}').hasMatch(open) &&
              RegExp(r'^\d{2}:\d{2}').hasMatch(close)) {
            _operatingHoursText =
                '${open.substring(0, 5)} - ${close.substring(0, 5)}';
          }
        }
      } else {
        _operatingHoursText = 'Chưa thiết lập';
      }
    });
  }

  final List<String> _dates = [
    'Today',
    'Mon 25',
    'Tue 26',
    'Wed 27',
    'Thu 28',
    'Fri 29',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.facility.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (val) async {
              if (val == 'edit') {
                final nav = Navigator.of(context);
                final res = await nav.push<dynamic>(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditFacilityScreen(facility: widget.facility),
                  ),
                );
                if (!mounted) return;
                if (res == true) {
                  _loadFacilityData();
                } else if (res == 'deleted') {
                  nav.pop(true);
                }
              } else if (val == 'delete') {
                _confirmDeleteFacility();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text('Chỉnh sửa cơ sở'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa cơ sở', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Opacity(
                  opacity: .22,
                  child: SvgPicture.asset(
                    'assets/icons/sprint4_court_pattern.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 1. Facility Hero Card (345 x 108 px)
            _buildHeroCard(),

            const SizedBox(height: 8),

            // 2. Ba Stat Cards (105 x 72 px, cách nhau 15 px)
            _buildStatCards(),

            const SizedBox(height: 16),

            // 3. Tab Selector (Court Schedule vs Facility Info)
            _buildTabs(),

            const SizedBox(height: 12),

            if (_selectedTabIndex == 0) ...[
              // 4. Date Selector
              _buildDateSelector(),

              const SizedBox(height: 14),

              // 5. Court Schedule Grid
              CourtScheduleGrid(
                courtCount: _courtCount,
                courtNames: _courts.isNotEmpty
                    ? _courts.map((c) {
                        final name = (c['name'] as String? ?? '').trim();
                        if (name.contains('(')) {
                          return name.split('(')[0].trim();
                        }
                        return name;
                      }).toList()
                    : null,
              ),
            ] else ...[
              // Tab Facility Info
              _buildFacilityInfoTab(),
            ],

            const SizedBox(height: 20),
            _buildCourtManagement(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        AddEditCourtScreen(facilityId: widget.facility.id),
                    transitionDuration: const Duration(milliseconds: 250),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) => FadeTransition(opacity: animation, child: child),
                  ),
                );
                if (result == true) {
                  _loadFacilityData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, color: AppColors.white, size: 20),
              label: Text(
                'Add Court',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourtManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Courts',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_courts.isEmpty)
          const Text('Chưa có sân. Bấm Add Court để tạo sân.'),
        ..._courts.map((court) {
          final slots = court['timeSlots'] as List? ?? [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${court['name']} · ${court['status']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final changed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AddEditCourtScreen(
                                    facilityId: widget.facility.id,
                                    courtId: court['id'] as int,
                                    court: court,
                                  ),
                                ),
                              );
                          if (changed == true) _loadFacilityData();
                        },
                        child: const Text('Edit / Maintenance'),
                      ),
                      TextButton(
                        onPressed: () => _addTimeSlot(court['id'] as int),
                        child: const Text('Add Slot'),
                      ),
                    ],
                  ),
                  ...slots.map((slot) {
                    final id = slot['id'] as int;
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${slot['startTime']}–${slot['endTime']} · Day ${slot['dayOfWeek']}',
                      ),
                      subtitle: const Text('Tắt để khóa khung giờ cho Player'),
                      value: slot['isActive'] == true,
                      onChanged: _updatingSlotId != null
                          ? null
                          : (active) async {
                              setState(() => _updatingSlotId = id);
                              final success = await FacilityService.instance
                                  .setTimeSlotActive(
                                    facilityId: widget.facility.id,
                                    courtId: court['id'] as int,
                                    slotId: id,
                                    isActive: active,
                                  );
                              if (!mounted) return;
                              setState(() => _updatingSlotId = null);
                              if (success) {
                                _loadFacilityData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Không cập nhật được khung giờ',
                                    ),
                                  ),
                                );
                              }
                            },
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addTimeSlot(int courtId) async {
    final startController = TextEditingController(text: '17:00');
    final endController = TextEditingController(text: '17:30');
    final priceController = TextEditingController(text: '40000');
    var day = DateTime.now().weekday % 7;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Add Time Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(
                    labelText: 'Ngày trong tuần',
                  ),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(index == 0 ? 'Chủ Nhật' : 'Thứ ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) => updateDialog(() => day = value ?? day),
                ),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Bắt đầu (HH:mm)',
                  ),
                ),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'Kết thúc (HH:mm)',
                  ),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Giá (VND)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                final start = startController.text.trim();
                final end = endController.text.trim();
                final price = double.tryParse(priceController.text.trim());
                final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
                if (!pattern.hasMatch(start) ||
                    !pattern.hasMatch(end) ||
                    start.compareTo(end) >= 0 ||
                    price == null ||
                    price < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Kiểm tra giờ HH:mm và giá')),
                  );
                  return;
                }
                final success = await FacilityService.instance.addTimeSlot(
                  facilityId: widget.facility.id,
                  courtId: courtId,
                  dayOfWeek: day,
                  startTime: start,
                  endTime: end,
                  price: price,
                );
                if (!dialogContext.mounted) return;
                if (success) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Không thêm được slot. Kiểm tra giờ mở cửa hoặc slot trùng.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    startController.dispose();
    endController.dispose();
    priceController.dispose();
    if (saved == true) _loadFacilityData();
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.facility.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.facility.isOpen
                      ? const Color(0xFFDDEFE7)
                      : const Color(0xFFFAF0F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.facility.isOpen ? 'Open' : 'Closed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.facility.isOpen
                        ? AppColors.primary
                        : AppColors.linkAction,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.facility.address,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.facility.description ?? 'A modern badminton facility with high-quality courts and a friendly community.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 18 / 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: 'Courts',
            value: '$_courtCount',
            subtitle: 'Available',
            onTap: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Hours',
            value: _operatingHoursText,
            subtitle: 'Tap to edit',
            onTap: () async {
              final result = await Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      OperatingHoursScreen(facilityId: widget.facility.id),
                  transitionDuration: const Duration(milliseconds: 250),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) => FadeTransition(opacity: animation, child: child),
                ),
              );
              if (result == true) {
                _loadFacilityData();
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatItem(
            label: 'Type',
            value: 'Indoor',
            subtitle: 'Standard',
            onTap: null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Court Schedule',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedTabIndex == 0
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Facility Info',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedTabIndex == 1
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedDateIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _dates[index],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacilityInfoTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Information',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Contact Phone', '0901234567'),
          _buildInfoRow('Operating Hours', _operatingHoursText),
          _buildInfoRow('Flooring', 'Yonex Competition Mat'),
          _buildInfoRow('Amenities', 'Parking, Shower, Free Wifi, Drinks'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFacility() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa cơ sở?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${widget.facility.name}"? Toàn bộ sân con và khung giờ thuộc cơ sở này sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await FacilityService.instance.deleteFacility(
        widget.facility.id,
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa cơ sở thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop('deleted');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Không thể xóa cơ sở.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
