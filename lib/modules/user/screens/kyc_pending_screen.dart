import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';

/// Màn hình Trạng thái Hồ sơ eKYC Đang Xét Duyệt (KYC Pending Screen)
/// Hiển thị khi Đối tác Tài xế nộp hồ sơ và đang chờ Admin thẩm định (Task 4.3)
class KycPendingScreen extends StatefulWidget {
  final String? plateNumber;

  const KycPendingScreen({
    super.key,
    this.plateNumber,
  });

  @override
  State<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends State<KycPendingScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return;

    AppLogger.userAction('KycPending', 'Bấm Kiểm tra lại trạng thái xét duyệt', {'uid': uid});
    setState(() => _isChecking = true);

    final driver = await UserService.instance.getDriverProfile(uid);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (driver == null) {
      AppLogger.ekyc('Kiểm tra duyệt', 'Chưa có hồ sơ', 'UID: $uid');
      AppDialogs.showError(
        context,
        title: 'Chưa Có Hồ Sơ',
        message: 'Hệ thống chưa tìm thấy hồ sơ đăng ký tài xế của bạn.',
      );
      return;
    }

    AppLogger.ekyc('Kiểm tra duyệt', 'Kết quả: ${driver.status.name}', 'UID: $uid');

    if (driver.status == DriverApprovalStatus.active) {
      AppDialogs.showSuccess(
        context,
        title: 'Đã Được Phê Duyệt!',
        message: 'Chúc mừng! Hồ sơ đối tác tài xế của bạn đã được Ban Quản trị phê duyệt thành công.',
        buttonText: 'Vào Bàn Cờ Tài Xế',
        onConfirmed: () {
          AppLogger.navigation('KycPending', 'DriverDashboard');
          Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
        },
      );
    } else if (driver.status == DriverApprovalStatus.banned) {
      AppDialogs.showError(
        context,
        title: 'Hồ Sơ Bị Từ Chối',
        message: 'Hồ sơ của bạn đã bị từ chối hoặc tài khoản bị tạm khóa. Vui lòng liên hệ bộ phận hỗ trợ JetPost để được giải đáp.',
      );
    } else {
      AppDialogs.showConfirm(
        context,
        title: 'Đang Trong Quá Trình Xét Duyệt',
        message: 'Hồ sơ của bạn vẫn đang được Admin đối soát hình ảnh CCCD và Bằng lái xe. Kết quả sẽ được cập nhật sớm, vui lòng quay lại kiểm tra sau!',
        confirmText: 'Đã hiểu',
        cancelText: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng Thái Hồ Sơ eKYC'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Biểu tượng Đồng hồ cát / Đang duyệt
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 50,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Hồ Sơ Đang Chờ Thẩm Định',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'JetPost đã tiếp nhận hồ sơ đăng ký Đối tác Tài xế của bạn. Ban Quản trị (Admin) đang tiến hành đối soát hình ảnh CCCD và Bằng lái xe trên Cloudinary.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 28),

              // Thẻ Tóm tắt Hồ sơ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trạng thái hồ sơ:', style: TextStyle(fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pending, size: 14, color: Color(0xFFE65100)),
                              SizedBox(width: 4),
                              Text(
                                'Đang xét duyệt',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.plateNumber != null) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Biển số đăng ký:', style: TextStyle(fontSize: 13)),
                          Text(
                            widget.plateNumber!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Nút kiểm tra lại trạng thái
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkStatus,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isChecking ? 'Đang kiểm tra...' : 'Kiểm tra trạng thái xét duyệt'),
                ),
              ),
              const SizedBox(height: 12),

              // Nút quay về Welcome Gate
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.welcomeGate,
                      (route) => false,
                    );
                  },
                  child: const Text('Quay về Màn hình Cổng vào'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
