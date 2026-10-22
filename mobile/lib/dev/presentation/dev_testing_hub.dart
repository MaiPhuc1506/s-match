import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/screens/admin_welcome_screen.dart';
import '../../features/auth/screens/court_owner_welcome_screen.dart';
import '../../features/auth/screens/player_profile_screen.dart';
import '../../features/auth/services/auth_service.dart';
import '../data/dev_saved_accounts_repository.dart';
import 'dev_account_selector.dart';
import 'dev_screen_explorer.dart';

/// Màn hình chính của Developer Testing Hub dành cho chế độ kiểm thử (Developer Mode).
class DevTestingHub extends StatefulWidget {
  const DevTestingHub({super.key});

  @override
  State<DevTestingHub> createState() => _DevTestingHubState();
}

class _DevTestingHubState extends State<DevTestingHub> {
  final _repo = DevSavedAccountsRepository.instance;
  final _auth = AuthService.instance;
  final _client = ApiClient.instance;

  List<DevAccount> _accounts = [];
  bool _isLoadingAccounts = true;
  String? _backendPingStatus;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _checkBackendHealth();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoadingAccounts = true);
    final list = await _repo.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = list;
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _checkBackendHealth() async {
    try {
      final res = await _client.dio.get('/');
      if (mounted) {
        setState(() {
          _backendPingStatus = res.statusCode == 200 ? 'Online (200)' : 'Status ${res.statusCode}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendPingStatus = 'Disconnected / Not Reachable';
        });
      }
    }
  }

  /// Thực hiện quy trình đăng nhập:
  /// 1. Thu hồi và dọn dẹp sạch phiên cũ (tokens, user state)
  /// 2. Đăng nhập tài khoản mới qua backend API
  /// 3. Cập nhật metadata tài khoản
  Future<bool> _handleLogin(String email, String password) async {
    try {
      // 1. Dọn dẹp phiên trước đó để không lẫn cache/tokens
      await _auth.logout();

      // 2. Gọi API đăng nhập backend thực tế
      final result = await _auth.login(email: email, password: password);

      if (!result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Đăng nhập thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Đánh dấu tài khoản vừa được dùng
      final matched = _accounts.where((a) => a.email.toLowerCase() == email.toLowerCase());
      if (matched.isNotEmpty) {
        await _repo.markAccountUsed(matched.first.id);
        await _loadAccounts();
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi ngoại lệ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Điều hướng sang màn hình tương ứng với vai trò sau khi dialog đã đóng hoàn toàn
  void _navigateToRoleScreen(String roleStr) {
    if (!mounted) return;
    final role = roleStr.toUpperCase();

    Widget targetScreen;
    if (role == 'COURT_OWNER' || role == 'COURT OWNER') {
      targetScreen = const CourtOwnerWelcomeScreen();
    } else if (role == 'ADMIN') {
      targetScreen = const AdminWelcomeScreen();
    } else {
      // Player: Chuyển thẳng sang PlayerProfileScreen để test thông tin & nút Đăng xuất
      targetScreen = const PlayerProfileScreen();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => targetScreen),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _triggerLoginForAccount(DevAccount account) {
    DevAccountSelector.showQuickLoginDialog(
      context: context,
      account: account,
      onLogin: (email, pass) => _handleLogin(email, pass),
      onSuccess: (role) => _navigateToRoleScreen(role),
    );
  }

  void _triggerQuickRoleLogin(String role) {
    final candidate = _accounts.firstWhere(
      (a) => a.role.toUpperCase() == role.toUpperCase(),
      orElse: () => DevAccount(
        id: 'temp',
        label: role,
        email: role == 'COURT_OWNER'
            ? 'owner@smatch.dev'
            : role == 'ADMIN'
                ? 'admin@smatch.dev'
                : 'player@smatch.dev',
        role: role,
      ),
    );
    _triggerLoginForAccount(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final currentToken = _client.token;
    final currentEmail = currentUser?['email'] as String?;
    final currentRole = currentUser?['role'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
                  await _loadAccounts();
                  await _checkBackendHealth();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HEADER ---
                      _buildHeader(currentEmail, currentRole, currentToken),
                      const SizedBox(height: 24),

                      // --- SECTION 1: QUICK LOGIN ---
                      _buildSectionTitle('1. Quick Login (Đăng nhập theo vai trò)'),
                      const SizedBox(height: 12),
                      _buildRoleCards(),
                      const SizedBox(height: 24),

                      // --- SECTION 2: SAVED ACCOUNTS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle('2. Saved Test Accounts'),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Thêm tài khoản'),
                            onPressed: () {
                              DevAccountSelector.showAddEditAccountDialog(
                                context: context,
                                onSave: (acc) async {
                                  await _repo.saveAccount(acc);
                                  await _loadAccounts();
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSavedAccountsList(currentEmail),
                      const SizedBox(height: 24),

                      // --- SECTION 3: SCREEN EXPLORER ENTRY ---
                      _buildSectionTitle('3. Screen Explorer (Khám phá toàn bộ màn hình)'),
                      const SizedBox(height: 12),
                      _buildScreenExplorerCard(),
                      const SizedBox(height: 24),

                      // --- SECTION 4: TEST SETTINGS & UTILITIES ---
                      _buildSectionTitle('4. Test Settings & Utilities'),
                      const SizedBox(height: 12),
                      _buildTestSettings(currentToken),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(String? currentEmail, String? currentRole, String? currentToken) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S-Match Developer Hub',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Development & Multi-account Testing Utility',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Backend indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _backendPingStatus != null &&
                          _backendPingStatus!.contains('Online')
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Backend: ${_client.dio.options.baseUrl} (${_backendPingStatus ?? "Checking..."})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Active Session indicator
          Row(
            children: [
              Icon(
                currentToken != null
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 14,
                color: currentToken != null ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentToken != null
                      ? 'Phiên hiện tại: $currentEmail ($currentRole)'
                      : 'Chưa có phiên đăng nhập nào đang hoạt động',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: currentToken != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: currentToken != null
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildRoleCards() {
    return Row(
      children: [
        Expanded(
          child: _buildRoleCard(
            label: 'Player',
            roleId: 'PLAYER',
            icon: Icons.sports_tennis_rounded,
            color: const Color(0xFF05644F),
            accountSeed: 'player@smatch.dev',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildRoleCard(
            label: 'Court Owner',
            roleId: 'COURT_OWNER',
            icon: Icons.storefront_rounded,
            color: const Color(0xFF03634D),
            accountSeed: 'owner@smatch.dev',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildRoleCard(
            label: 'Admin',
            roleId: 'ADMIN',
            icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFF914A45),
            accountSeed: 'admin@smatch.dev',
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String label,
    required String roleId,
    required IconData icon,
    required Color color,
    required String accountSeed,
  }) {
    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _triggerQuickRoleLogin(roleId),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                accountSeed,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAccountsList(String? currentEmail) {
    if (_isLoadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'Chưa có tài khoản test nào được lưu. Bấm "Thêm tài khoản" ở trên.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _accounts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final acc = _accounts[index];
        final isActive = currentEmail != null &&
            currentEmail.toLowerCase() == acc.email.toLowerCase();

        return Card(
          elevation: 0.5,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive ? AppColors.primary : Colors.grey.shade200,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getRoleColor(acc.role).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      acc.label.isNotEmpty ? acc.label[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(acc.role),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              acc.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(acc.role).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              acc.role,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(acc.role),
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        acc.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (acc.note != null && acc.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          acc.note!,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flash_on_rounded, color: AppColors.primary),
                      tooltip: 'Đăng nhập',
                      onPressed: () => _triggerLoginForAccount(acc),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (val) async {
                        if (val == 'rename') {
                          DevAccountSelector.showRenameDialog(
                            context: context,
                            account: acc,
                            onRename: (newLabel) async {
                              await _repo.renameAccount(acc.id, newLabel);
                              await _loadAccounts();
                            },
                          );
                        } else if (val == 'delete') {
                          DevAccountSelector.showConfirmDeleteDialog(
                            context: context,
                            account: acc,
                            onDelete: () async {
                              await _repo.removeAccount(acc.id);
                              await _loadAccounts();
                            },
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Đổi tên'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa tài khoản', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreenExplorerCard() {
    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DevScreenExplorer()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mở Screen Explorer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Khám phá hơn 20 màn hình: Auth, Map, Facility, Booking, Match...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestSettings(String? currentToken) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            title: const Text('Kiểm tra kết nối Backend (Ping)'),
            subtitle: Text('Status: ${_backendPingStatus ?? "Chưa kiểm tra"}'),
            trailing: IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: _checkBackendHealth,
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Colors.orange),
            title: const Text('Đăng xuất phiên hiện tại'),
            subtitle: const Text('Xóa token và hủy phiên làm việc ở backend'),
            enabled: currentToken != null,
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
                foregroundColor: Colors.orange.shade900,
                elevation: 0,
              ),
              onPressed: currentToken == null
                  ? null
                  : () async {
                      await _auth.logout();
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã xóa sạch phiên hiện tại')),
                        );
                      }
                    },
              child: const Text('Đăng xuất'),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_rounded, color: Colors.blueGrey),
            title: const Text('Khôi phục danh sách seed mặc định'),
            subtitle: const Text('Phục hồi 4 tài khoản mẫu: Player 1, 2, Owner, Admin'),
            trailing: TextButton(
              onPressed: () async {
                await _repo.resetToDefaults();
                await _loadAccounts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã khôi phục danh sách tài khoản seed')),
                  );
                }
              },
              child: const Text('Khôi phục'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'COURT_OWNER':
        return const Color(0xFF03634D);
      case 'ADMIN':
        return const Color(0xFF914A45);
      case 'PLAYER':
      default:
        return const Color(0xFF05644F);
    }
  }
}

