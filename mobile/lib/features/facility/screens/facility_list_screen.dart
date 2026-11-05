import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';
import '../widgets/facility_card.dart';
import 'add_edit_facility_screen.dart';
import 'facility_detail_screen.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../dashboard/widgets/dashboard_widgets.dart';
import '../../../core/theme/app_motion.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  List<FacilityCardItem> _facilities = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    setState(() => _isLoading = true);
    final data = await FacilityService.instance.getMyFacilities();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadFailed = data == null;
      if (data != null) {
        _facilities = data.map((facility) {
          final hours = facility['operatingHours'];
          String hoursText = 'Chưa thiết lập';
          if (hours is List && hours.isNotEmpty && hours.first is Map) {
            final open = hours.first['openTime'];
            final close = hours.first['closeTime'];
            if (open is String &&
                close is String &&
                open.length >= 5 &&
                close.length >= 5) {
              hoursText = '${open.substring(0, 5)} - ${close.substring(0, 5)}';
            }
          }
          return FacilityCardItem(
            id: facility['id'] as int,
            name: facility['name'] as String? ?? '',
            address: facility['address'] as String? ?? '',
            courtCount: (facility['courts'] as List?)?.length ?? 0,
            operatingHours: hoursText,
            isOpen: hours is List && hours.isNotEmpty,
            contactPhone: facility['contactPhone'] as String?,
            description: facility['description'] as String?,
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Gradient Xanh (393 x 220 px)
            _buildHeader(),

            const SizedBox(height: 16),

            // 2. Danh sách Facility Cards (345 x 150 px)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    )
                  else if (_loadFailed)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: TextButton(
                        onPressed: _loadFacilities,
                        child: const Text(
                          'Không tải được cơ sở. Nhấn để thử lại.',
                        ),
                      ),
                    )
                  else if (_facilities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('Bạn chưa có cơ sở nào.'),
                    ),
                  ..._facilities.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FacilityCard(
                        facility: item,
                        onTap: () async {
                          await Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (
                                context,
                                animation,
                                secondaryAnimation,
                              ) => FacilityDetailScreen(facility: item),
                              transitionDuration: const Duration(
                                milliseconds: 250,
                              ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                            ),
                          );
                          _loadFacilities();
                        },
                        onEdit: () async {
                          final res = await Navigator.of(context).push<dynamic>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditFacilityScreen(facility: item),
                            ),
                          );
                          if (res == true || res == 'deleted') {
                            _loadFacilities();
                          }
                        },
                        onDelete: () => _confirmDeleteFacility(item),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.facilityHeaderGradient,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tiêu đề và nút Add Facility
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Facilities',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        height: 36 / 27,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage your badminton venues',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFBFE8D9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.white, size: 22),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<dynamic>(
                      MaterialPageRoute(
                        builder: (_) => const AddEditFacilityScreen(),
                      ),
                    );
                    if (res == true) {
                      _loadFacilities();
                    }
                  },
                ),
              ),
            ],
          ),

          // Search (279 x 48 px) & Filter (48 x 48 px)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.plusJakartaSans(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search facilities...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.tune,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFacility(FacilityCardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa cơ sở?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${item.name}"? Toàn bộ sân con và khung giờ thuộc cơ sở này sẽ bị xóa vĩnh viễn.',
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
      final result = await FacilityService.instance.deleteFacility(item.id);
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa cơ sở thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
        _loadFacilities();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'Không thể xóa cơ sở. Vui lòng thử lại sau.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBottomNavigation() => DashboardBottomNavigation(
    palette: const DashboardPalette(DashboardRole.owner),
    index: 1,
    onChanged: (index) {
      if (index == 1) return;
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(index);
        return;
      }
      Navigator.of(context).pushReplacement(
        AppMotion.route(
          DashboardScreen(role: DashboardRole.owner, initialTab: index),
        ),
      );
    },
  );
}
