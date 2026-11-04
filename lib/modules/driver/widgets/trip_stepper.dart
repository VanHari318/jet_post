import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/cloudinary_service.dart';
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
            onSwipeConfirmed: () {
              if (delivery.status == DeliveryStatus.inTransit) {
                _showDeliveryCompletionDialog(context, controller, delivery);
              } else if (delivery.status == DeliveryStatus.accepted) {
                _showPickupConfirmationDialog(context, controller, delivery);
              } else {
                controller.advanceDeliveryStatus();
              }
            },
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

  /// Hộp thoại xác nhận lấy hàng từ người gửi
  Future<void> _showPickupConfirmationDialog(
    BuildContext context,
    DriverTripController controller,
    DeliveryModel delivery,
  ) async {
    File? pickedImage;
    bool isUploading = false;
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom +
              max(20.0, MediaQuery.of(sheetContext).padding.bottom + 12.0);

          return SafeArea(
            top: false,
            bottom: true,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomPadding,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.inventory_2_rounded,
                            color: AppColors.secondary, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Xác Nhận Đã Nhận Gói Hàng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kiểm tra kiện hàng từ người gửi (${delivery.senderName}). Vui lòng chụp ảnh gói hàng để lưu bằng chứng nhận hàng.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 16),

                    // Khu vực ảnh xem toàn bộ + Chụp lại + Phóng to
                    if (pickedImage != null) ...[
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _showFullScreenImageViewer(
                                  sheetContext, pickedImage!);
                            },
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  pickedImage!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Xem toàn màn hình',
                                    icon: const Icon(Icons.fullscreen_rounded,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _showFullScreenImageViewer(
                                        sheetContext, pickedImage!),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Chụp lại',
                                    icon: const Icon(Icons.replay_rounded,
                                        color: Colors.white, size: 20),
                                    onPressed: isUploading
                                        ? null
                                        : () async {
                                            final picker = ImagePicker();
                                            final xFile =
                                                await picker.pickImage(
                                              source: ImageSource.camera,
                                              maxWidth: 1200,
                                              maxHeight: 1200,
                                              imageQuality: 80,
                                            );
                                            if (xFile != null) {
                                              setModalState(() {
                                                pickedImage = File(xFile.path);
                                                localError = null;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Chạm vào ảnh để phóng to toàn màn hình',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final xFile = await picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 1200,
                                  maxHeight: 1200,
                                  imageQuality: 80,
                                );
                                if (xFile != null) {
                                  setModalState(() {
                                    pickedImage = File(xFile.path);
                                    localError = null;
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: localError != null
                                  ? AppColors.error
                                  : AppColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_rounded,
                                  color: AppColors.primary, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Bấm để chụp ảnh kiện hàng (Bắt buộc)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () async {
                              if (pickedImage == null) {
                                setModalState(() {
                                  localError =
                                      'Vui lòng chụp ảnh kiện hàng trước khi xác nhận nhận hàng!';
                                });
                                return;
                              }

                              setModalState(() => isUploading = true);
                              String? uploadedUrl;
                              uploadedUrl = await CloudinaryService.instance
                                  .uploadCustomImage(
                                imageFile: pickedImage!,
                                subFolder: 'deliveries/pickup',
                                fileName:
                                    'pickup_${delivery.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                              );

                              await controller.advanceDeliveryStatus(
                                pickupPhotoUrl: uploadedUrl,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Xác Nhận & Bắt Đầu Di Chuyển',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Hộp thoại đối soát OTP & PoD bàn giao hàng thành công
  Future<void> _showDeliveryCompletionDialog(
    BuildContext context,
    DriverTripController controller,
    DeliveryModel delivery,
  ) async {
    final otpController = TextEditingController();
    File? podImage;
    bool isUploading = false;
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
          final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom +
              max(20.0, MediaQuery.of(sheetContext).padding.bottom + 12.0);

          return SafeArea(
            top: false,
            bottom: true,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomPadding,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.verified_user_rounded,
                            color: AppColors.success, size: 26),
                        SizedBox(width: 10),
                        Text(
                          'Bàn Giao & Hoàn Tất Đơn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yêu cầu người nhận (${delivery.receiverName}) đọc mã OTP 4 số và chụp ảnh bàn giao hàng hóa.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 16),
                    // Ô nhập OTP
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Nhập Mã OTP 4 số từ Người Nhận',
                        hintText: '••••',
                        errorText: localError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon:
                            const Icon(Icons.pin_rounded, color: AppColors.primary),
                      ),
                      onChanged: (_) {
                        if (localError != null) {
                          setModalState(() => localError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Ô chụp ảnh PoD
                    if (podImage != null) ...[
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _showFullScreenImageViewer(
                                  sheetContext, podImage!);
                            },
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.success,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  podImage!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Xem toàn màn hình',
                                    icon: const Icon(Icons.fullscreen_rounded,
                                        color: Colors.white, size: 20),
                                    onPressed: () => _showFullScreenImageViewer(
                                        sheetContext, podImage!),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Chụp lại',
                                    icon: const Icon(Icons.replay_rounded,
                                        color: Colors.white, size: 20),
                                    onPressed: isUploading
                                        ? null
                                        : () async {
                                            final picker = ImagePicker();
                                            final xFile =
                                                await picker.pickImage(
                                              source: ImageSource.camera,
                                              maxWidth: 1200,
                                              maxHeight: 1200,
                                              imageQuality: 80,
                                            );
                                            if (xFile != null) {
                                              setModalState(() {
                                                podImage = File(xFile.path);
                                                localError = null;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Chạm vào ảnh để phóng to toàn màn hình',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final xFile = await picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 1200,
                                  maxHeight: 1200,
                                  imageQuality: 80,
                                );
                                if (xFile != null) {
                                  setModalState(() {
                                    podImage = File(xFile.path);
                                    localError = null;
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: localError != null && podImage == null
                                  ? AppColors.error
                                  : AppColors.borderLight,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt_rounded,
                                  color: AppColors.secondary, size: 36),
                              SizedBox(height: 6),
                              Text(
                                'Bấm để chụp ảnh bàn giao (PoD) (Bắt buộc)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final enteredOtp = otpController.text.trim();
                              if (enteredOtp.length != 4) {
                                setModalState(() {
                                  localError =
                                      'Vui lòng nhập đủ 4 chữ số OTP từ người nhận.';
                                });
                                return;
                              }

                              // Đối soát OTP với handoverOtp
                              final correctOtp = delivery.handoverOtp?.trim();
                              if (correctOtp != null && correctOtp.isNotEmpty) {
                                if (enteredOtp != correctOtp) {
                                  setModalState(() {
                                    localError =
                                        'Mã OTP không đúng! Hãy hỏi lại người nhận.';
                                  });
                                  return;
                                }
                              }

                              if (podImage == null) {
                                setModalState(() {
                                  localError =
                                      'Vui lòng chụp ảnh bàn giao hàng hóa (PoD) trước khi hoàn tất!';
                                });
                                return;
                              }

                              setModalState(() => isUploading = true);
                              String? podUrl;
                              podUrl = await CloudinaryService.instance
                                  .uploadDeliveryPod(
                                imageFile: podImage!,
                                deliveryId: delivery.id,
                              );

                              final ok = await controller.completeDelivery(
                                enteredOtp: enteredOtp,
                                podPhotoUrl: podUrl,
                              );

                              if (ok) {
                                if (ctx.mounted) Navigator.pop(ctx);
                              } else {
                                setModalState(() {
                                  isUploading = false;
                                  localError = controller.errorMessage.value ??
                                      'Có lỗi xảy ra khi hoàn tất đơn.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Xác Nhận Bàn Giao Thành Công',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Trình xem toàn ảnh có thể zoom kéo thả
  void _showFullScreenImageViewer(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
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


