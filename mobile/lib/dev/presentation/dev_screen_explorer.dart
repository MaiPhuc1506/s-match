import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Screens imports - Auth
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/create_account_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/player_welcome_screen.dart';
import '../../features/auth/screens/court_owner_welcome_screen.dart';
import '../../features/auth/screens/admin_welcome_screen.dart';
import '../../features/auth/screens/player_profile_screen.dart';
import '../../features/auth/screens/edit_profile_screen.dart';
import '../../features/auth/screens/skill_assessment_screen.dart';
import '../../features/auth/screens/match_preferences_screen.dart';

// Screens imports - Court Map (Sprint 6)
import '../../features/court_map/screens/find_courts_map_screen.dart';
import '../../features/court_map/screens/court_preview_screen.dart';
import '../../features/court_map/screens/find_players_map_screen.dart';
import '../../features/recommendation/data/recommendation_fixtures.dart';
import '../../features/recommendation/screens/recommendation_list_screen.dart';
import '../../features/recommendation/screens/recommended_player_detail_screen.dart';
import '../../features/recommendation/screens/no_recommendations_screen.dart';

// Screens imports - Facility
import '../../features/facility/screens/facility_list_screen.dart';
import '../../features/facility/screens/facility_detail_screen.dart';
import '../../features/facility/screens/add_edit_court_screen.dart';
import '../../features/facility/screens/add_edit_facility_screen.dart';
import '../../features/facility/screens/operating_hours_screen.dart';
import '../../features/facility/widgets/facility_card.dart';

// Screens imports - Booking
import '../../features/booking/screens/booking_facility_schedule_screen.dart';
import '../../features/booking/screens/booking_flow_screen.dart';
import '../../features/booking/screens/booking_summary_screen.dart';
import '../../features/booking/screens/booking_history_screen.dart';
import '../../features/booking/screens/booking_success_screen.dart';
import '../../features/booking/screens/booking_detail_screen.dart';

// Screens imports - Match
import '../../features/match/screens/match_list_screen.dart';
import '../../features/match/screens/create_match_screen.dart';
import '../../features/match/screens/match_detail_open_screen.dart';
import '../../features/match/screens/match_invitations_screen.dart';
import '../../features/match/screens/match_join_requests_screen.dart';
import '../../features/match/screens/match_participant_list_screen.dart';
import '../../features/match/models/match_model.dart';

class _DevScreenItem {
  final String title;
  final String category;
  final String description;
  final Widget Function(BuildContext) builder;

  const _DevScreenItem({
    required this.title,
    required this.category,
    required this.description,
    required this.builder,
  });
}

class DevScreenExplorer extends StatefulWidget {
  const DevScreenExplorer({super.key});

  @override
  State<DevScreenExplorer> createState() => _DevScreenExplorerState();
}

class _DevScreenExplorerState extends State<DevScreenExplorer> {
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';

  late final List<_DevScreenItem> _allScreens = [
    // --- 1. AUTHENTICATION & ONBOARDING ---
    _DevScreenItem(
      title: 'Splash Screen',
      category: 'Auth',
      description: 'Màn hình khởi động logo S-Match và kiểm tra trạng thái đăng nhập',
      builder: (ctx) => const SplashScreen(),
    ),
    _DevScreenItem(
      title: 'Login Screen',
      category: 'Auth',
      description: 'Đăng nhập người dùng bằng email và mật khẩu',
      builder: (ctx) => const LoginScreen(),
    ),
    _DevScreenItem(
      title: 'Create Account Screen',
      category: 'Auth',
      description: 'Đăng ký tài khoản mới cho người chơi S-Match',
      builder: (ctx) => const CreateAccountScreen(),
    ),
    _DevScreenItem(
      title: 'Forgot Password Screen',
      category: 'Auth',
      description: 'Quên mật khẩu và gửi mã xác thực khôi phục',
      builder: (ctx) => const ForgotPasswordScreen(),
    ),
    _DevScreenItem(
      title: 'Player Welcome Screen',
      category: 'Auth',
      description: 'Màn hình chào mừng dành cho Player sau khi đăng nhập',
      builder: (ctx) => const PlayerWelcomeScreen(),
    ),
    _DevScreenItem(
      title: 'Court Owner Welcome Screen',
      category: 'Auth',
      description: 'Màn hình chào mừng dành cho Court Owner (Chủ sân)',
      builder: (ctx) => const CourtOwnerWelcomeScreen(),
    ),
    _DevScreenItem(
      title: 'Admin Welcome Screen',
      category: 'Auth',
      description: 'Màn hình chào mừng dành cho Quản trị viên (Admin)',
      builder: (ctx) => const AdminWelcomeScreen(),
    ),

    // --- 2. PROFILE & PREFERENCES ---
    _DevScreenItem(
      title: 'Player Profile Screen',
      category: 'Profile',
      description: 'Hồ sơ người chơi, thông tin chỉ số kỹ năng và nút đăng xuất',
      builder: (ctx) => const PlayerProfileScreen(),
    ),
    _DevScreenItem(
      title: 'Edit Profile Screen',
      category: 'Profile',
      description: 'Chỉnh sửa thông tin cá nhân người chơi',
      builder: (ctx) => const EditProfileScreen(),
    ),
    _DevScreenItem(
      title: 'Skill Assessment Screen',
      category: 'Profile',
      description: 'Đánh giá kỹ năng đập, thủ, phản xạ của người chơi',
      builder: (ctx) => const SkillAssessmentScreen(),
    ),
    _DevScreenItem(
      title: 'Match Preferences Screen',
      category: 'Profile',
      description: 'Cài đặt sở thích ghép trận, khoảng cách và thời gian rảnh',
      builder: (ctx) => const MatchPreferencesScreen(),
    ),

    // --- 3. MAP EXPLORATION (SPRINT 6) ---
    _DevScreenItem(
      title: 'Find Courts Map Screen',
      category: 'Court Map',
      description: 'Bản đồ khám phá cụm sân cầu lông theo vị trí',
      builder: (ctx) => const FindCourtsMapScreen(),
    ),
    _DevScreenItem(
      title: 'Court Preview Screen',
      category: 'Court Map',
      description: 'Xem trước hình ảnh và tiện ích của sân cầu lông',
      builder: (ctx) => const CourtPreviewScreen(),
    ),
    _DevScreenItem(
      title: 'Find Players Map Screen',
      category: 'Court Map',
      description: 'Bản đồ tìm kiếm người chơi xung quanh khu vực',
      builder: (ctx) => const FindPlayersMapScreen(),
    ),

    // --- SPRINT 7: RECOMMENDATION MOBILE (PLAYER UI PREVIEW) ---
    _DevScreenItem(
      title: 'Recommendation List Screen',
      category: 'Recommendation',
      description: 'Sprint 7 · Player · Danh sách gợi ý và điểm tương thích (UI preview)',
      builder: (ctx) => const RecommendationListScreen(),
    ),
    _DevScreenItem(
      title: 'Recommended Player Detail Screen',
      category: 'Recommendation',
      description: 'Sprint 7 · Player · Hồ sơ, Compatibility và Skill Radar (UI preview)',
      builder: (ctx) => RecommendedPlayerDetailScreen(
        player: referenceRecommendations.first,
      ),
    ),
    _DevScreenItem(
      title: 'No Recommendations Screen',
      category: 'Recommendation',
      description: 'Sprint 7 · Player · Trạng thái không có gợi ý (UI preview)',
      builder: (ctx) => const NoRecommendationsScreen(),
    ),

    // --- 4. FACILITY & COURT MANAGEMENT ---
    _DevScreenItem(
      title: 'Facility List Screen',
      category: 'Facility',
      description: 'Danh sách các cơ sở sân thuộc quyền quản lý của chủ sân',
      builder: (ctx) => const FacilityListScreen(),
    ),
    _DevScreenItem(
      title: 'Facility Detail Screen (Preview)',
      category: 'Facility',
      description: 'Chi tiết cụm sân, danh sách sân đơn/đôi và lịch ma trận slot',
      builder: (ctx) => const FacilityDetailScreen(
        facility: FacilityCardItem(
          id: 1,
          name: 'Sân Cầu Lông Sky Badminton (Test Fixture)',
          address: '123 Le Van Viet, D9, TP.HCM',
          courtCount: 4,
          operatingHours: '06:00 - 22:00',
          isOpen: true,
        ),
      ),
    ),
    _DevScreenItem(
      title: 'Add / Edit Facility Screen',
      category: 'Facility',
      description: 'Thêm mới hoặc chỉnh sửa cơ sở / cụm sân thể thao',
      builder: (ctx) => const AddEditFacilityScreen(),
    ),
    _DevScreenItem(
      title: 'Add / Edit Court Screen',
      category: 'Facility',
      description: 'Thêm mới hoặc chỉnh sửa sân thuộc cơ sở',
      builder: (ctx) => const AddEditCourtScreen(facilityId: 1),
    ),
    _DevScreenItem(
      title: 'Operating Hours Screen',
      category: 'Facility',
      description: 'Cấu hình khung giờ mở cửa trong tuần cho cơ sở',
      builder: (ctx) => const OperatingHoursScreen(facilityId: 1),
    ),

    // --- 5. BOOKING FLOW ---
    _DevScreenItem(
      title: 'Booking Flow Screen',
      category: 'Booking',
      description: 'Quy trình đặt sân hoàn chỉnh từ chọn sân đến thanh toán',
      builder: (ctx) => const BookingFlowScreen(),
    ),
    _DevScreenItem(
      title: 'Booking Facility Schedule',
      category: 'Booking',
      description: 'Xem lịch trống theo ngày và chọn khung giờ đặt sân',
      builder: (ctx) => const BookingFacilityScheduleScreen(),
    ),
    _DevScreenItem(
      title: 'Booking Summary Screen',
      category: 'Booking',
      description: 'Xem lại thông tin và xác nhận chi phí đặt sân',
      builder: (ctx) => const BookingSummaryScreen(),
    ),
    _DevScreenItem(
      title: 'Booking Success Screen',
      category: 'Booking',
      description: 'Thông báo đặt sân thành công với pháo hoa confetti',
      builder: (ctx) => const BookingSuccessScreen(),
    ),
    _DevScreenItem(
      title: 'Booking Detail Screen',
      category: 'Booking',
      description: 'Chi tiết đơn đặt sân, mã QR và trạng thái đơn',
      builder: (ctx) => const BookingDetailScreen(),
    ),
    _DevScreenItem(
      title: 'Booking History Screen',
      category: 'Booking',
      description: 'Lịch sử đặt sân: Sắp diễn ra, Hoàn thành, Đã hủy',
      builder: (ctx) => const BookingHistoryScreen(),
    ),

    // --- 6. MATCH ORGANIZATION ---
    _DevScreenItem(
      title: 'Match List Screen',
      category: 'Match',
      description: 'Danh sách các trận đấu công khai và trận của tôi',
      builder: (ctx) => const MatchListScreen(),
    ),
    _DevScreenItem(
      title: 'Create Match Screen (Public/Private)',
      category: 'Match',
      description: 'Tạo trận đấu mới: Open Match hoặc Private Match',
      builder: (ctx) => const CreateMatchScreen(),
    ),
    _DevScreenItem(
      title: 'Match Detail Open Screen',
      category: 'Match',
      description: 'Chi tiết trận đấu mở: Danh sách người tham gia & nút tham gia',
      builder: (ctx) => MatchDetailOpenScreen(
        match: kVerifiedMatches[0],
      ),
    ),
    _DevScreenItem(
      title: 'Match Invitations Screen',
      category: 'Match',
      description: 'Danh sách lời mời tham gia trận đấu từ bạn bè',
      builder: (ctx) => const MatchInvitationsScreen(),
    ),
    _DevScreenItem(
      title: 'Match Join Requests Screen',
      category: 'Match',
      description: 'Quản lý yêu cầu xin tham gia trận đấu riêng tư',
      builder: (ctx) => const MatchJoinRequestsScreen(),
    ),
    _DevScreenItem(
      title: 'Match Participant List Screen',
      category: 'Match',
      description: 'Danh sách chi tiết các vận động viên tham gia trận đấu',
      builder: (ctx) => MatchParticipantListScreen(
        match: kVerifiedMatches[0],
      ),
    ),
  ];

  List<String> get _categories {
    final set = <String>{'Tất cả'};
    for (final s in _allScreens) {
      set.add(s.category);
    }
    return set.toList();
  }

  List<_DevScreenItem> get _filteredScreens {
    return _allScreens.where((screen) {
      final matchesCat =
          _selectedCategory == 'Tất cả' || screen.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          screen.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          screen.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          screen.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();
  }

  void _navigateToScreen(_DevScreenItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => item.builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredScreens;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        title: const Text(
          'Screen Explorer',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allScreens.length} Màn hình',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm màn hình (VD: Match, Booking, Map...)',
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF2F4F3),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // Category Chips
          Container(
            height: 48,
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFF0F4F2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Screen List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy màn hình nào phù hợp',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final screen = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _navigateToScreen(screen),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(screen.category),
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              screen.title,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              screen.category,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        screen.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Auth':
        return Icons.lock_outline_rounded;
      case 'Profile':
        return Icons.person_outline_rounded;
      case 'Court Map':
        return Icons.map_outlined;
      case 'Facility':
        return Icons.storefront_outlined;
      case 'Booking':
        return Icons.calendar_month_outlined;
      case 'Match':
        return Icons.sports_tennis_rounded;
      case 'Recommendation':
        return Icons.people_outline_rounded;
      default:
        return Icons.widgets_outlined;
    }
  }
}
