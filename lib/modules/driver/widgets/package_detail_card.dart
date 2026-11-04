import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Card hiển thị chi tiết bưu kiện/hàng hóa
/// Chỉ hiện với đơn giao hàng (DeliveryModel) — ẩn với xe ôm
class PackageDetailCard extends StatelessWidget {
  /// Loại hàng: Tài liệu | Đồ ăn | Hàng nặng | Bưu phẩm ...
  final String packageType;

  /// Ghi chú bưu gửi (VD: "Hàng dễ vỡ, gọi trước")
  final String? packageNote;

  /// Hiển thị lưu ý đối soát khi đang giao hàng
  final bool showDeliveryNotice;

  const PackageDetailCard({
    super.key,
    required this.packageType,
    this.packageNote,
    this.showDeliveryNotice = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Chi Tiết Hàng Hóa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Loại hàng ─────────────────────────────────────────────────
            _InfoRow(
              icon: Icons.category_outlined,
              label: 'Loại hàng',
              value: packageType,
              isDark: isDark,
            ),

            // ── Ghi chú (nếu có) ──────────────────────────────────────────
            if (packageNote != null && packageNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.sticky_note_2_outlined,
                label: 'Ghi chú',
                value: packageNote!,
                isDark: isDark,
                valueColor: AppColors.warning,
              ),
            ],

            // ── Lưu ý đối soát bàn giao khi đang giao hàng ────────────
            if (showDeliveryNotice) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Khi đến nơi, hãy yêu cầu người nhận đọc Mã OTP 4 số và chụp ảnh bàn giao kiện hàng để hoàn tất.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Row hiển thị một thông tin dạng icon + nhãn + giá trị
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
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
