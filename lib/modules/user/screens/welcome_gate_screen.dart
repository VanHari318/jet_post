import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';
import 'kyc_pending_screen.dart';
import 'phone_auth_screen.dart';

/// Màn hình Cổng vào Hợp nhất (UI Entry Point Gate) & Demo Role Switcher
/// Cho phép điều phối vào 4 phân hệ độc lập và kiểm thử trực tiếp trước Hội đồng
class WelcomeGateScreen extends StatefulWidget {
  const WelcomeGateScreen({super.key});

  @override
  State<WelcomeGateScreen> createState() => _WelcomeGateScreenState();
}

class _WelcomeGateScreenState extends State<WelcomeGateScreen> {
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    AppLogger.navigation('AppStartup', 'WelcomeGateScreen');
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = await UserService.instance.checkAutoLogin();
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _isLoadingUser = false;
    });
  }

  void _navigateToRole(String roleRoute, UserRole requiredRole) {
    AppLogger.userAction('WelcomeGate', 'Chạm chọn Phân hệ', {
      'role': requiredRole.toFirestore(),
      'route': roleRoute,
      'isLoggedIn': _currentUser != null,
    });

    if (_currentUser == null) {
      AppLogger.navigation('WelcomeGate', 'PhoneAuthScreen', {'targetRole': requiredRole.name});
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhoneAuthScreen(targetRole: requiredRole),
        ),
      ).then((_) => _checkSession());
      return;
    }

    if (requiredRole == UserRole.driver) {
      _handleDriverEntry();
      return;
    }

    if (requiredRole == UserRole.admin && _currentUser!.role != UserRole.admin) {
      AppLogger.auth('Từ chối truy cập Cổng Admin: Người dùng không có quyền admin', {
        'currentRole': _currentUser!.role.toFirestore(),
      });
      _showNoticeDialog(
        title: 'Quyền Quản Trị Viên',
        message: 'Tài khoản của bạn hiện là ${_currentUser!.role.toFirestore()}. Bạn cần đăng nhập bằng tài khoản Admin để truy cập.',
      );
      return;
    }

    AppLogger.navigation('WelcomeGate', roleRoute);
    Navigator.pushNamed(context, roleRoute);
  }

  Future<void> _handleDriverEntry() async {
    final driver = await UserService.instance.getDriverProfile(_currentUser!.id);

    if (!mounted) return;

    if (driver == null) {
      // Chưa đăng ký eKYC
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Đăng Ký Đối Tác Tài Xế'),
          content: const Text(
            'Bạn chưa hoàn thành hồ sơ định danh điện tử eKYC. Bạn có muốn nộp hồ sơ bằng lái và CCCD ngay bây giờ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.driverKyc);
              },
              child: const Text('Đăng ký ngay'),
            ),
          ],
        ),
      );
    } else if (driver.status == DriverApprovalStatus.pendingApproval) {
      Navigator.pushNamed(context, AppRoutes.kycPending);
    } else if (driver.status == DriverApprovalStatus.banned) {
      _showNoticeDialog(
        title: 'Tài Khoản Bị Khóa',
        message: 'Tài khoản đối tác của bạn đã bị tạm khóa do vi phạm quy chế hoạt động.',
      );
    } else {
      Navigator.pushNamed(context, AppRoutes.driverDashboard);
    }
  }

  void _showNoticeDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTapDriverEkyc() async {
    if (_currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PhoneAuthScreen(targetRole: UserRole.driver),
        ),
      ).then((_) => _checkSession());
      return;
    }
    // Kiểm tra trạng thái hồ sơ tài xế hiện có
    final driver = await UserService.instance.getDriverProfile(_currentUser!.id);
    if (!mounted) return;
    if (driver != null) {
      if (driver.status == DriverApprovalStatus.pendingApproval) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KycPendingScreen(plateNumber: driver.plateNumber),
          ),
        ).then((_) => _checkSession());
        return;
      } else if (driver.status == DriverApprovalStatus.active) {
        Navigator.pushNamed(context, AppRoutes.driverDashboard).then((_) => _checkSession());
        return;
      }
    }
    Navigator.pushNamed(context, AppRoutes.driverKyc).then((_) => _checkSession());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.electric_moped, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              AppStrings.appName,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          // Nút Hộp thư Chat P2P
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Tin nhắn P2P',
            onPressed: () {
              AppLogger.userAction('WelcomeGate', 'Chạm icon Tin nhắn P2P', {'isLoggedIn': _currentUser != null});
              if (_currentUser == null) {
                Navigator.pushNamed(context, AppRoutes.phoneAuth).then((_) => _checkSession());
              } else {
                Navigator.pushNamed(context, AppRoutes.messagesInbox);
              }
            },
          ),

          // Nút Cài đặt
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () {
              AppLogger.userAction('WelcomeGate', 'Chạm icon Cài đặt');
              Navigator.pushNamed(context, AppRoutes.appSettings);
            },
          ),

          // Avatar / Nút Đăng nhập
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isLoadingUser
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: () {
                      AppLogger.userAction('WelcomeGate', 'Chạm Avatar / Tài khoản', {'isLoggedIn': _currentUser != null});
                      if (_currentUser == null) {
                        Navigator.pushNamed(context, AppRoutes.phoneAuth).then((_) => _checkSession());
                      } else {
                        Navigator.pushNamed(context, AppRoutes.userProfile).then((_) => _checkSession());
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.primary.withAlpha(40),
                      backgroundImage: _currentUser?.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty
                          ? NetworkImage(
                              CloudinaryService.instance.getOptimizedUrl(
                                _currentUser!.avatarUrl!,
                                width: 80,
                                height: 80,
                              ),
                            )
                          : null,
                      child: _currentUser == null
                          ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                          : (_currentUser!.avatarUrl == null || _currentUser!.avatarUrl!.isEmpty)
                              ? Text(
                                  _currentUser!.fullName.isNotEmpty
                                      ? _currentUser!.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                )
                              : null,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner giới thiệu ứng dụng
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A86B), Color(0xFF007A4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_done, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _currentUser != null
                                  ? 'Đã đăng nhập: ${_currentUser!.fullName}'
                                  : 'Firebase & Cloudinary Sẵn Sàng',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hệ Thống Giao Vận JetPost',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nền tảng tích hợp Xe ôm công nghệ & Giao hàng hỏa tốc - Đồ án Chuyên đề CNTT Nhóm 14',
                      style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Row(
                children: [
                  const Icon(Icons.dashboard_customize, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'CỔNG TRUY CẬP 4 PHÂN HỆ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Cổng Khách hàng (Module 1)
              _buildRoleCard(
                context,
                title: 'Phân hệ Khách Hàng',
                subtitle: 'Đặt xe ôm di chuyển, tạo đơn gửi hàng & theo dõi hành trình',
                badgeText: 'Thành viên 1',
                color: const Color(0xFF00A86B),
                icon: Icons.person_pin_circle,
                onTap: () {
                  _navigateToRole(AppRoutes.customerHome, UserRole.customer);
                },
              ),

              const SizedBox(height: 14),

              // 2. Cổng Tài xế (Module 2)
              _buildRoleCard(
                context,
                title: 'Đối Tác Tài Xế JetPost',
                subtitle: 'Bật trực tuyến GPS, nhận cuốc 15s & xác nhận giao hàng PoD',
                badgeText: 'Thành viên 2 (Hải)',
                color: const Color(0xFFFF6B00),
                icon: Icons.two_wheeler,
                onTap: () {
                  _navigateToRole(AppRoutes.driverDashboard, UserRole.driver);
                },
              ),

              const SizedBox(height: 14),

              // 3. Cổng Hồ sơ & Bảo mật (Module 3)
              _buildRoleCard(
                context,
                title: 'Hồ Sơ & Bảo Mật Cá Nhân',
                subtitle: 'Xem thông tin, đổi ảnh đại diện, đổi SĐT & liên kết email',
                badgeText: 'Thành viên 3',
                color: const Color(0xFF7B1FA2),
                icon: Icons.manage_accounts_outlined,
                onTap: () {
                  if (_currentUser == null) {
                    Navigator.pushNamed(context, AppRoutes.phoneAuth).then((_) => _checkSession());
                  } else {
                    Navigator.pushNamed(context, AppRoutes.userProfile).then((_) => _checkSession());
                  }
                },
              ),

              const SizedBox(height: 14),

              // 4. Cổng Quản trị Admin (Module 4)
              _buildRoleCard(
                context,
                title: 'Quản Trị Điều Hành Hệ Thống',
                subtitle: 'Bàn cờ Radar toàn thành phố, thẩm định eKYC & cấu hình cước',
                badgeText: 'Thành viên 4',
                color: const Color(0xFF1E88E5),
                icon: Icons.admin_panel_settings,
                onTap: () {
                  _navigateToRole(AppRoutes.adminDashboard, UserRole.admin);
                },
              ),

              const SizedBox(height: 24),

              // Nút Đăng ký eKYC Tài Xế Nổi Bật (Nếu chưa đăng ký)
              if (_currentUser == null || _currentUser!.role != UserRole.driver) ...[
                InkWell(
                  onTap: _handleTapDriverEkyc,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFB300)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.badge_outlined, color: Color(0xFFE65100), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đăng Ký Gia Nhập Đối Tác Tài Xế (eKYC)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Chụp ảnh CCCD và Giấy phép lái xe gửi Admin xét duyệt',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFE65100)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward, size: 16, color: Color(0xFFE65100)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Trạng thái hệ thống phía dưới
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Phân hệ User: Phone Auth, eKYC Cloudinary & Chat P2P đã sẵn sàng!',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ],
        ),
      ),
    );
  }
}
