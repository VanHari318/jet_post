import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';

class DriverRadarMarkerInfo extends StatelessWidget {
  final DriverModel driver;
  final UserModel? userInfo;
  final VoidCallback? onClose;

  const DriverRadarMarkerInfo({
    super.key,
    required this.driver,
    this.userInfo,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = driver.isOnline;
    final isBusy = driver.isBusy;

    Color statusColor;
    String statusText;
    if (!isOnline) {
      statusColor = AppColors.textMutedLight;
      statusText = 'Offline';
    } else if (isBusy) {
      statusColor = AppColors.driverBusy;
      statusText = 'Đang thực hiện chuyến / giao hàng';
    } else {
      statusColor = AppColors.driverOnline;
      statusText = 'Online sẵn sàng nhận đơn';
    }

    // Tính tốc độ di chuyển giả lập/thực tế theo trạng thái (Task 4.2)
    final speedKmh = !isOnline
        ? 0
        : (isBusy ? (28 + (driver.heading.toInt() % 12)) : 15);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondaryLight),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: userInfo?.avatarUrl != null
                          ? NetworkImage(userInfo!.avatarUrl!)
                          : null,
                      child: userInfo?.avatarUrl == null
                          ? const Icon(Icons.person,
                              color: AppColors.primary, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo?.fullName ??
                                'Tài xế #${driver.id.length > 6 ? driver.id.substring(0, 6) : driver.id}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            userInfo?.phone ?? 'Chưa cập nhật SĐT',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            '$speedKmh km/h',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.motorcycle,
                  label: 'Phương tiện',
                  value: '${driver.plateNumber} (${driver.vehicleType})',
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Tọa độ GPS',
                  value:
                      '${driver.currentLat.toStringAsFixed(4)}, ${driver.currentLng.toStringAsFixed(4)} (${driver.heading.toStringAsFixed(0)}°)',
                ),
                _InfoRow(
                  icon: Icons.star_rounded,
                  label: 'Đánh giá & Chuyến',
                  value:
                      '${driver.rating.toStringAsFixed(1)} ⭐ (${driver.totalReviews} lượt) • ${driver.totalTrips} chuyến',
                ),
                _InfoRow(
                  icon: Icons.receipt_long,
                  label: 'Cuốc đang chạy',
                  value: (driver.activeTripId != null &&
                          driver.activeTripId!.isNotEmpty)
                      ? driver.activeTripId!
                      : 'Đang rảnh (Chờ nhận cuốc)',
                  valueColor: (driver.activeTripId != null &&
                          driver.activeTripId!.isNotEmpty)
                      ? AppColors.secondary
                      : AppColors.driverOnline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondaryLight),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
