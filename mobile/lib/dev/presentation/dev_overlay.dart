import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/services/auth_service.dart';
import 'dev_screen_explorer.dart';
import 'dev_testing_hub.dart';

/// Lớp phủ toàn cục (Global Dev Overlay) hoạt động vĩnh viễn xuyên suốt Developer Mode.
/// Nút nổi [ 🛠 Dev Hub ] luôn luôn hiển thị và có thể kéo thả tự do trên mọi màn hình,
/// không bao giờ bị biến mất khi chuyển trang, đổi tab hay đăng xuất.
class DevGlobalOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navKey;

  const DevGlobalOverlay({
    super.key,
    required this.child,
    required this.navKey,
  });

  @override
  State<DevGlobalOverlay> createState() => _DevGlobalOverlayState();
}

class _DevGlobalOverlayState extends State<DevGlobalOverlay> {
  // Vị trí mặc định góc trên bên phải để không che logo/tiêu đề
  Offset _position = const Offset(16, 60);

  void _showDevMenu() {
    final navContext = widget.navKey.currentContext ?? context;
    final user = AuthService.instance.currentUser;
    final email = user?['email'] ?? 'Chưa đăng nhập (Khách)';
    final role = user?['role'] ?? 'GUEST';

    showModalBottomSheet(
      context: navContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.developer_mode_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'S-Match Dev Quick Bar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$email ($role)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.hub_rounded, color: AppColors.primary),
                  title: const Text('Quay lại Developer Testing Hub'),
                  subtitle: const Text('Trở về trung tâm kiểm thử & danh sách tài khoản'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.navKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DevTestingHub()),
                      (route) => false,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.explore_rounded, color: Colors.blueGrey),
                  title: const Text('Mở Screen Explorer'),
                  subtitle: const Text('Khám phá và mở hơn 20 màn hình hệ thống'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.navKey.currentState?.push(
                      MaterialPageRoute(builder: (_) => const DevScreenExplorer()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.switch_account_rounded, color: Colors.teal),
                  title: const Text('Đổi tài khoản nhanh'),
                  subtitle: const Text('Chọn tài khoản Player / Owner / Admin'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.navKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const DevTestingHub()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Toàn bộ ứng dụng và cây Navigation
        widget.child,

        // 2. Nút nổi kéo thả luôn luôn hiển thị vĩnh viễn trên mọi màn hình
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: SafeArea(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                });
              },
              onTap: _showDevMenu,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withOpacity(0.95),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.build_circle_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Dev Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Giữ lại DevOverlayWrapper cho tính tương thích ngược với các builder màn hình
class DevOverlayWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onReturnToHub;
  final VoidCallback? onSwitchAccount;
  final VoidCallback? onOpenScreenExplorer;

  const DevOverlayWrapper({
    super.key,
    required this.child,
    this.onReturnToHub,
    this.onSwitchAccount,
    this.onOpenScreenExplorer,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
