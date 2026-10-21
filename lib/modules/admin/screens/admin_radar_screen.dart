import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.2 - Bàn cờ Điều hành Radar Thời gian thực
/// Giám sát toàn bộ tài xế Online/Busy trên bản đồ (dùng ListView do không có flutter_map)
class AdminRadarScreen extends StatefulWidget {
  final UserModel adminUser;

  const AdminRadarScreen({super.key, required this.adminUser});

  @override
  State<AdminRadarScreen> createState() => _AdminRadarScreenState();
}

class _AdminRadarScreenState extends State<AdminRadarScreen> {
  final _controller = AdminController();
  DriverModel? _selectedDriver;
  UserModel? _selectedDriverUser;
  bool _showOnlyOnline = true;

  Future<void> _onSelectDriver(DriverModel driver) async {
    setState(() {
      _selectedDriver = driver;
      _selectedDriverUser = null;
    });
    final userInfo = await _controller.getUserByDriverId(driver.id);
    setState(() => _selectedDriverUser = userInfo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Điều hành'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Toggle filter
          Row(
            children: [
              const Text('Chỉ Online',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Switch(
                value: _showOnlyOnline,
                onChanged: (v) => setState(() => _showOnlyOnline = v),
                activeColor: Colors.white,
                activeTrackColor: AppColors.primaryLight,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Bản đồ giả lập (vì không có flutter_map trong pubspec)
          _RadarMapPlaceholder(
            selectedDriver: _selectedDriver,
          ),
          // Driver Info Card khi chọn
          if (_selectedDriver != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DriverRadarMarkerInfo(
                driver: _selectedDriver!,
                userInfo: _selectedDriverUser,
                onClose: () => setState(() {
                  _selectedDriver = null;
                  _selectedDriverUser = null;
                }),
              ),
            ),
          // Danh sách tài xế
          Expanded(
            child: StreamBuilder<List<DriverModel>>(
              stream: _showOnlyOnline
                  ? _controller.watchAllOnlineDrivers()
                  : _controller.watchAllActiveDrivers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final drivers = snapshot.data ?? [];
                if (drivers.isEmpty) {
                  return _EmptyRadar(isOnline: _showOnlyOnline);
                }
                return Column(
                  children: [
                    // Header count
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Theme.of(context).scaffoldBackgroundColor,
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
                          Text(
                            '${drivers.length} tài xế ${_showOnlyOnline ? "đang online" : "hoạt động"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
                            onTap: () => _onSelectDriver(driver),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarMapPlaceholder extends StatelessWidget {
  final DriverModel? selectedDriver;

  const _RadarMapPlaceholder({this.selectedDriver});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Stack(
        children: [
          // Grid radar pattern
          CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _RadarGridPainter(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.radar,
                  size: 40,
                  color: AppColors.primary.withOpacity(0.8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bản đồ Radar Real-time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Yêu cầu thư viện flutter_map (thêm vào pubspec)',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Animated dots for online drivers
          if (selectedDriver != null)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.driverOnline.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.driverOnline.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.driverOnline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedDriver!.plateNumber,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Center crosshair
    final centerPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
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
    final statusText = isBusy ? 'Đang giao' : 'Sẵn sàng';

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primaryLight,
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.15),
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
                    width: 1.5),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        driver.plateNumber,
        style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        'GPS: ${driver.currentLat.toStringAsFixed(4)}, ${driver.currentLng.toStringAsFixed(4)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
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

  const _EmptyRadar({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 56,
            color: AppColors.textMutedLight,
          ),
          const SizedBox(height: 12),
          Text(
            isOnline
                ? 'Không có tài xế nào đang online'
                : 'Không có tài xế nào hoạt động',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
