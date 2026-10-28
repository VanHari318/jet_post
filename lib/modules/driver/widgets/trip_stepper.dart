import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/ride_model.dart';
import '../../../models/delivery_model.dart';
import '../controllers/driver_trip_controller.dart';
import 'swipe_action_bar.dart';

/// Widget TripStepper — Hiển thị phiên hoạt động của tài xế
///
/// Bao gồm:
/// - Thanh tiến trình trực quan (các bước đã/đang/chưa hoàn thành)
/// - SwipeActionBar để chuyển sang trạng thái kế tiếp
/// - Nút huỷ chuyến
class TripStepper extends StatelessWidget {
  final DriverTripController controller;

  const TripStepper({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.tripType == TripType.ride) {
      return ValueListenableBuilder<RideModel?>(
        valueListenable: controller.currentRide,
        builder: (_, ride, _) {
          if (ride == null) return const SizedBox.shrink();
          return _TripStepperBody(
            steps: _rideSteps(ride.status),
            swipeLabel: controller.rideSwipeLabel,
            confirmTitle: 'Xác nhận hành động',
            confirmMessage: controller.rideConfirmMessage,
            canAdvance: controller.canAdvance,
            isUpdating: controller.isUpdating,
            onSwipeConfirmed: () => controller.advanceRideStatus(),
            onCancel: (reason) => controller.cancelTrip(reason),
            isCompleted: ride.status == RideStatus.completed,
            isCancelled: ride.status == RideStatus.cancelled,
          );
        },
      );
    } else {
      return ValueListenableBuilder<DeliveryModel?>(
        valueListenable: controller.currentDelivery,
        builder: (_, delivery, _) {
          if (delivery == null) return const SizedBox.shrink();
          return _TripStepperBody(
            steps: _deliverySteps(delivery.status),
            swipeLabel: controller.deliverySwipeLabel,
            confirmTitle: 'Xác nhận hành động',
            confirmMessage: controller.deliveryConfirmMessage,
            canAdvance: controller.canAdvance,
            isUpdating: controller.isUpdating,
            onSwipeConfirmed: () => controller.advanceDeliveryStatus(),
            onCancel: (reason) => controller.cancelTrip(reason),
            isCompleted: delivery.status == DeliveryStatus.completed,
            isCancelled: delivery.status == DeliveryStatus.cancelled ||
                delivery.status == DeliveryStatus.failedDelivery,
          );
        },
      );
    }
  }

  // ── Danh sách bước cho Xe Ôm ────────────────────────────────────────────
  List<_StepData> _rideSteps(RideStatus status) {
    final steps = [
      _StepData(
        icon: Icons.handshake_rounded,
        label: 'Đã nhận cuốc',
        subLabel: 'Đang đến điểm đón',
        isDone: _rideIndex(status) > 0,
        isActive: _rideIndex(status) == 0,
      ),
      _StepData(
        icon: Icons.person_pin_circle_rounded,
        label: 'Đã đến đón khách',
        subLabel: 'Chờ khách lên xe',
        isDone: _rideIndex(status) > 1,
        isActive: _rideIndex(status) == 1,
      ),
      _StepData(
        icon: Icons.directions_bike_rounded,
        label: 'Đang di chuyển',
        subLabel: 'Đang chở khách đến nơi',
        isDone: _rideIndex(status) > 2,
        isActive: _rideIndex(status) == 2,
      ),
      _StepData(
        icon: Icons.check_circle_rounded,
        label: 'Hoàn thành',
        subLabel: 'Chuyến đi kết thúc',
        isDone: status == RideStatus.completed,
        isActive: false,
      ),
    ];
    return steps;
  }

  int _rideIndex(RideStatus s) {
    switch (s) {
      case RideStatus.accepted:
        return 0;
      case RideStatus.arrivedPickup:
        return 1;
      case RideStatus.inProgress:
        return 2;
      case RideStatus.completed:
        return 3;
      default:
        return 0;
    }
  }

  // ── Danh sách bước cho Giao Hàng ────────────────────────────────────────
  List<_StepData> _deliverySteps(DeliveryStatus status) {
    final steps = [
      _StepData(
        icon: Icons.handshake_rounded,
        label: 'Đã nhận đơn',
        subLabel: 'Đang đến điểm lấy hàng',
        isDone: _deliveryIndex(status) > 0,
        isActive: _deliveryIndex(status) == 0,
      ),
      _StepData(
        icon: Icons.inventory_2_rounded,
        label: 'Đã lấy hàng',
        subLabel: 'Đã lấy hàng từ người gửi',
        isDone: _deliveryIndex(status) > 1,
        isActive: _deliveryIndex(status) == 1,
      ),
      _StepData(
        icon: Icons.local_shipping_rounded,
        label: 'Đang giao hàng',
        subLabel: 'Đang trên đường giao',
        isDone: _deliveryIndex(status) > 2,
        isActive: _deliveryIndex(status) == 2,
      ),
      _StepData(
        icon: Icons.check_circle_rounded,
        label: 'Giao thành công',
        subLabel: 'Đơn hàng hoàn tất',
        isDone: status == DeliveryStatus.completed,
        isActive: false,
      ),
    ];
    return steps;
  }

  int _deliveryIndex(DeliveryStatus s) {
    switch (s) {
      case DeliveryStatus.accepted:
        return 0;
      case DeliveryStatus.pickedUp:
        return 1;
      case DeliveryStatus.inTransit:
        return 2;
      case DeliveryStatus.completed:
        return 3;
      default:
        return 0;
    }
  }
}

// ── Dữ liệu mỗi bước trong stepper ─────────────────────────────────────────
class _StepData {
  final IconData icon;
  final String label;
  final String subLabel;
  final bool isDone;
  final bool isActive;

  _StepData({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.isDone,
    required this.isActive,
  });
}

// ── Body thực sự của TripStepper ─────────────────────────────────────────────
class _TripStepperBody extends StatelessWidget {
  final List<_StepData> steps;
  final String swipeLabel;
  final String confirmTitle;
  final String confirmMessage;
  final bool canAdvance;
  final ValueNotifier<bool> isUpdating;
  final VoidCallback onSwipeConfirmed;
  final Future<bool> Function(String reason) onCancel;
  final bool isCompleted;
  final bool isCancelled;

  const _TripStepperBody({
    required this.steps,
    required this.swipeLabel,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.canAdvance,
    required this.isUpdating,
    required this.onSwipeConfirmed,
    required this.onCancel,
    required this.isCompleted,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timeline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Phiên Hoạt Động',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                // Badge trạng thái tổng
                if (isCompleted)
                  _StatusBadge(
                      label: 'Hoàn thành',
                      color: AppColors.success,
                      bg: AppColors.successBg)
                else if (isCancelled)
                  _StatusBadge(
                      label: 'Đã huỷ',
                      color: AppColors.error,
                      bg: AppColors.errorBg)
                else
                  _StatusBadge(
                      label: 'Đang chạy',
                      color: AppColors.primary,
                      bg: AppColors.primaryLight),
              ],
            ),

            const SizedBox(height: 20),

            // ── Stepper trực quan ─────────────────────────────────────────
            ...List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;
              return _StepRow(step: step, isLast: isLast);
            }),

            // ── SwipeActionBar hoặc Banner hoàn thành ─────────────────────
            const SizedBox(height: 16),

            if (isCancelled)
              _bannerCancelled()
            else if (isCompleted)
              _bannerCompleted()
            else if (canAdvance) ...[
              ValueListenableBuilder<bool>(
                valueListenable: isUpdating,
                builder: (_, updating, _) => SwipeActionBar(
                  label: swipeLabel,
                  confirmTitle: confirmTitle,
                  confirmMessage: confirmMessage,
                  onConfirmed: onSwipeConfirmed,
                  isLoading: updating,
                ),
              ),
              const SizedBox(height: 10),
              // Nút huỷ chuyến
              Center(
                child: TextButton.icon(
                  onPressed: () => _showCancelDialog(context),
                  icon: Icon(Icons.cancel_outlined,
                      color: AppColors.error, size: 16),
                  label: Text(
                    'Huỷ chuyến',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Dialog huỷ chuyến — yêu cầu nhập lý do
  Future<void> _showCancelDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Huỷ Chuyến',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn có chắc muốn huỷ chuyến này không?\nVui lòng nhập lý do:',
                style: TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Lý do huỷ...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận huỷ'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Tài xế huỷ không có lý do';
      await onCancel(reason);
    }
  }

  Widget _bannerCompleted() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text(
              'Chuyến đi đã hoàn thành thành công!',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  Widget _bannerCancelled() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Chuyến đi đã bị huỷ',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

/// Một dòng bước trong stepper
class _StepRow extends StatelessWidget {
  final _StepData step;
  final bool isLast;

  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
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
      lineColor = AppColors.borderLight;
    } else {
      circleColor = Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : AppColors.backgroundLight;
      iconColor = Theme.of(context).brightness == Brightness.dark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight;
      lineColor = AppColors.borderLight;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cột trái: circle + đường kẻ dọc ───────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
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
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(step.icon, color: iconColor, size: 18),
                ),
                // Đường kẻ dọc nối các bước (trừ bước cuối)
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

          // ── Cột phải: nhãn bước ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: step.isDone || step.isActive
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: step.isActive
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Check icon cho bước đã hoàn thành ────────────────────────────
          if (step.isDone)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 18),
            ),
          if (step.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.radio_button_checked_rounded,
                  color: AppColors.primary, size: 18),
            ),
        ],
      ),
    );
  }
}

/// Badge nhỏ hiển thị trạng thái tổng
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _StatusBadge(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}


