import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../models/delivery_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../services/customer_service.dart';
import '../widgets/driver_contact_card.dart';
import '../widgets/live_trip_stepper.dart';
import '../widgets/trip_rating_dialog.dart';

/// Màn hình Theo Dõi Trực Tuyến Thời Gian Thực (Task 1.3 & 1.5)
/// Hiển thị bản đồ OSM, vị trí tài xế di chuyển mượt mà, TripStepper,
/// thẻ liên lạc tài xế (Gọi / Chat P2P) và hộp thoại đối soát PoD khi hoàn tất.
class LiveTrackingScreen extends StatefulWidget {
  final String? rideId;
  final String? deliveryId;

  const LiveTrackingScreen.ride({super.key, required this.rideId})
    : deliveryId = null;

  const LiveTrackingScreen.delivery({super.key, required this.deliveryId})
    : rideId = null;

  bool get isDelivery => deliveryId != null;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  bool _hasShownCompletionDialog = false;

  Future<void> _handleCancelTrip(
    BuildContext context,
    String tripId,
    bool isDelivery,
  ) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy Chuyến Đi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tài xế đã tiếp nhận chuyến. Bạn có chắc chắn muốn hủy không?',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do hủy chuyến...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Khách hàng chủ động hủy chuyến';

      if (isDelivery) {
        await CustomerService.instance.cancelDelivery(
          deliveryId: tripId,
          reason: reason,
          cancelledBy: 'customer',
        );
      } else {
        await CustomerService.instance.cancelRide(
          rideId: tripId,
          reason: reason,
          cancelledBy: 'customer',
        );
      }

      if (context.mounted) {
        AppDialogs.showSuccess(
          context,
          title: 'Đã Hủy Chuyến',
          message: 'Chuyến đi của bạn đã được hủy bỏ thành công.',
          onConfirmed: () {
            Navigator.pop(context);
          },
        );
      }
    }
  }

  void _triggerCompletion(
    BuildContext context, {
    required String tripId,
    String? driverId,
    required String driverName,
    required double price,
    bool isDelivery = false,
    String? podPhotoUrl,
  }) {
    if (_hasShownCompletionDialog) return;
    _hasShownCompletionDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TripRatingDialog.show(
        context,
        tripId: tripId,
        driverId: driverId,
        driverName: driverName,
        price: price,
        isDelivery: isDelivery,
        podPhotoUrl: podPhotoUrl,
        onDismissed: () {
          if (mounted) Navigator.pop(context);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDelivery) {
      return StreamBuilder<DeliveryModel?>(
        stream: CustomerService.instance.streamDelivery(widget.deliveryId!),
        builder: (context, snapshot) {
          final delivery = snapshot.data;
          if (delivery == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (delivery.status == DeliveryStatus.completed) {
            _triggerCompletion(
              context,
              tripId: delivery.id,
              driverId: delivery.driverId,
              driverName: delivery.driverName ?? 'Tài xế JetPost',
              price: delivery.price,
              isDelivery: true,
              podPhotoUrl: delivery.podPhotoUrl,
            );
          }

          return _buildTrackingView(
            context,
            tripId: delivery.id,
            isDelivery: true,
            pickupLat: delivery.pickupLat,
            pickupLng: delivery.pickupLng,
            dropoffLat: delivery.dropoffLat,
            dropoffLng: delivery.dropoffLng,
            pickupAddress: delivery.pickupAddress,
            dropoffAddress: delivery.dropoffAddress,
            driverId: delivery.driverId,
            driverName: delivery.driverName,
            driverPhone: delivery.driverPhone,
            driverPlate: delivery.driverPlate,
            deliveryStatus: delivery.status,
            handoverOtp: delivery.handoverOtp,
            canCancel:
                delivery.status == DeliveryStatus.pendingDriver ||
                delivery.status == DeliveryStatus.accepted ||
                delivery.status == DeliveryStatus.pickedUp,
          );
        },
      );
    } else {
      return StreamBuilder<RideModel?>(
        stream: CustomerService.instance.streamRide(widget.rideId!),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (ride.status == RideStatus.completed) {
            _triggerCompletion(
              context,
              tripId: ride.id,
              driverId: ride.driverId,
              driverName: ride.driverName ?? 'Tài xế JetPost',
              price: ride.price,
              isDelivery: false,
            );
          }

          return _buildTrackingView(
            context,
            tripId: ride.id,
            isDelivery: false,
            pickupLat: ride.pickupLat,
            pickupLng: ride.pickupLng,
            dropoffLat: ride.dropoffLat,
            dropoffLng: ride.dropoffLng,
            pickupAddress: ride.pickupAddress,
            dropoffAddress: ride.dropoffAddress,
            driverId: ride.driverId,
            driverName: ride.driverName,
            driverPhone: ride.driverPhone,
            driverPlate: ride.driverPlate,
            rideStatus: ride.status,
            canCancel:
                ride.status == RideStatus.pendingDriver ||
                ride.status == RideStatus.accepted ||
                ride.status == RideStatus.arrivedPickup,
          );
        },
      );
    }
  }

  Widget _buildTrackingView(
    BuildContext context, {
    required String tripId,
    required bool isDelivery,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String pickupAddress,
    required String dropoffAddress,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    RideStatus? rideStatus,
    DeliveryStatus? deliveryStatus,
    String? handoverOtp,
    required bool canCancel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickupPoint = LatLng(pickupLat, pickupLng);
    final dropoffPoint = LatLng(dropoffLat, dropoffLng);

    return Scaffold(
      body: Stack(
        children: [
          // 1. STREAM VỊ TRÍ TÀI XẾ & BẢN ĐỒ LIVE
          StreamBuilder<DriverModel?>(
            stream: driverId != null && driverId.isNotEmpty
                ? CustomerService.instance.streamDriver(driverId)
                : Stream.value(null),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;
              final driverLatLng =
                  driver != null &&
                      driver.currentLat != 0.0 &&
                      driver.currentLng != 0.0
                  ? LatLng(driver.currentLat, driver.currentLng)
                  : pickupPoint;

              final heading = driver?.heading ?? 0.0;

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: driverLatLng,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl:
                        'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.jet_post',
                    maxZoom: 18,
                  ),
                  MarkerLayer(
                    markers: [
                      // Marker điểm đón
                      Marker(
                        point: pickupPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      // Marker điểm đến
                      Marker(
                        point: dropoffPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.secondary,
                          size: 36,
                        ),
                      ),
                      // Marker tài xế di chuyển thời gian thực (xoay theo heading)
                      if (driver != null)
                        Marker(
                          point: driverLatLng,
                          width: 44,
                          height: 44,
                          child: Transform.rotate(
                            angle: heading * (pi / 180),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(50),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),

          // 2. NÚT QUAY LẠI Ở GÓC TRÊN
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircleAvatar(
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: isDark ? Colors.white : Colors.black87,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // 3. DRAGGABLE SCROLLABLE SHEET TIẾN TRÌNH & THÔNG TIN
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.22,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 12),
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(80),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mã OTP Bàn Giao 4 số (Dành riêng cho đơn Giao Hàng)
                    if (isDelivery &&
                        handoverOtp != null &&
                        handoverOtp.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              color: AppColors.secondary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mã OTP Bàn Giao Bưu Phẩm:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    handoverOtp,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Đọc cho tài xế\nkhi nhận hàng',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Thẻ thông tin tài xế & Liên lạc P2P hoặc Thẻ Chờ Điều Phối
                    if (driverId != null &&
                        driverId.isNotEmpty &&
                        rideStatus != RideStatus.pendingDriver &&
                        deliveryStatus != DeliveryStatus.pendingDriver)
                      DriverContactCard(
                        driverId: driverId,
                        driverName: driverName,
                        driverPhone: driverPhone,
                        driverPlate: driverPlate,
                      )
                    else
                      _PendingDriverCard(
                        isDelivery: isDelivery,
                        pickupAddress: pickupAddress,
                        dropoffAddress: dropoffAddress,
                      ),
                    const SizedBox(height: 14),

                    // Trip Stepper tiến trình
                    if (isDelivery && deliveryStatus != null)
                      LiveTripStepper.delivery(deliveryStatus: deliveryStatus)
                    else if (!isDelivery && rideStatus != null)
                      LiveTripStepper.ride(rideStatus: rideStatus),
                    const SizedBox(height: 14),

                    // Nút Hủy chuyến
                    if (canCancel)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                _handleCancelTrip(context, tripId, isDelivery),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.error,
                              size: 18,
                            ),
                            label: const Text(
                              'Hủy Chuyến Đi Này',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Thẻ trạng thái đang tìm kiếm / điều phối tài xế gần nhất
class _PendingDriverCard extends StatelessWidget {
  final bool isDelivery;
  final String pickupAddress;
  final String dropoffAddress;

  const _PendingDriverCard({
    required this.isDelivery,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withAlpha(isDark ? 80 : 100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang Tìm Tài Xế...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDelivery
                          ? 'Đang gửi yêu cầu giao hàng đến tài xế lân cận'
                          : 'Đang tìm xe ôm gần bạn nhất để đón',
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
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn có thể thu nhỏ ứng dụng hoặc hủy yêu cầu bất cứ lúc nào.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
