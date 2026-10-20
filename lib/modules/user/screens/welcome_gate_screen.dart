import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// Màn hình Cổng vào Hợp nhất (UI Entry Point Gate) & Demo Role Switcher
/// Cho phép điều phối vào 4 phân hệ độc lập và kiểm thử trực tiếp trước Hội đồng
class WelcomeGateScreen extends StatefulWidget {
  const WelcomeGateScreen({super.key});

  @override
  State<WelcomeGateScreen> createState() => _WelcomeGateScreenState();
}

class _WelcomeGateScreenState extends State<WelcomeGateScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Firebase Cloud Connected',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                  _showModuleNotice(context, 'Phân hệ 1: Khách hàng', 'Thành viên 1 sẽ lập trình giao diện đặt xe tại: lib/modules/customer/');
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
                  _showModuleNotice(context, 'Phân hệ 2: Đối tác Tài xế', 'Nguyễn Văn Hải sẽ lập trình giao diện chạy xe tại: lib/modules/driver/');
                },
              ),

              const SizedBox(height: 14),

              // 3. Cổng User & eKYC (Module 3)
              _buildRoleCard(
                context,
                title: 'Tài Khoản & Định Danh eKYC',
                subtitle: 'Xác thực SMS OTP, nộp CCCD/bằng lái & Chat P2P trực tiếp',
                badgeText: 'Thành viên 3',
                color: const Color(0xFF7B1FA2),
                icon: Icons.verified_user,
                onTap: () {
                  _showModuleNotice(context, 'Phân hệ 3: User & Định danh', 'Thành viên 3 sẽ lập trình xác thực OTP tại: lib/modules/user/');
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
                  _showModuleNotice(context, 'Phân hệ 4: Quản trị Admin', 'Thành viên 4 sẽ lập trình radar điều hành tại: lib/modules/admin/');
                },
              ),

              const SizedBox(height: 24),

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
                        'Hạ tầng 9 thực thể CSDL & Core Services đã sẵn sàng hoạt động!',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
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

  void _showModuleNotice(BuildContext context, String moduleName, String detail) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                moduleName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                detail,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
