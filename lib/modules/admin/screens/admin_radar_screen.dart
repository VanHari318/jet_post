import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../controllers/admin_controller.dart';
import '../widgets/admin_widgets.dart';

/// Task 4.2 - Bàn cờ Điều hành Radar Thời gian thực (Live Dispatcher Map)
/// Giám sát trực tiếp mật độ tài xế Online (Xanh) và Đang giao/chở khách (Đỏ) toàn thành phố
class AdminRadarScreen extends StatefulWidget {
  final UserModel adminUser;

  const AdminRadarScreen({super.key, required this.adminUser});

  @override
  State<AdminRadarScreen> createState() => _AdminRadarScreenState();
}

class _AdminRadarScreenState extends State<AdminRadarScreen>
    with SingleTickerProviderStateMixin {
  final _controller = AdminController();
  DriverModel? _selectedDriver;
  UserModel? _selectedDriverUser;
  bool _showOnlyOnline = true;
  late AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSelectDriver(DriverModel driver) async {
    setState(() {
      _selectedDriver = driver;
      _selectedDriverUser = null;
    });
    final userInfo = await _controller.getUserByDriverId(driver.id);
    if (!mounted) return;
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
              // Bản đồ Radar Điều hành Tương tác (Task 4.2)
              _InteractiveRadarMap(
                drivers: drivers,
                selectedDriver: _selectedDriver,
                sweepAnimation: _sweepCtrl,
                onlineReadyCount: onlineReadyCount,
                busyCount: busyCount,
                onTapDriver: _onSelectDriver,
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
                                    Text(
                                      '${drivers.length} tài xế trên bản đồ ($onlineReadyCount sẵn sàng, $busyCount đang chạy)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
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
  final List<DriverModel> drivers;
  final DriverModel? selectedDriver;
  final Animation<double> sweepAnimation;
  final int onlineReadyCount;
  final int busyCount;
  final ValueChanged<DriverModel> onTapDriver;

  const _InteractiveRadarMap({
    required this.drivers,
    required this.selectedDriver,
    required this.sweepAnimation,
    required this.onlineReadyCount,
    required this.busyCount,
    required this.onTapDriver,
  });

  // Tâm bản đồ mặc định: Khu vực Đống Đa / ĐH Thủy Lợi (21.0074, 105.8247)
  static const double _centerLat = 21.0074;
  static const double _centerLng = 105.8247;
  static const double _spanDeg = 0.025; // Bán kính hiển thị ~2.5km mỗi chiều

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141E2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // 1. Lưới bản đồ & Vòng quét Radar
              AnimatedBuilder(
                animation: sweepAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(w, h),
                    painter: _RadarGridPainter(
                      sweepAngle: sweepAnimation.value * 2 * math.pi,
                    ),
                  );
                },
              ),

              // 2. Nhãn địa danh nền bản đồ Hà Nội
              const Positioned(
                left: 14,
                bottom: 10,
                child: Text(
                  '📍 Tâm Radar: Đống Đa - ĐH Thủy Lợi (21.0074, 105.8247)',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ),

              // 3. Chú thích màu sắc Marker (Legend)
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
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

              // 4. Các Marker xe máy tương tác trên bản đồ
              ...drivers.asMap().entries.map((entry) {
                final idx = entry.key;
                final drv = entry.value;
                final pos = _projectToCanvas(drv, idx, w, h);
                final isSelected = selectedDriver?.id == drv.id;
                final markerColor = drv.isBusy
                    ? AppColors.driverBusy
                    : (drv.isOnline
                        ? AppColors.driverOnline
                        : AppColors.textMutedLight);

                return Positioned(
                  left: (pos.dx - 24).clamp(6.0, w - 54.0),
                  top: (pos.dy - 24).clamp(32.0, h - 52.0),
                  child: GestureDetector(
                    onTap: () => onTapDriver(drv),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: markerColor.withValues(
                                alpha: isSelected ? 0.95 : 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : markerColor,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.5),
                                blurRadius: isSelected ? 12 : 6,
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
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            drv.plateNumber,
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
              }),
            ],
          );
        },
      ),
    );
  }

  Offset _projectToCanvas(DriverModel drv, int index, double w, double h) {
    if (drv.currentLat == 0 && drv.currentLng == 0) {
      // Nếu tài xế chưa phát GPS thực tế, phân bổ quanh tâm radar để vẫn bấm chọn được
      final angle = (index * 1.7) % (2 * math.pi);
      final radius = 35.0 + (index % 3) * 22.0;
      return Offset(
        w / 2 + radius * math.cos(angle),
        h / 2 + radius * math.sin(angle),
      );
    }
    final normX = ((drv.currentLng - _centerLng) / _spanDeg).clamp(-0.85, 0.85);
    final normY = ((_centerLat - drv.currentLat) / _spanDeg).clamp(-0.75, 0.75);
    return Offset(
      w / 2 + normX * (w * 0.42),
      h / 2 + normY * (h * 0.38),
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

class _RadarGridPainter extends CustomPainter {
  final double sweepAngle;

  _RadarGridPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final circlePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final r in [35.0, 70.0, 105.0]) {
      canvas.drawCircle(center, r, circlePaint);
    }

    final centerPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      centerPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      centerPaint,
    );

    // Tia quét Radar
    final sweepRadius = math.min(size.width, size.height) * 0.48;
    final sweepEnd = Offset(
      center.dx + sweepRadius * math.cos(sweepAngle),
      center.dy + sweepRadius * math.sin(sweepAngle),
    );
    final sweepPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    canvas.drawLine(center, sweepEnd, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle;
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
