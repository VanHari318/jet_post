import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../models/driver_model.dart';
import '../../user/widgets/order_chat_button.dart';

/// Thẻ thông tin tài xế phục vụ cuốc xe
/// Hiển thị thông tin nhận diện xe, tài xế và các nút gọi điện / chat P2P
class DriverContactCard extends StatelessWidget {
  final DriverModel? driver;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;
  const DriverContactCard({
    super.key,
    this.driver,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
  });

  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      AppDialogs.showError(
        context,
        title: 'Không Có Số Điện Thoại',
        message: 'Tài xế chưa cập nhật số điện thoại liên lạc.',
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        AppDialogs.showError(
          context,
          title: 'Lỗi Cuộc Gọi',
          message: 'Không thể mở trình quay số trên thiết bị này.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name =
        driverName ?? (driver != null ? 'Đối tác Tài xế' : 'Đang tìm...');
    final plate = driverPlate ?? driver?.plateNumber ?? 'Biển số đang cập nhật';
    final phone = driverPhone ?? '';
    final rating = driver?.rating ?? 5.0;
    final reviews = driver?.totalReviews ?? 0;
    final targetDriverId = (driverId != null && driverId!.isNotEmpty)
        ? driverId!
        : (driver?.id ?? '');

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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar tài xế
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryLight,
                backgroundImage:
                    driver?.idCardFrontUrl != null &&
                        driver!.idCardFrontUrl!.isNotEmpty
                    ? NetworkImage(
                        CloudinaryService.instance.getOptimizedUrl(
                          driver!.idCardFrontUrl!,
                          width: 100,
                          height: 100,
                        ),
                      )
                    : null,
                child: driver?.idCardFrontUrl == null
                    ? const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Thông tin Tên, Biển số xe, Đánh giá sao
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        plate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rating ($reviews đánh giá)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Các nút hành động: Gọi điện & Chat P2P
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(context, phone),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(
                    Icons.phone,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Gọi Điện',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderChatButton(
                  targetUserId: targetDriverId,
                  targetName: name,
                  targetPhone: phone,
                  label: 'Nhắn Tin P2P',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
