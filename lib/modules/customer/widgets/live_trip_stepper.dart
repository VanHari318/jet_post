import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';

/// Dữ liệu từng bước trong tiến trình cuốc xe phía khách hàng
class _CustomerStepData {
  final IconData icon;
  final String label;
  final String subLabel;
  final bool isDone;
  final bool isActive;

  _CustomerStepData({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.isDone,
    required this.isActive,
  });
}

/// Widget LiveTripStepper phía Khách hàng
/// Hiển thị trực quan tiến trình chuyến đi thời gian thực đồng bộ với trạng thái tài xế
class LiveTripStepper extends StatelessWidget {
  final RideStatus? rideStatus;
  final DeliveryStatus? deliveryStatus;

  const LiveTripStepper.ride({
    super.key,
    required RideStatus this.rideStatus,
  }) : deliveryStatus = null;

  const LiveTripStepper.delivery({
    super.key,
    required DeliveryStatus this.deliveryStatus,
  }) : rideStatus = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = rideStatus != null
        ? _buildRideSteps(rideStatus!)
        : _buildDeliverySteps(deliveryStatus!);

    final isPending = rideStatus == RideStatus.pendingDriver ||
        deliveryStatus == DeliveryStatus.pendingDriver;
    final isCompleted = rideStatus == RideStatus.completed ||
        deliveryStatus == DeliveryStatus.completed;
    final isCancelled = rideStatus == RideStatus.cancelled ||
        deliveryStatus == DeliveryStatus.cancelled ||
        deliveryStatus == DeliveryStatus.failedDelivery;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isPending ? AppColors.warningBg : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPending ? Icons.radar_rounded : Icons.timeline_rounded,
                  color: isPending ? AppColors.warning : AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tiến Trình Chuyến Đi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              if (isCompleted)
                _statusBadge('Hoàn tất', AppColors.success, AppColors.successBg)
              else if (isCancelled)
                _statusBadge('Đã hủy', AppColors.error, AppColors.errorBg)
              else if (isPending)
                _statusBadge('Đang tìm tài xế', AppColors.warning, AppColors.warningBg)
              else
                _statusBadge('Đang diễn ra', AppColors.primary, AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 14),
          if (isPending)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.warningBg.withAlpha(50) : AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đang điều phối tài xế gần bạn nhất... Tiến trình sẽ kích hoạt khi tài xế nhận đơn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.warning : const Color(0xFF8D6E63),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return _CustomerStepRow(step: step, isLast: isLast);
          }),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
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

  List<_CustomerStepData> _buildRideSteps(RideStatus status) {
    final idx = _rideIndex(status);
    return [
      _CustomerStepData(
        icon: Icons.two_wheeler_rounded,
        label: 'Tài xế đang đến',
        subLabel: 'Tài xế đã tiếp nhận và đang di chuyển đón bạn',
        isDone: idx > 0,
        isActive: idx == 0,
      ),
      _CustomerStepData(
        icon: Icons.person_pin_circle_rounded,
        label: 'Tài xế đã đến điểm đón',
        subLabel: 'Vui lòng di chuyển ra gặp tài xế',
        isDone: idx > 1,
        isActive: idx == 1,
      ),
      _CustomerStepData(
        icon: Icons.navigation_rounded,
        label: 'Đang di chuyển',
        subLabel: 'Đang trên hành trình đến điểm trả',
        isDone: idx > 2,
        isActive: idx == 2,
      ),
      _CustomerStepData(
        icon: Icons.check_circle_rounded,
        label: 'Đã đến đích',
        subLabel: 'Chuyến đi hoàn thành an toàn',
        isDone: status == RideStatus.completed,
        isActive: false,
      ),
    ];
  }

  int _rideIndex(RideStatus status) {
    switch (status) {
      case RideStatus.pendingDriver:
        return -1;
      case RideStatus.accepted:
        return 0;
      case RideStatus.arrivedPickup:
        return 1;
      case RideStatus.inProgress:
        return 2;
      case RideStatus.completed:
        return 3;
      default:
        return -1;
    }
  }

  List<_CustomerStepData> _buildDeliverySteps(DeliveryStatus status) {
    final idx = _deliveryIndex(status);
    return [
      _CustomerStepData(
        icon: Icons.storefront_rounded,
        label: 'Tài xế đang đến lấy hàng',
        subLabel: 'Tài xế đang đến địa chỉ người gửi',
        isDone: idx > 0,
        isActive: idx == 0,
      ),
      _CustomerStepData(
        icon: Icons.inventory_2_rounded,
        label: 'Đã lấy gói hàng',
        subLabel: 'Gói hàng đã được bàn giao cho tài xế',
        isDone: idx > 1,
        isActive: idx == 1,
      ),
      _CustomerStepData(
        icon: Icons.local_shipping_rounded,
        label: 'Đang trên đường giao',
        subLabel: 'Tài xế đang di chuyển tới người nhận',
        isDone: idx > 2,
        isActive: idx == 2,
      ),
      _CustomerStepData(
        icon: Icons.task_alt_rounded,
        label: 'Giao hàng thành công',
        subLabel: 'Bưu phẩm đã được đối soát PoD và bàn giao',
        isDone: status == DeliveryStatus.completed,
        isActive: false,
      ),
    ];
  }

  int _deliveryIndex(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pendingDriver:
        return -1;
      case DeliveryStatus.accepted:
        return 0;
      case DeliveryStatus.pickedUp:
        return 1;
      case DeliveryStatus.inTransit:
        return 2;
      case DeliveryStatus.completed:
        return 3;
      default:
        return -1;
    }
  }
}

class _CustomerStepRow extends StatelessWidget {
  final _CustomerStepData step;
  final bool isLast;

  const _CustomerStepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color circleColor;
    Color iconColor;
    Color lineColor;

    if (step.isDone) {
      circleColor = AppColors.primary;
      iconColor = Colors.white;
      lineColor = AppColors.primary;
    } else if (step.isActive) {
      circleColor = AppColors.primaryLight;
      iconColor = AppColors.primary;
      lineColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    } else {
      circleColor = isDark ? AppColors.surfaceDark : AppColors.backgroundLight;
      iconColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
      lineColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    border: step.isActive
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                    boxShadow: step.isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(60),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(step.icon, color: iconColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: lineColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: step.isDone || step.isActive
                          ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: step.isActive
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (step.isDone)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle, color: AppColors.primary, size: 16),
            ),
          if (step.isActive)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.radio_button_checked,
                  color: AppColors.primary, size: 16),
            ),
        ],
      ),
    );
  }
}

