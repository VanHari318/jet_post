import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.2 - Bàn cờ Điều hành Radar Thời gian thực (Live Dispatcher Map)
/// Giám sát trực tiếp mật độ tài xế Online (Xanh) và Đang giao/chở khách (Đỏ) toàn thành phố
/// trên nền bản đồ đường phố thực tế OpenStreetMap (FlutterMap)
class AdminRadarScreen extends StatefulWidget {
  final UserModel adminUser;

  const AdminRadarScreen({super.key, required this.adminUser});

  @override
  State<AdminRadarScreen> createState() => _AdminRadarScreenState();
}

class _AdminRadarScreenState extends State<AdminRadarScreen> {
  final _controller = AdminController();
  final MapController _mapController = MapController();

  DriverModel? _selectedDriver;
  UserModel? _selectedDriverUser;
  bool _showOnlyOnline = true;
  bool _mapReady = false;
  double _currentZoom = 14.2;

  // Tâm bản đồ mặc định: Khu vực Đống Đa / ĐH Thủy Lợi (21.0074, 105.8247)
  static const LatLng _defaultCenter = LatLng(21.0074, 105.8247);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Lấy tọa độ hiển thị trên bản đồ cho tài xế (dùng tọa độ thật, hoặc phân bổ quanh tâm nếu chưa có GPS)
  LatLng _resolveDriverPosition(DriverModel drv, int index) {
    if (drv.currentLat != 0 && drv.currentLng != 0) {
      return LatLng(drv.currentLat, drv.currentLng);
    }
    final angle = (index * 1.7) % (2 * math.pi);
    final radiusDeg = 0.004 + (index % 3) * 0.003;
    return LatLng(
      _defaultCenter.latitude + radiusDeg * math.sin(angle),
      _defaultCenter.longitude + radiusDeg * math.cos(angle),
    );
  }

  Future<void> _onSelectDriver(DriverModel driver, [int index = 0]) async {
    setState(() {
      _selectedDriver = driver;
      _selectedDriverUser = null;
    });

    if (_mapReady) {
      final targetPos = _resolveDriverPosition(driver, index);
      _currentZoom = math.max(_currentZoom, 15.5);
      _mapController.move(targetPos, _currentZoom);
    }

    final userInfo = await _controller.getUserByDriverId(driver.id);
    if (!mounted) return;
    setState(() => _selectedDriverUser = userInfo);
  }

  void _fitAllDrivers(List<DriverModel> drivers) {
    if (!_mapReady) return;
    if (drivers.isEmpty) {
      _currentZoom = 14.2;
      _mapController.move(_defaultCenter, _currentZoom);
      return;
    }
    if (drivers.length == 1) {
      final pos = _resolveDriverPosition(drivers.first, 0);
      _currentZoom = 15.0;
      _mapController.move(pos, _currentZoom);
      return;
    }
    final points = drivers
        .asMap()
        .entries
        .map((e) => _resolveDriverPosition(e.value, e.key))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _currentZoom = (camera.zoom + delta).clamp(5.0, 18.5);
    _mapController.move(camera.center, _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Điều hành'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              const Text(
                'Chỉ Online',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Switch(
                value: _showOnlyOnline,
                onChanged: (v) => setState(() => _showOnlyOnline = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryDark,
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<DriverModel>>(
        stream: _showOnlyOnline
            ? _controller.watchAllOnlineDrivers()
            : _controller.watchAllActiveDrivers(),
        builder: (context, snapshot) {
          final drivers = snapshot.data ?? [];
          final onlineReadyCount =
              drivers.where((d) => d.isOnline && !d.isBusy).length;
          final busyCount = drivers.where((d) => d.isBusy).length;

          return Column(
            children: [
              // Bản đồ OpenStreetMap Radar Điều hành Tương tác (Task 4.2)
              _InteractiveRadarMap(
                mapController: _mapController,
                drivers: drivers,
                selectedDriver: _selectedDriver,
                onlineReadyCount: onlineReadyCount,
                busyCount: busyCount,
                resolvePosition: _resolveDriverPosition,
                onMapReady: () {
                  _mapReady = true;
                  if (drivers.isNotEmpty) {
                    _fitAllDrivers(drivers);
                  }
                },
                onTapDriver: _onSelectDriver,
                onFitAll: () => _fitAllDrivers(drivers),
                onZoomIn: () => _zoomBy(1.0),
                onZoomOut: () => _zoomBy(-1.0),
              ),

              // Thẻ thông tin chi tiết khi Admin chạm vào Marker hoặc dòng tài xế
              if (_selectedDriver != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DriverRadarMarkerInfo(
                    driver: _selectedDriver!,
                    userInfo: _selectedDriverUser,
                    onClose: () => setState(() {
                      _selectedDriver = null;
                      _selectedDriverUser = null;
                    }),
                  ),
                ),

              // Danh sách tài xế thời gian thực
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : drivers.isEmpty
                        ? _EmptyRadar(
                            isOnline: _showOnlyOnline,
                            onSeedDemo: () => _controller
                                .seedDemoAdminData(widget.adminUser.id),
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.driverOnline,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${drivers.length} tài xế trên bản đồ ($onlineReadyCount sẵn sàng, $busyCount đang chạy)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _fitAllDrivers(drivers),
                                      icon: const Icon(
                                        Icons.center_focus_strong,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Toàn cảnh',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: drivers.length,
                                  itemBuilder: (context, index) {
                                    final driver = drivers[index];
                                    final isSelected =
                                        _selectedDriver?.id == driver.id;
                                    return _DriverRadarListTile(
                                      driver: driver,
                                      isSelected: isSelected,
                                      onTap: () =>
                                          _onSelectDriver(driver, index),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InteractiveRadarMap extends StatelessWidget {
  final MapController mapController;
  final List<DriverModel> drivers;
  final DriverModel? selectedDriver;
  final int onlineReadyCount;
  final int busyCount;
  final LatLng Function(DriverModel, int) resolvePosition;
  final VoidCallback onMapReady;
  final void Function(DriverModel, int) onTapDriver;
  final VoidCallback onFitAll;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _InteractiveRadarMap({
    required this.mapController,
    required this.drivers,
    required this.selectedDriver,
    required this.onlineReadyCount,
    required this.busyCount,
    required this.resolvePosition,
    required this.onMapReady,
    required this.onTapDriver,
    required this.onFitAll,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  // Tâm bản đồ mặc định: Khu vực Đống Đa / ĐH Thủy Lợi (21.0074, 105.8247)
  static const LatLng _defaultCenter = LatLng(21.0074, 105.8247);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Bản đồ đường phố thực tế OpenStreetMap
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14.2,
              onMapReady: onMapReady,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jet_post',
                maxZoom: 19,
              ),

              // Vòng phủ sóng Radar trung tâm (Bán kính 2.5km quanh tâm điều hành)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _defaultCenter,
                    radius: 2500,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderColor: AppColors.primary.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // 2. Các Marker xe máy gắn đúng tọa độ GPS trên bản đồ
              MarkerLayer(
                markers: drivers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final drv = entry.value;
                  final pos = resolvePosition(drv, idx);
                  final isSelected = selectedDriver?.id == drv.id;
                  final markerColor = drv.isBusy
                      ? AppColors.driverBusy
                      : (drv.isOnline
                          ? AppColors.driverOnline
                          : AppColors.textMutedLight);

                  return Marker(
                    point: pos,
                    width: 86,
                    height: 64,
                    child: GestureDetector(
                      onTap: () => onTapDriver(drv, idx),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected ? markerColor : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: markerColor,
                                width: isSelected ? 3.0 : 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: markerColor.withValues(alpha: 0.45),
                                  blurRadius: isSelected ? 12 : 6,
                                  spreadRadius: isSelected ? 2 : 0,
                                ),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: (drv.heading * math.pi) / 180,
                              child: Icon(
                                Icons.two_wheeler,
                                size: isSelected ? 20 : 16,
                                color: isSelected ? Colors.white : markerColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? markerColor
                                  : Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              drv.plateNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 3. Chú thích màu sắc Marker (Legend) góc trên trái
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendDot(
                    color: AppColors.driverOnline,
                    label: 'Sẵn sàng ($onlineReadyCount)',
                  ),
                  const SizedBox(width: 12),
                  _LegendDot(
                    color: AppColors.driverBusy,
                    label: 'Đang chạy ($busyCount)',
                  ),
                ],
              ),
            ),
          ),

          // 4. Cụm nút điều khiển Zoom +/- và căn tâm bản đồ góc phải
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                _MapActionButton(
                  icon: Icons.add,
                  tooltip: 'Phóng to',
                  onTap: onZoomIn,
                ),
                const SizedBox(height: 6),
                _MapActionButton(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ',
                  onTap: onZoomOut,
                ),
                const SizedBox(height: 6),
                _MapActionButton(
                  icon: Icons.my_location,
                  tooltip: 'Căn toàn bộ tài xế',
                  onTap: onFitAll,
                ),
              ],
            ),
          ),

          // 5. Nhãn địa danh nền bản đồ Hà Nội góc dưới trái
          Positioned(
            left: 10,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '📍 OpenStreetMap • Tâm Radar: Đống Đa - ĐH Thủy Lợi',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DriverRadarListTile extends StatelessWidget {
  final DriverModel driver;
  final bool isSelected;
  final VoidCallback onTap;

  const _DriverRadarListTile({
    required this.driver,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = driver.isBusy;
    final statusColor =
        isBusy ? AppColors.driverBusy : AppColors.driverOnline;
    final statusText = isBusy ? 'Đang chạy cuốc' : 'Sẵn sàng';

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primaryLight,
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(Icons.motorcycle, color: statusColor),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        '${driver.plateNumber} • ${driver.vehicleType}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        'GPS: ${driver.currentLat.toStringAsFixed(4)}, ${driver.currentLng.toStringAsFixed(4)} • Hướng: ${driver.heading.toStringAsFixed(0)}°',
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          statusText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}

class _EmptyRadar extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onSeedDemo;

  const _EmptyRadar({
    required this.isOnline,
    required this.onSeedDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 48,
              color: AppColors.textMutedLight,
            ),
            const SizedBox(height: 12),
            Text(
              isOnline
                   ? 'Chưa có tài xế nào đang bật Online'
                  : 'Chưa có tài xế nào đang hoạt động',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSeedDemo,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Tạo Tài xế Mẫu trên Radar'),
            ),
          ],
        ),
      ),
    );
  }
}
