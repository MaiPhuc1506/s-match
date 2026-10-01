import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';
import '../widgets/facility_card.dart';
import 'facility_detail_screen.dart';

class FacilityListScreen extends StatefulWidget {
  const FacilityListScreen({super.key});

  @override
  State<FacilityListScreen> createState() => _FacilityListScreenState();
}

class _FacilityListScreenState extends State<FacilityListScreen> {
  int _currentNavIndex = 1; // Tab Facilities đang active

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
          );
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Nội dung cuộn chính
          SingleChildScrollView(
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
                        const CircularProgressIndicator()
                      else if (_loadFailed)
                        TextButton(
                          onPressed: _loadFacilities,
                          child: const Text(
                            'Không tải được cơ sở. Nhấn để thử lại.',
                          ),
                        )
                      else if (_facilities.isEmpty)
                        const Text('Bạn chưa có cơ sở nào.'),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Khoảng đệm dưới cho bottom navigation
                const SizedBox(height: 100),
              ],
            ),
          ),

          // 3. Bottom Navigation cố định dưới đáy (393 x 80 px)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigation(),
          ),
        ],
      ),
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
              Column(
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: AppColors.white, size: 22),
                  onPressed: () {
                    // Mở dialog hoặc điều hướng thêm cơ sở
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

  Widget _buildBottomNavigation() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, 'Home'),
          _buildNavItem(1, Icons.domain, 'Facilities'),
          _buildNavItem(2, Icons.calendar_today_outlined, 'Bookings'),
          _buildNavItem(3, Icons.chat_bubble_outline, 'Messages'),
          _buildNavItem(4, Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
