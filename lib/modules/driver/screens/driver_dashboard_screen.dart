import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../controllers/driver_dashboard_controller.dart';
import '../widgets/driver_navigation_drawer.dart';
import '../services/driver_order_preferences.dart';
import '../services/driver_location_service.dart';
import '../../../routes/app_routes.dart';

/// Màn hình chính của tài xế — hiển thị bản đồ OSM + toggle online/offline
/// Lắng nghe đơn mới và hiện IncomingOrderSheet khi có cuốc phù hợp
class DriverDashboardScreen extends StatefulWidget {
  final bool suppressActiveTripRedirect;

  const DriverDashboardScreen({
    super.key,
    this.suppressActiveTripRedirect = false,
  });

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final DriverDashboardController _controller;
  late final TabController _tabController;
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final DriverOrderPreferences _orderPreferences =
      DriverOrderPreferences.instance;
  StreamSubscription<Position>? _positionSubscription;
  Future<void>? _locationTrackingTask;

  LatLng? _currentPosition;
  LatLng? _lastOrderSearchPosition;
  bool _isGettingLocation = true;
  String? _locationError;
  bool _mapReady = false;
  bool _mapHasError = false;
  int _mapReloadToken = 0;
  double _searchRadiusKm = 1;
  String _orderFilter = 'Tất cả';
  bool _isLoadingActiveTrip = false;
  bool _isAcceptingOrder = false;
  double _sheetExtent = 0.16;
  String? _activeTripId;
  String? _activeTripType;
  RideModel? _activeRide;
  DeliveryModel? _activeDelivery;
  bool _autoAcceptInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _controller = DriverDashboardController();
    unawaited(_orderPreferences.load());
    unawaited(_controller.init());
    _orderPreferences.value.addListener(_onOrdersChanged);
    _controller.driverModel.addListener(_onDriverModelChanged);
    _controller.pendingRides.addListener(_onOrdersChanged);
    _controller.pendingDeliveries.addListener(_onOrdersChanged);
    _controller.errorMessage.addListener(_onError);
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _sheetController.dispose();
    _orderPreferences.value.removeListener(_onOrdersChanged);
    _controller.driverModel.removeListener(_onDriverModelChanged);
    _controller.pendingRides.removeListener(_onOrdersChanged);
    _controller.pendingDeliveries.removeListener(_onOrdersChanged);
    _controller.errorMessage.removeListener(_onError);
    unawaited(_positionSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  /// Đồng bộ trạng thái bận và chuyến hiện tại từ DriverModel
  void _onDriverModelChanged() {
    final driver = _controller.driverModel.value;
    if (driver == null) return;
    if (driver.isBusy && driver.activeTripId != null) {
      if (_activeTripId != driver.activeTripId) {
        _activeTripId = driver.activeTripId;
        _activeRide = null;
        _activeDelivery = null;
        unawaited(_loadActiveTrip(driver.activeTripId!));
      }
      if (_tabController.index != 1) _tabController.animateTo(1);
    } else if (_activeTripId != null) {
      setState(() {
        _activeTripId = null;
        _activeRide = null;
        _activeDelivery = null;
        _activeTripType = null;
      });
    }
  }

  Future<void> _startLocationTracking() async {
    final activeTask = _locationTrackingTask;
    if (activeTask != null) {
      await activeTask;
      return;
    }

    final task = _loadLocationTracking();
    _locationTrackingTask = task;
    try {
      await task;
    } finally {
      if (identical(_locationTrackingTask, task)) {
        _locationTrackingTask = null;
      }
    }
  }

  Future<void> _loadLocationTracking() async {
    if (!mounted) return;
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      final position = await DriverLocationService.getCurrentPosition();
      if (!mounted) return;
      _onPositionChanged(position);

      await _positionSubscription?.cancel();
      _positionSubscription = DriverLocationService.getPositionStream().listen(
        _onPositionChanged,
        onError: (Object error) {
          _showLocationError(
            'Mất kết nối GPS. Vui lòng kiểm tra dịch vụ vị trí của thiết bị.',
          );
        },
      );
    } on DriverLocationException catch (error) {
      _showLocationError(error.message);
    } on TimeoutException {
      _showLocationError(
        'Không nhận được vị trí GPS. Hãy kiểm tra tín hiệu hoặc vị trí máy ảo.',
      );
    } catch (error) {
      debugPrint('Không thể lấy vị trí tài xế: $error');
      _showLocationError('Không thể xác định vị trí hiện tại của thiết bị.');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _onPositionChanged(Position position) {
    if (!mounted) return;
    final currentPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = currentPosition;
      _locationError = null;
    });
    if (_mapReady) _mapController.move(currentPosition, 15);
    final lastSearchPosition = _lastOrderSearchPosition;
    final refreshDistanceKm = _searchRadiusKm <= 0 ? 1 : _searchRadiusKm / 2;
    if (lastSearchPosition == null ||
        const Distance().as(
              LengthUnit.Kilometer,
              lastSearchPosition,
              currentPosition,
            ) >=
            refreshDistanceKm) {
      unawaited(_refreshAvailableOrders());
    }
    if (_controller.isOnline.value) {
      unawaited(
        _controller.updateLocation(
          position.latitude,
          position.longitude,
          position.heading,
        ),
      );
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _isGettingLocation = false;
    });
  }

  Future<void> _toggleOnline() async {
    if (!_controller.isOnline.value && _currentPosition == null) {
      await _startLocationTracking();
    }
    final currentPosition = _currentPosition;
    if (!_controller.isOnline.value && currentPosition == null) return;
    await _controller.toggleOnline(currentPosition: currentPosition);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadActiveTrip(String tripId) async {
    if (!mounted) return;
    setState(() => _isLoadingActiveTrip = true);
    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(tripId)
          .get();
      if (!mounted) return;
      if (rideDoc.exists) {
        setState(() {
          _activeRide = RideModel.fromFirestore(rideDoc);
          _activeDelivery = null;
          _activeTripType = 'ride';
          _isLoadingActiveTrip = false;
        });
        return;
      }

      final deliveryDoc = await FirebaseFirestore.instance
          .collection('deliveries')
          .doc(tripId)
          .get();
      if (!mounted) return;
      setState(() {
        _activeDelivery = deliveryDoc.exists
            ? DeliveryModel.fromFirestore(deliveryDoc)
            : null;
        _activeRide = null;
        _activeTripType = deliveryDoc.exists ? 'delivery' : null;
        _isLoadingActiveTrip = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingActiveTrip = false);
        _controller.errorMessage.value =
            'Không thể tải thông tin chuyến đang làm.';
      }
    }
  }

  /// Điều hướng sang màn hình chi tiết chuyến đang thực hiện
  void _navigateToTrip(String tripId, {required String tripType}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.driverTrip,
      arguments: {
        'tripId': tripId,
        'tripType': tripType,
        'driverUid': _controller.driverUid,
        'driverName': _controller.userModel.value?.fullName ?? 'Tài xế JetPost',
        'avatarUrl': _controller.userModel.value?.avatarUrl,
      },
    );
  }

  /// Khi có đơn mới → hiện IncomingOrderSheet
  void _onOrdersChanged() {
    unawaited(_autoAcceptEligibleOrder());
  }

  Future<void> _autoAcceptEligibleOrder() async {
    final preferences = _orderPreferences.value.value;
    if (_autoAcceptInProgress ||
        _controller.driverModel.value?.isBusy == true ||
        !_controller.isOnline.value) {
      return;
    }

    final distance = const Distance();
    bool isWithinLimit(double lat, double lng, double maxKm) {
      final currentPosition = _currentPosition;
      if (lat == 0 || lng == 0 || currentPosition == null) return false;
      final km = distance.as(
        LengthUnit.Kilometer,
        currentPosition,
        LatLng(lat, lng),
      );
      return maxKm <= 0 || km < maxKm;
    }

    RideModel? ride;
    if (preferences.autoAcceptRides) {
      for (final item in _controller.pendingRides.value) {
        if (isWithinLimit(
          item.pickupLat,
          item.pickupLng,
          preferences.rideMaxDistanceKm,
        )) {
          ride = item;
          break;
        }
      }
    }

    DeliveryModel? delivery;
    if (ride == null && preferences.autoAcceptDeliveries) {
      for (final item in _controller.pendingDeliveries.value) {
        if (isWithinLimit(
              item.pickupLat,
              item.pickupLng,
              preferences.deliveryMaxDistanceKm,
            ) &&
            (preferences.deliveryCodLimit <= 0 ||
                item.codAmount < preferences.deliveryCodLimit)) {
          delivery = item;
          break;
        }
      }
    }
    if (ride == null && delivery == null) return;

    _autoAcceptInProgress = true;
    final accepted = ride != null
        ? await _controller.acceptRide(ride)
        : await _controller.acceptDelivery(delivery!);
    _autoAcceptInProgress = false;
    if (!mounted || !accepted) return;
    _activeTripId = ride?.id ?? delivery!.id;
    _activeTripType = ride == null ? 'delivery' : 'ride';
    await _loadActiveTrip(_activeTripId!);
    if (mounted) _tabController.animateTo(1);
  }

  Future<void> _refreshAvailableOrders() {
    final currentPosition = _currentPosition;
    if (currentPosition == null) return Future<void>.value();
    _lastOrderSearchPosition = currentPosition;
    return _controller.refreshAvailableOrders(
      center: currentPosition,
      radiusKm: _searchRadiusKm,
      filter: _orderFilter == 'Cuốc xe'
          ? 'ride'
          : _orderFilter == 'Giao hàng'
          ? 'delivery'
          : 'all',
    );
  }

  Future<void> _acceptManualRide(RideModel ride) async {
    if (_isAcceptingOrder) return;
    if (_controller.driverModel.value == null ||
        _controller.driverUid.isEmpty) {
      _controller.errorMessage.value =
          'Đăng nhập và hoàn tất hồ sơ tài xế để nhận đơn.';
      return;
    }
    setState(() => _isAcceptingOrder = true);
    final accepted = await _controller.acceptRide(ride);
    if (!mounted) return;
    setState(() => _isAcceptingOrder = false);
    if (accepted) {
      _activeTripId = ride.id;
      _activeTripType = 'ride';
      await _loadActiveTrip(ride.id);
      if (mounted) _tabController.animateTo(1);
    }
  }

  Future<void> _acceptManualDelivery(DeliveryModel delivery) async {
    if (_isAcceptingOrder) return;
    if (_controller.driverModel.value == null ||
        _controller.driverUid.isEmpty) {
      _controller.errorMessage.value =
          'Đăng nhập và hoàn tất hồ sơ tài xế để nhận đơn.';
      return;
    }
    setState(() => _isAcceptingOrder = true);
    final accepted = await _controller.acceptDelivery(delivery);
    if (!mounted) return;
    setState(() => _isAcceptingOrder = false);
    if (accepted) {
      _activeTripId = delivery.id;
      _activeTripType = 'delivery';
      await _loadActiveTrip(delivery.id);
      if (mounted) _tabController.animateTo(1);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ValueListenableBuilder(
        valueListenable: _controller.userModel,
        builder: (_, user, _) => ValueListenableBuilder<bool>(
          valueListenable: _controller.isOnline,
          builder: (_, isOnline, _) => DriverNavigationDrawer(
            driverName: user?.fullName ?? 'Tài xế JetPost',
            avatarUrl: user?.avatarUrl,
            isOnline: isOnline,
            isDemoMode: _controller.isDemoMode,
            currentRoute: AppRoutes.driverDashboard,
            onToggleOnline: () => unawaited(_toggleOnline()),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Bản đồ OpenStreetMap toàn màn hình ───────────────────────
          _buildMap(),

          // ── AppBar nổi phía trên bản đồ ───────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: _buildFloatingAppBar()),

          if (_tabController.index == 0) ...[
            Positioned(top: 190, left: 12, child: _buildRadiusControls()),
            Positioned(top: 190, right: 12, child: _buildOrderFilter()),
          ],

          if (_mapHasError)
            Positioned(
              left: 16,
              bottom: MediaQuery.sizeOf(context).height * _sheetExtent + 12,
              child: _buildMapErrorNotice(),
            ),

          Positioned.fill(
            key: const ValueKey('driver-dashboard-order-sheet-position'),
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if ((_sheetExtent - notification.extent).abs() >= 0.01) {
                  setState(() => _sheetExtent = notification.extent);
                }
                return false;
              },
              child: DraggableScrollableSheet(
                key: const ValueKey('driver-dashboard-order-sheet'),
                controller: _sheetController,
                initialChildSize: _sheetExtent,
                minChildSize: 0.12,
                maxChildSize: 0.68,
                snap: true,
                snapSizes: const [0.12, 0.4, 0.68],
                builder: (context, scrollController) =>
                    _buildBottomPanel(scrollController),
              ),
            ),
          ),

          // ── Nút định vị lại (về vị trí tài xế) ───────────────────────
          if (_tabController.index == 0)
            Positioned(
              right: 16,
              bottom: MediaQuery.sizeOf(context).height * _sheetExtent + 12,
              child: _buildLocateMeButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildMapErrorNotice() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Không tải được bản đồ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: 'Tải lại bản đồ',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _mapHasError = false;
                  _mapReloadToken++;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  /// Bản đồ OSM với marker vị trí tài xế
  Widget _buildMap() {
    final currentPosition = _currentPosition;
    if (currentPosition == null) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGettingLocation) const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  _locationError ?? 'Đang lấy vị trí GPS của thiết bị...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentPosition,
        initialZoom: 15,
        onMapReady: () {
          _mapReady = true;
          _mapController.move(currentPosition, 15);
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile layer OpenStreetMap
        TileLayer(
          key: ValueKey(_mapReloadToken),
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.jet_post',
          maxZoom: 19,
          errorTileCallback: (_, _, _) {
            if (mounted && !_mapHasError) {
              setState(() => _mapHasError = true);
            }
          },
        ),
        if (_tabController.index == 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: currentPosition,
                radius: _searchRadiusKm * 1000,
                useRadiusInMeter: true,
                color: AppColors.primary.withAlpha(28),
                borderColor: AppColors.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        // Marker tài xế và các đơn quanh vị trí hiện tại
        ValueListenableBuilder<List<RideModel>>(
          valueListenable: _controller.availableRides,
          builder: (_, rides, _) => ValueListenableBuilder<List<DeliveryModel>>(
            valueListenable: _controller.availableDeliveries,
            builder: (_, deliveries, _) => ValueListenableBuilder<bool>(
              valueListenable: _controller.isOnline,
              builder: (_, isOnline, _) => MarkerLayer(
                markers: [
                  Marker(
                    point: currentPosition,
                    width: 48,
                    height: 48,
                    child: _DriverMarker(isOnline: isOnline),
                  ),
                  if (_tabController.index == 0)
                    ...rides.map(
                      (ride) => Marker(
                        point: LatLng(ride.pickupLat, ride.pickupLng),
                        width: 38,
                        height: 38,
                        child: const _OrderMapMarker(
                          icon: Icons.motorcycle_rounded,
                        ),
                      ),
                    ),
                  if (_tabController.index == 0)
                    ...deliveries.map(
                      (delivery) => Marker(
                        point: LatLng(delivery.pickupLat, delivery.pickupLng),
                        width: 38,
                        height: 38,
                        child: const _OrderMapMarker(
                          icon: Icons.local_shipping_rounded,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );
  }

  /// AppBar nổi trong suốt phía trên bản đồ
  Widget _buildFloatingAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Mở menu tài xế',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ),
                  // Avatar tài xế
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 20,
                          )
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
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ValueListenableBuilder(
                          valueListenable: _controller.driverModel,
                          builder: (_, driver, _) => Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                driver != null
                                    ? driver.rating.toStringAsFixed(1)
                                    : '5.0',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.motorcycle_rounded,
                                color: AppColors.textSecondaryLight,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                driver?.plateNumber ?? '---',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút Profile / Ví - Bấm để xem màn hình Thu nhập
                  InkWell(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.driverIncome),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
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
                                color: AppColors.textSecondaryLight,
                              ),
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark.withAlpha(230)
                  : Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryLight,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Tự chọn đơn'),
                Tab(text: 'Đang làm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusControls() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Tăng bán kính tìm đơn',
            onPressed: () {
              setState(() {
                _searchRadiusKm = (_searchRadiusKm + 0.5).clamp(0.5, 20);
              });
              _refreshAvailableOrders();
            },
            icon: const Icon(Icons.add_rounded),
          ),
          Text(
            '${_searchRadiusKm.toStringAsFixed(_searchRadiusKm % 1 == 0 ? 0 : 1)} km',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Giảm bán kính tìm đơn',
            onPressed: () {
              setState(() {
                _searchRadiusKm = (_searchRadiusKm - 0.5).clamp(0.5, 20);
              });
              _refreshAvailableOrders();
            },
            icon: const Icon(Icons.remove_rounded),
          ),
          const Divider(height: 1),
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isSearchingOrders,
            builder: (_, loading, _) => IconButton(
              tooltip: 'Tìm lại đơn quanh đây',
              onPressed: loading ? null : _refreshAvailableOrders,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFilter() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _orderFilter,
            borderRadius: BorderRadius.circular(12),
            items: const [
              DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả')),
              DropdownMenuItem(value: 'Cuốc xe', child: Text('Cuốc xe')),
              DropdownMenuItem(value: 'Giao hàng', child: Text('Giao hàng')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _orderFilter = value);
              _refreshAvailableOrders();
            },
          ),
        ),
      ),
    );
  }

  /// Panel dưới cùng hiển thị danh sách đơn hoặc chuyến đang làm
  Widget _buildBottomPanel(ScrollController scrollController) {
    final isExpanded = _sheetExtent > 0.2;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMutedLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tabController.index == 0
                            ? 'Đơn quanh bạn'
                            : 'Đang làm',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_tabController.index == 0)
                      ValueListenableBuilder<List<RideModel>>(
                        valueListenable: _controller.availableRides,
                        builder: (_, rides, _) =>
                            ValueListenableBuilder<List<DeliveryModel>>(
                              valueListenable: _controller.availableDeliveries,
                              builder: (_, deliveries, _) => Text(
                                '${rides.length + deliveries.length} đơn',
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                      ),
                    IconButton(
                      tooltip: isExpanded
                          ? 'Thu gọn bảng đơn'
                          : 'Mở rộng bảng đơn',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _sheetController.animateTo(
                        isExpanded ? 0.12 : 0.68,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                      ),
                    ),
                  ],
                ),
                if (_tabController.index == 0)
                  _buildFreePickPanel()
                else
                  _buildActiveTripPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreePickPanel() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isOnline,
                builder: (_, isOnline, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'Đang nhận đơn' : 'Đang offline',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isOnline
                            ? AppColors.driverOnline
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const Text(
                      'Tự bật trạng thái để hệ thống tự nhận đơn',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _controller.isOnline,
              builder: (_, online, _) => Switch.adaptive(
                value: online,
                onChanged: (_) => unawaited(_toggleOnline()),
                activeTrackColor: AppColors.primaryLight,
                activeThumbColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const Divider(height: 12),
        _buildAvailableOrderList(),
      ],
    );
  }

  Widget _buildAvailableOrderList() {
    return ValueListenableBuilder<List<RideModel>>(
      valueListenable: _controller.availableRides,
      builder: (_, rides, _) => ValueListenableBuilder<List<DeliveryModel>>(
        valueListenable: _controller.availableDeliveries,
        builder: (_, deliveries, _) {
          final itemCount = rides.length + deliveries.length;
          if (itemCount == 0) {
            return ValueListenableBuilder<bool>(
              valueListenable: _controller.isSearchingOrders,
              builder: (_, loading, _) => Center(
                child: Text(
                  loading
                      ? 'Đang tìm đơn trong bán kính ${_searchRadiusKm.toStringAsFixed(1)} km...'
                      : 'Chưa tìm thấy đơn trong bán kính này.\nNhấn nút làm mới để tìm lại.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (var index = 0; index < itemCount; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                if (index < rides.length)
                  _buildRideOrderCard(rides[index])
                else
                  _buildDeliveryOrderCard(deliveries[index - rides.length]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRideOrderCard(RideModel ride) {
    return _OrderCard(
      icon: Icons.motorcycle_rounded,
      label: 'Cuốc xe',
      pickup: ride.pickupAddress,
      dropoff: ride.dropoffAddress,
      distanceKm: ride.distanceKm,
      price: ride.price,
      isAccepting: _isAcceptingOrder,
      onAccept: () => _acceptManualRide(ride),
    );
  }

  Widget _buildDeliveryOrderCard(DeliveryModel delivery) {
    return _OrderCard(
      icon: Icons.local_shipping_rounded,
      label: 'Giao hàng',
      pickup: delivery.pickupAddress,
      dropoff: delivery.dropoffAddress,
      distanceKm: delivery.distanceKm,
      price: delivery.price,
      codAmount: delivery.codAmount,
      isAccepting: _isAcceptingOrder,
      onAccept: () => _acceptManualDelivery(delivery),
    );
  }

  Widget _buildActiveTripPanel() {
    if (_isLoadingActiveTrip) {
      return const Center(child: CircularProgressIndicator());
    }

    final ride = _activeRide;
    final delivery = _activeDelivery;
    if (ride == null && delivery == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: AppColors.textMutedLight,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn chưa có đơn nào',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Tự tìm đơn'),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          delivery == null
              ? 'Cuốc xe đang thực hiện'
              : 'Đơn giao hàng đang làm',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _OrderCard(
          icon: delivery == null
              ? Icons.motorcycle_rounded
              : Icons.local_shipping_rounded,
          label: delivery == null ? 'Cuốc xe' : 'Giao hàng',
          pickup: ride?.pickupAddress ?? delivery!.pickupAddress,
          dropoff: ride?.dropoffAddress ?? delivery!.dropoffAddress,
          distanceKm: ride?.distanceKm ?? delivery!.distanceKm,
          price: ride?.price ?? delivery!.price,
          isActive: true,
          onAccept: () => _navigateToTrip(
            _activeTripId!,
            tripType: _activeTripType ?? 'ride',
          ),
        ),
      ],
    );
  }

  /// Nút định vị lại về vị trí tài xế
  Widget _buildLocateMeButton() {
    return FloatingActionButton.small(
      heroTag: 'locate_me',
      onPressed: _currentPosition == null
          ? () => unawaited(_startLocationTracking())
          : () => _mapReady
                ? _mapController.move(_currentPosition!, 15)
                : null,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primary,
      elevation: 4,
      child: const Icon(Icons.my_location_rounded),
    );
  }
}

class _OrderMapMarker extends StatelessWidget {
  final IconData icon;

  const _OrderMapMarker({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(70),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
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
            color: (isOnline ? AppColors.driverOnline : Colors.grey).withAlpha(
              120,
            ),
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

class _OrderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String pickup;
  final String dropoff;
  final double distanceKm;
  final double price;
  final double? codAmount;
  final bool isAccepting;
  final bool isActive;
  final VoidCallback onAccept;

  const _OrderCard({
    required this.icon,
    required this.label,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.price,
    this.codAmount,
    this.isAccepting = false,
    this.isActive = false,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 9, color: AppColors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, size: 12, color: AppColors.secondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.format(price),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (codAmount != null && codAmount! > 0)
                Text(
                  'COD ${CurrencyFormatter.format(codAmount!)}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: isAccepting ? null : onAccept,
              child: isAccepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isActive ? 'Xem chi tiết chuyến' : 'Nhận đơn'),
            ),
          ),
        ],
      ),
    );
  }
}
