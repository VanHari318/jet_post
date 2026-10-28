import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/ride_model.dart';
import '../../../models/delivery_model.dart';
import '../controllers/driver_trip_controller.dart';
import '../widgets/order_info_card.dart';
import '../widgets/package_detail_card.dart';
import '../widgets/contact_card.dart';
import '../widgets/trip_stepper.dart';
import '../../../routes/app_routes.dart';

/// Màn hình tài xế đang thực hiện chuyến đi
/// Hiển thị: OSM Map + OrderInfoCard + PackageDetailCard + ContactCard + TripStepper
class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key});

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  late final DriverTripController _controller;
  late final TripType _tripType;
  late final String _tripId;
  late final String _driverUid;

  final MapController _mapController = MapController();

  // Vị trí mặc định (TP.HCM) — cập nhật từ trip data
  final LatLng _driverPos = const LatLng(10.7769, 106.7009);
  LatLng? _pickupPos;
  LatLng? _dropoffPos;
  List<LatLng> _routePoints = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _tripId = args?['tripId'] as String? ?? '';
    _driverUid = args?['driverUid'] as String? ?? '';
    final typeStr = args?['tripType'] as String? ?? 'ride';
    _tripType =
        typeStr == 'delivery' ? TripType.delivery : TripType.ride;

    _controller = DriverTripController(
      tripId: _tripId,
      tripType: _tripType,
      driverUid: _driverUid,
    );
    _controller.init();

    // Lắng nghe thay đổi trip để cập nhật bản đồ
    _controller.currentRide.addListener(_onRideChanged);
    _controller.currentDelivery.addListener(_onDeliveryChanged);
    _controller.errorMessage.addListener(_onError);
  }

  @override
  void dispose() {
    _controller.currentRide.removeListener(_onRideChanged);
    _controller.currentDelivery.removeListener(_onDeliveryChanged);
    _controller.errorMessage.removeListener(_onError);
    _controller.dispose();
    super.dispose();
  }

  void _onRideChanged() {
    final ride = _controller.currentRide.value;
    if (ride == null || !mounted) return;

    setState(() {
      _pickupPos = LatLng(ride.pickupLat, ride.pickupLng);
      _dropoffPos = LatLng(ride.dropoffLat, ride.dropoffLng);
      _routePoints = [_pickupPos!, _dropoffPos!];
    });

    // Zoom bản đồ về khu vực chuyến đi
    _fitMapBounds();

    // Khi hoàn thành hoặc huỷ → về dashboard sau 2 giây
    if (ride.status == RideStatus.completed ||
        ride.status == RideStatus.cancelled) {
      _navigateToDashboardAfterDelay();
    }
  }

  void _onDeliveryChanged() {
    final delivery = _controller.currentDelivery.value;
    if (delivery == null || !mounted) return;

    setState(() {
      _pickupPos = LatLng(delivery.pickupLat, delivery.pickupLng);
      _dropoffPos = LatLng(delivery.dropoffLat, delivery.dropoffLng);
      _routePoints = [_pickupPos!, _dropoffPos!];
    });

    _fitMapBounds();

    if (delivery.status == DeliveryStatus.completed ||
        delivery.status == DeliveryStatus.cancelled ||
        delivery.status == DeliveryStatus.failedDelivery) {
      _navigateToDashboardAfterDelay();
    }
  }

  void _onError() {
    final msg = _controller.errorMessage.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Zoom bản đồ hiển thị cả điểm A và điểm B
  void _fitMapBounds() {
    if (_pickupPos == null || _dropoffPos == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([_pickupPos!, _dropoffPos!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {}
  }

  /// Về màn hình Dashboard sau 2 giây (khi hoàn thành/huỷ)
  void _navigateToDashboardAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context)
            .pushReplacementNamed(AppRoutes.driverDashboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Bản đồ (40% màn hình) ─────────────────────────────────────
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                _buildMap(),
                // AppBar nổi
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildFloatingAppBar(),
                ),
                // Nút định vị lại
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'locate_trip',
                    onPressed: _fitMapBounds,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    child: const Icon(Icons.fit_screen_rounded),
                  ),
                ),
              ],
            ),
          ),

          // ── Danh sách card cuộn (60% màn hình) ───────────────────────
          Expanded(
            flex: 6,
            child: _buildScrollableContent(),
          ),
        ],
      ),
    );
  }

  /// Bản đồ OSM với markers điểm đón + điểm đến + polyline
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverPos,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.jetpost.app',
          maxZoom: 19,
        ),
        // Polyline tuyến đường
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4,
                color: AppColors.routePolyline,
              ),
            ],
          ),
        // Markers
        MarkerLayer(
          markers: [
            // Marker tài xế
            Marker(
              point: _driverPos,
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.driverBusy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.driverBusy.withAlpha(100),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: const Icon(Icons.motorcycle_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            // Marker điểm đón / lấy hàng (A)
            if (_pickupPos != null)
              Marker(
                point: _pickupPos!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 40),
              ),
            // Marker điểm đến (B)
            if (_dropoffPos != null)
              Marker(
                point: _dropoffPos!,
                width: 40,
                height: 40,
                child: const Icon(Icons.flag_rounded,
                    color: AppColors.secondary, size: 36),
              ),
          ],
        ),
      ],
    );
  }

  /// AppBar nổi trên bản đồ
  Widget _buildFloatingAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withAlpha(220)
              : Colors.white.withAlpha(220),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 10,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Nút back
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () =>
                    Navigator.pushReplacementNamed(
                        context, AppRoutes.driverDashboard),
              ),

              // Tiêu đề
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _tripType == TripType.ride
                              ? Icons.motorcycle_rounded
                              : Icons.inventory_2_rounded,
                          size: 14,
                          color: _tripType == TripType.ride
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _tripType == TripType.ride
                              ? 'Cuốc Xe Ôm'
                              : 'Giao Hàng',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _tripType == TripType.ride
                                ? AppColors.primary
                                : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Mã đơn: #${_tripId.length > 8 ? _tripId.substring(0, 8).toUpperCase() : _tripId}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),

              // Badge trạng thái hiện tại
              _buildStatusBadge(),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_tripType == TripType.ride) {
      return ValueListenableBuilder<RideModel?>(
        valueListenable: _controller.currentRide,
        builder: (_, ride, _) {
          if (ride == null) return const SizedBox.shrink();
          return _StatusChip(label: ride.status.displayName);
        },
      );
    } else {
      return ValueListenableBuilder<DeliveryModel?>(
        valueListenable: _controller.currentDelivery,
        builder: (_, delivery, _) {
          if (delivery == null) return const SizedBox.shrink();
          return _StatusChip(label: delivery.status.displayName);
        },
      );
    }
  }

  /// Phần nội dung cuộn phía dưới: OrderInfoCard + PackageDetailCard + ContactCard + TripStepper
  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── OrderInfoCard ────────────────────────────────────────────
          if (_tripType == TripType.ride)
            ValueListenableBuilder<RideModel?>(
              valueListenable: _controller.currentRide,
              builder: (_, ride, _) => ride == null
                  ? const SizedBox.shrink()
                  : OrderInfoCard(
                      pickupLabel: 'Điểm Đón Khách',
                      pickupAddress: ride.pickupAddress,
                      pickupLat: ride.pickupLat,
                      pickupLng: ride.pickupLng,
                      dropoffLabel: 'Điểm Trả Khách',
                      dropoffAddress: ride.dropoffAddress,
                      dropoffLat: ride.dropoffLat,
                      dropoffLng: ride.dropoffLng,
                      distanceKm: ride.distanceKm,
                      price: ride.price,
                    ),
            )
          else
            ValueListenableBuilder<DeliveryModel?>(
              valueListenable: _controller.currentDelivery,
              builder: (_, delivery, _) => delivery == null
                  ? const SizedBox.shrink()
                  : OrderInfoCard(
                      pickupLabel: 'Điểm Lấy Hàng',
                      pickupAddress: delivery.pickupAddress,
                      pickupLat: delivery.pickupLat,
                      pickupLng: delivery.pickupLng,
                      dropoffLabel: 'Địa Chỉ Giao Hàng',
                      dropoffAddress: delivery.dropoffAddress,
                      dropoffLat: delivery.dropoffLat,
                      dropoffLng: delivery.dropoffLng,
                      distanceKm: delivery.distanceKm,
                      price: delivery.price,
                    ),
            ),

          // ── PackageDetailCard (chỉ với Delivery) ─────────────────────
          if (_tripType == TripType.delivery)
            ValueListenableBuilder<DeliveryModel?>(
              valueListenable: _controller.currentDelivery,
              builder: (_, delivery, _) => delivery == null
                  ? const SizedBox.shrink()
                  : PackageDetailCard(
                      packageType: delivery.packageType,
                      packageNote: delivery.packageNote,
                      handoverOtp: delivery.handoverOtp,
                      showOtp:
                          delivery.status == DeliveryStatus.inTransit,
                    ),
            ),

          // ── ContactCard ───────────────────────────────────────────────
          if (_tripType == TripType.ride)
            ValueListenableBuilder<RideModel?>(
              valueListenable: _controller.currentRide,
              builder: (_, ride, _) => ride == null
                  ? const SizedBox.shrink()
                  : ContactCard.ride(
                      customerName: ride.customerName,
                      customerPhone: ride.customerPhone,
                    ),
            )
          else
            ValueListenableBuilder<DeliveryModel?>(
              valueListenable: _controller.currentDelivery,
              builder: (_, delivery, _) => delivery == null
                  ? const SizedBox.shrink()
                  : ContactCard.delivery(
                      senderName: delivery.senderName,
                      senderPhone: delivery.senderPhone,
                      receiverName: delivery.receiverName,
                      receiverPhone: delivery.receiverPhone,
                    ),
            ),

          // ── TripStepper (Swipe-to-Confirm) ───────────────────────────
          TripStepper(controller: _controller),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Chip hiển thị trạng thái hiện tại
class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
