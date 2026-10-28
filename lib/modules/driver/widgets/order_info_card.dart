import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

/// Card hiển thị địa chỉ điểm đón/lấy hàng và điểm đến
/// Có link mở Google Maps chỉ đường cho từng điểm
class OrderInfoCard extends StatelessWidget {
  /// Tiêu đề điểm A (VD: "Điểm đón khách" hoặc "Điểm lấy hàng")
  final String pickupLabel;

  /// Địa chỉ văn bản điểm đón / lấy hàng
  final String pickupAddress;

  /// Tọa độ điểm đón (để mở Google Maps)
  final double pickupLat;
  final double pickupLng;

  /// Tiêu đề điểm B (VD: "Điểm trả khách" hoặc "Địa chỉ giao hàng")
  final String dropoffLabel;

  /// Địa chỉ văn bản điểm trả / giao hàng
  final String dropoffAddress;

  /// Tọa độ điểm đến (để mở Google Maps)
  final double dropoffLat;
  final double dropoffLng;

  /// Khoảng cách ước tính (km)
  final double distanceKm;

  /// Giá cước (VNĐ)
  final double price;

  const OrderInfoCard({
    super.key,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLabel,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.price,
  });

  /// Mở Google Maps chỉ đường đến tọa độ chỉ định
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: khoảng cách + giá ────────────────────────────────
            Row(
              children: [
                Icon(Icons.route_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_formatPrice(price)}đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Điểm A: Đón / Lấy hàng ───────────────────────────────────
            _AddressRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.primary,
              label: pickupLabel,
              address: pickupAddress,
              isDark: isDark,
              onMapTap: () => _openGoogleMaps(pickupLat, pickupLng),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: SizedBox(
                height: 20,
                child: VerticalDivider(
                  width: 1,
                  color: AppColors.primary,
                  thickness: 1.5,
                ),
              ),
            ),

            // ── Điểm B: Trả khách / Giao hàng ────────────────────────────
            _AddressRow(
              icon: Icons.flag_rounded,
              iconColor: AppColors.secondary,
              label: dropoffLabel,
              address: dropoffAddress,
              isDark: isDark,
              onMapTap: () => _openGoogleMaps(dropoffLat, dropoffLng),
            ),
          ],
        ),
      ),
    );
  }

  /// Format giá tiền VNĐ thêm dấu chấm phân cách nghìn
  String _formatPrice(double price) {
    final intPrice = price.toInt();
    final s = intPrice.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

/// Row địa chỉ dùng lại cho điểm A và điểm B
class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final bool isDark;
  final VoidCallback onMapTap;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.isDark,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon điểm
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),

        // Nhãn + Địa chỉ
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Nút mở Google Maps
        const SizedBox(width: 8),
        InkWell(
          onTap: onMapTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined,
                    color: AppColors.accent, size: 14),
                SizedBox(width: 3),
                Text(
                  'Maps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
