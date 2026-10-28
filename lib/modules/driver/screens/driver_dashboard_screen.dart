import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../controllers/driver_dashboard_controller.dart';
import '../widgets/incoming_order_sheet.dart';
import '../../../routes/app_routes.dart';

/// Màn hình chính của tài xế — hiển thị bản đồ OSM + toggle online/offline
/// Lắng nghe đơn mới và hiện IncomingOrderSheet khi có cuốc phù hợp
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  late final DriverDashboardController _controller;
  final MapController _mapController = MapController();

  // Vị trí mặc định (TP.HCM) — sẽ cập nhật khi có GPS thực
  LatLng _currentPosition = const LatLng(10.7769, 106.7009);

  // Theo dõi đơn đang hiện sheet — tránh hiện trùng
  String? _showingOrderId;

  @override
  void initState() {
    super.initState();
    _controller = DriverDashboardController();
    _controller.init();
    _controller.driverModel.addListener(_onDriverModelChanged);
    _controller.pendingRides.addListener(_onOrdersChanged);
    _controller.pendingDeliveries.addListener(_onOrdersChanged);
    _controller.errorMessage.addListener(_onError);
  }

  @override
  void dispose() {
    _controller.driverModel.removeListener(_onDriverModelChanged);
    _controller.pendingRides.removeListener(_onOrdersChanged);
    _controller.pendingDeliveries.removeListener(_onOrdersChanged);
    _controller.errorMessage.removeListener(_onError);
    _controller.dispose();
    super.dispose();
  }

  /// Khi DriverModel cập nhật → cập nhật vị trí marker trên bản đồ
  void _onDriverModelChanged() {
    final driver = _controller.driverModel.value;
    if (driver == null) return;
    if (driver.currentLat != 0 && driver.currentLng != 0) {
      final pos = LatLng(driver.currentLat, driver.currentLng);
      if (mounted) {
        setState(() => _currentPosition = pos);
        _mapController.move(pos, 15);
      }
    }

    // Nếu đang bận chuyến → điều hướng sang màn hình trip
    if (driver.isBusy && driver.activeTripId != null) {
      _navigateToTrip(driver.activeTripId!);
    }
  }

  /// Điều hướng sang màn hình trip đang thực hiện
  void _navigateToTrip(String tripId) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.driverTrip,
      arguments: {'tripId': tripId},
    );
  }

  /// Khi có đơn mới → hiện IncomingOrderSheet
  void _onOrdersChanged() {
    final rides = _controller.pendingRides.value;
    final deliveries = _controller.pendingDeliveries.value;

    // Ưu tiên hiện đơn xe ôm trước, sau đó giao hàng
    if (rides.isNotEmpty && _showingOrderId != rides.first.id) {
      _showRideSheet(rides.first);
    } else if (deliveries.isNotEmpty &&
        _showingOrderId != deliveries.first.id) {
      _showDeliverySheet(deliveries.first);
    }
  }

  void _showRideSheet(RideModel ride) {
    if (!mounted) return;
    _showingOrderId = ride.id;
    IncomingOrderSheet.showRide(
      context: context,
      ride: ride,
      onAccept: () => _controller.acceptRide(ride),
      onDecline: () {
        _showingOrderId = null;
      },
    ).then((_) => _showingOrderId = null);
  }

  void _showDeliverySheet(DeliveryModel delivery) {
    if (!mounted) return;
    _showingOrderId = delivery.id;
    IncomingOrderSheet.showDelivery(
      context: context,
      delivery: delivery,
      onAccept: () => _controller.acceptDelivery(delivery),
      onDecline: () {
        _showingOrderId = null;
      },
    ).then((_) => _showingOrderId = null);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Bản đồ OpenStreetMap toàn màn hình ───────────────────────
          _buildMap(),

          // ── AppBar nổi phía trên bản đồ ───────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingAppBar(),
          ),

          // ── Panel dưới: trạng thái online + thống kê hôm nay ──────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),

          // ── Nút định vị lại (về vị trí tài xế) ───────────────────────
          Positioned(
            right: 16,
            bottom: 200,
            child: _buildLocateMeButton(),
          ),
        ],
      ),
    );
  }

  /// Bản đồ OSM với marker vị trí tài xế
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile layer OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.jetpost.app',
          maxZoom: 19,
        ),
        // Marker vị trí tài xế
        ValueListenableBuilder(
          valueListenable: _controller.isOnline,
          builder: (_, isOnline, _) => MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition,
                width: 48,
                height: 48,
                child: _DriverMarker(isOnline: isOnline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// AppBar nổi trong suốt phía trên bản đồ
  Widget _buildFloatingAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withAlpha(230)
              : Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ValueListenableBuilder(
          valueListenable: _controller.userModel,
          builder: (_, user, _) => Row(
            children: [
              // Avatar tài xế
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),

              // Tên tài xế + rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.fullName ?? 'Tài xế JetPost',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller.driverModel,
                      builder: (_, driver, _) => Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            driver != null
                                ? driver.rating.toStringAsFixed(1)
                                : '5.0',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.motorcycle_rounded,
                              color: AppColors.textSecondaryLight, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            driver?.plateNumber ?? '---',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Nút Profile / Ví - Bấm để xem màn hình Thu nhập
              InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.driverIncome),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: ValueListenableBuilder(
                    valueListenable: _controller.driverModel,
                    builder: (_, driver, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '💰 ${CurrencyFormatter.format(driver?.walletBalance ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          '${driver?.totalTrips ?? 0} cuốc ›',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Panel dưới cùng: switch online/offline + stats hôm nay
  Widget _buildBottomPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Toggle Online/Offline ─────────────────────────────────
              ValueListenableBuilder<bool>(
                valueListenable: _controller.isOnline,
                builder: (_, isOnline, _) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline
                                ? '🟢 Đang nhận đơn'
                                : '⚫ Offline — Không nhận đơn',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isOnline
                                  ? AppColors.driverOnline
                                  : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                            ),
                          ),
                          Text(
                            isOnline
                                ? 'Hệ thống đang tìm đơn cho bạn'
                                : 'Bật switch để bắt đầu nhận đơn',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _controller.isLoading,
                      builder: (_, loading, _) => Switch.adaptive(
                        value: isOnline,
                        onChanged: loading
                            ? null
                            : (_) => _controller.toggleOnline(),
                        activeTrackColor: AppColors.primaryLight,
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Stats hôm nay ────────────────────────────────────────
              ValueListenableBuilder(
                valueListenable: _controller.driverModel,
                builder: (_, driver, _) => Row(
                  children: [
                    _StatTile(
                      icon: Icons.motorcycle_rounded,
                      label: 'Tổng cuốc',
                      value: '${driver?.totalTrips ?? 0}',
                      color: AppColors.primary,
                    ),
                    _StatDivider(),
                    _StatTile(
                      icon: Icons.star_rounded,
                      label: 'Đánh giá',
                      value: driver != null
                          ? '${driver.rating.toStringAsFixed(1)} ⭐'
                          : '5.0 ⭐',
                      color: Colors.amber,
                    ),
                    _StatDivider(),
                    _StatTile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Ví ›',
                      value: CurrencyFormatter.format(
                          driver?.walletBalance ?? 0),
                      color: AppColors.success,
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.driverIncome),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút định vị lại về vị trí tài xế
  Widget _buildLocateMeButton() {
    return FloatingActionButton.small(
      heroTag: 'locate_me',
      onPressed: () {
        _mapController.move(_currentPosition, 15);
      },
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primary,
      elevation: 4,
      child: const Icon(Icons.my_location_rounded),
    );
  }
}

/// Marker xe máy cho tài xế trên bản đồ
class _DriverMarker extends StatelessWidget {
  final bool isOnline;
  const _DriverMarker({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isOnline ? AppColors.driverOnline : AppColors.textSecondaryLight,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppColors.driverOnline : Colors.grey)
                .withAlpha(120),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.motorcycle_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

/// Tile thống kê nhỏ
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: content,
              ),
            )
          : content,
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.borderDark
          : AppColors.borderLight,
    );
  }
}
