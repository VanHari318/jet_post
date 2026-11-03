import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';

/// Thẻ hiển thị tóm tắt cuốc xe / đơn giao hàng trong danh sách Hoạt động & Lịch sử
class OrderHistoryCard extends StatelessWidget {
  final RideModel? ride;
  final DeliveryModel? delivery;
  final VoidCallback onTap;
  final VoidCallback? onRateNow;

  const OrderHistoryCard.ride({
    super.key,
    required RideModel this.ride,
    required this.onTap,
    this.onRateNow,
  }) : delivery = null;

  const OrderHistoryCard.delivery({
    super.key,
    required DeliveryModel this.delivery,
    required this.onTap,
    this.onRateNow,
  }) : ride = null;

  bool get isDelivery => delivery != null;

  String get id => isDelivery ? delivery!.id : ride!.id;
  String get pickupAddress =>
      isDelivery ? delivery!.pickupAddress : ride!.pickupAddress;
  String get dropoffAddress =>
      isDelivery ? delivery!.dropoffAddress : ride!.dropoffAddress;
  double get price => isDelivery ? delivery!.price : ride!.price;
  DateTime get createdAt =>
      isDelivery ? delivery!.createdAt : ride!.createdAt;
  int? get rating => isDelivery ? delivery!.rating : ride!.rating;

  bool get isCompleted {
    if (isDelivery) {
      return delivery!.status == DeliveryStatus.completed;
    }
    return ride!.status == RideStatus.completed;
  }

  bool get isCancelled {
    if (isDelivery) {
      return delivery!.status == DeliveryStatus.cancelled ||
          delivery!.status == DeliveryStatus.failedDelivery;
    }
    return ride!.status == RideStatus.cancelled;
  }

  String get statusText {
    if (isDelivery) {
      switch (delivery!.status) {
        case DeliveryStatus.pendingDriver:
          return 'Đang tìm tài xế';
        case DeliveryStatus.accepted:
          return 'Tài xế đang đến lấy';
        case DeliveryStatus.pickedUp:
          return 'Đã lấy hàng';
        case DeliveryStatus.inTransit:
          return 'Đang giao hàng';
        case DeliveryStatus.completed:
          return 'Giao thành công';
        case DeliveryStatus.cancelled:
          return 'Đã hủy';
        case DeliveryStatus.failedDelivery:
          return 'Giao thất bại';
      }
    } else {
      switch (ride!.status) {
        case RideStatus.pendingDriver:
          return 'Đang tìm tài xế';
        case RideStatus.accepted:
          return 'Tài xế đang đến';
        case RideStatus.arrivedPickup:
          return 'Tài xế đã đến điểm đón';
        case RideStatus.inProgress:
          return 'Đang di chuyển';
        case RideStatus.completed:
          return 'Hoàn thành';
        case RideStatus.cancelled:
          return 'Đã hủy';
      }
    }
  }

  Color get statusColor {
    if (isCompleted) return AppColors.success;
    if (isCancelled) return AppColors.error;
    return AppColors.primary;
  }

  Color get statusBg {
    if (isCompleted) return AppColors.successBg;
    if (isCancelled) return AppColors.errorBg;
    return AppColors.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon dịch vụ + Ngày giờ + Badge trạng thái
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDelivery
                          ? AppColors.secondary.withAlpha(30)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDelivery
                          ? Icons.local_shipping_rounded
                          : Icons.electric_moped_rounded,
                      color: isDelivery
                          ? AppColors.secondary
                          : AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDelivery ? 'Giao Hàng JetExpress' : 'Xe Ôm JetBike',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Thời gian tạo
              Text(
                DateFormatter.formatDateTime(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Lộ trình điểm đón -> điểm trả
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle,
                          color: AppColors.primary, size: 10),
                      Container(
                        width: 2,
                        height: 24,
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
                          pickupAddress,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          dropoffAddress,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Footer: Giá tiền + Đánh giá sao hoặc Nút đánh giá bù
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Cước phí: ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        CurrencyFormatter.format(price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (rating != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          '$rating sao',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ] else if (isCompleted && onRateNow != null) ...[
                    InkWell(
                      onTap: onRateNow,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline_rounded,
                                color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Đánh giá ngay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

