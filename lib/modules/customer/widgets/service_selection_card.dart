import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Thẻ chọn dịch vụ chính của JetPost: Xe ôm JetBike vs Giao hàng JetExpress
class ServiceSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final String badgeText;
  final VoidCallback onTap;

  const ServiceSelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(isDark ? 20 : 15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon khối màu thương hiệu
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 14),

              // Tiêu đề & mô tả
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Mũi tên điều hướng
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textMutedDark
                    : AppColors.textMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

