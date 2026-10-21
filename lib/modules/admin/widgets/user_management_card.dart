import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/user_model.dart';

class UserManagementCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onViewDetail;
  final VoidCallback onBanToggle;

  const UserManagementCard({
    super.key,
    required this.user,
    required this.onViewDetail,
    required this.onBanToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isBanned = user.isBanned;

    Color roleColor;
    String roleLabel;
    switch (user.role) {
      case UserRole.admin:
        roleColor = AppColors.accent;
        roleLabel = 'Admin';
      case UserRole.driver:
        roleColor = AppColors.primary;
        roleLabel = 'Tài xế';
      default:
        roleColor = AppColors.secondary;
        roleLabel = 'Khách hàng';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onViewDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: roleColor.withOpacity(0.15),
                    backgroundImage:
                        user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null
                        ? Icon(Icons.person, color: roleColor, size: 24)
                        : null,
                  ),
                  if (isBanned)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.block, color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isBanned ? AppColors.textMutedLight : null,
                              decoration: isBanned
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isBanned ? Icons.lock_open : Icons.lock_outline,
                  color: isBanned ? AppColors.success : AppColors.error,
                  size: 22,
                ),
                onPressed: onBanToggle,
                tooltip: isBanned ? 'Mở khóa' : 'Khóa tài khoản',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
