import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/delivery_model.dart';
import '../../../models/user_model.dart';
import '../../user/services/user_service.dart';
import '../services/customer_service.dart';
import 'order_detail_screen.dart';

/// Màn hình Tra Cứu Đơn Bưu Kiện Gửi Cho Tôi (Task 1.4 - Consignee Tracking)
/// Tự động lọc các đơn hàng có `receiverPhone` trùng với SĐT của khách hàng,
/// hiển thị Timeline bưu phẩm & Mã OTP 4 số bàn giao an toàn.
class ConsigneeTrackingScreen extends StatefulWidget {
  const ConsigneeTrackingScreen({super.key});

  @override
  State<ConsigneeTrackingScreen> createState() =>
      _ConsigneeTrackingScreenState();
}

class _ConsigneeTrackingScreenState extends State<ConsigneeTrackingScreen> {
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await UserService.instance.getUserProfile(uid);
    }
    if (mounted) {
      setState(() => _isLoadingUser = false);
    }
  }

  void _copyOtp(BuildContext context, String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép mã OTP: $otp'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    final phone = _currentUser?.phone ?? '';

    if (phone.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_missed_rounded,
                  size: 64, color: AppColors.secondary.withAlpha(120)),
              const SizedBox(height: 16),
              const Text(
                'Chưa Có Số Điện Thoại Nhận Hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tài khoản của bạn chưa liên kết số điện thoại. Vui lòng cập nhật số điện thoại trong Hồ sơ để tra cứu bưu phẩm gửi cho bạn!',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn Hàng Gửi Cho Tôi'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<DeliveryModel>>(
        stream: CustomerService.instance.streamConsigneeDeliveries(phone),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data ?? [];

          if (deliveries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: AppColors.secondary.withAlpha(120)),
                    const SizedBox(height: 16),
                    Text(
                      'Không có đơn hàng nào gửi cho bạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khi ai đó gửi bưu phẩm qua JetPost đến số điện thoại $phone của bạn, đơn hàng sẽ hiển thị tại đây kèm mã OTP nhận hàng!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: deliveries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return _buildConsigneeCard(context, delivery, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildConsigneeCard(
      BuildContext context, DeliveryModel delivery, bool isDark) {
    final isDelivering = delivery.status == DeliveryStatus.inTransit ||
        delivery.status == DeliveryStatus.pickedUp;
    final isCompleted = delivery.status == DeliveryStatus.completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Người gửi & Badge trạng thái
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Người gửi: ${delivery.senderName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Loại hàng: ${delivery.packageType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(delivery.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Lộ trình giao hàng
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle,
                      color: AppColors.primary, size: 10),
                  Container(
                    width: 2,
                    height: 22,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  const Icon(Icons.location_on,
                      color: AppColors.secondary, size: 12),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.pickupAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      delivery.dropoffAddress,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // HỘP MÃ OTP NHẬN HÀNG 4 SỐ (TASK 1.4)
          if (delivery.handoverOtp != null &&
              delivery.handoverOtp!.isNotEmpty &&
              !isCompleted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(isDark ? 40 : 25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.secondary, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      color: AppColors.secondary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MÃ OTP NHẬN HÀNG CỦA BẠN:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          delivery.handoverOtp!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.secondary, size: 20),
                    tooltip: 'Sao chép mã OTP',
                    onPressed: () =>
                        _copyOtp(context, delivery.handoverOtp!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Vui lòng đọc mã OTP này cho tài xế JetPost khi nhận hàng',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Nút xem chi tiết đơn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tạo lúc: ${DateFormatter.formatDateTime(delivery.createdAt)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailScreen.delivery(delivery: delivery),
                    ),
                  );
                },
                child: const Text('Xem Chi Tiết >'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(DeliveryStatus status) {
    String text;
    Color color;
    Color bg;

    switch (status) {
      case DeliveryStatus.pendingDriver:
        text = 'Tìm tài xế';
        color = AppColors.warning;
        bg = AppColors.warningBg;
        break;
      case DeliveryStatus.accepted:
        text = 'Đang đến lấy';
        color = AppColors.primary;
        bg = AppColors.primaryLight;
        break;
      case DeliveryStatus.pickedUp:
        text = 'Đã lấy hàng';
        color = AppColors.primary;
        bg = AppColors.primaryLight;
        break;
      case DeliveryStatus.inTransit:
        text = 'Đang giao đến';
        color = AppColors.secondary;
        bg = AppColors.secondaryLight;
        break;
      case DeliveryStatus.completed:
        text = 'Đã nhận';
        color = AppColors.success;
        bg = AppColors.successBg;
        break;
      case DeliveryStatus.cancelled:
        text = 'Đã hủy';
        color = AppColors.error;
        bg = AppColors.errorBg;
        break;
      case DeliveryStatus.failedDelivery:
        text = 'Thất bại';
        color = AppColors.error;
        bg = AppColors.errorBg;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

