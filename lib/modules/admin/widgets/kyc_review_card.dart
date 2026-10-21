import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';

class KycReviewCard extends StatelessWidget {
  final DriverModel driver;
  final UserModel? userInfo;
  final VoidCallback onReview;

  const KycReviewCard({
    super.key,
    required this.driver,
    this.userInfo,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onReview,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.warningBg,
                backgroundImage: userInfo?.avatarUrl != null
                    ? NetworkImage(userInfo!.avatarUrl!)
                    : null,
                child: userInfo?.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.warning, size: 30)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userInfo?.fullName ?? 'Tài xế mới',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userInfo?.phone ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.motorcycle,
                            size: 14, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          driver.plateNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Chờ duyệt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.textMutedLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
