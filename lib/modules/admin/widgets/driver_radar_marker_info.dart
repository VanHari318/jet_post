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
      statusText = 'Đang giao hàng';
    } else {
      statusColor = AppColors.driverOnline;
      statusText = 'Sẵn sàng nhận đơn';
    }

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
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
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: Icon(Icons.close,
                        size: 18, color: AppColors.textSecondaryLight),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: userInfo?.avatarUrl != null
                          ? NetworkImage(userInfo!.avatarUrl!)
                          : null,
                      child: userInfo?.avatarUrl == null
                          ? const Icon(Icons.person,
                              color: AppColors.primary, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userInfo?.fullName ?? 'Tài xế #${driver.id.substring(0, 6)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            userInfo?.phone ?? '',
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
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                    icon: Icons.motorcycle,
                    label: 'Biển số',
                    value: driver.plateNumber),
                _InfoRow(
                  icon: Icons.star_rounded,
                  label: 'Đánh giá',
                  value:
                      '${driver.rating.toStringAsFixed(1)} ⭐ (${driver.totalReviews} lượt)',
                ),
                _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Tổng cuốc',
                  value: '${driver.totalTrips} chuyến',
                ),
                if (driver.activeTripId != null)
                  _InfoRow(
                    icon: Icons.receipt_long,
                    label: 'Đơn hiện tại',
                    value: driver.activeTripId!,
                    valueColor: AppColors.secondary,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
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
