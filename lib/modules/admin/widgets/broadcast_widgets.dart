import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BroadcastTargetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const BroadcastTargetChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationHistoryCard extends StatelessWidget {
  final String title;
  final String body;
  final String targetGroup;
  final String priority;
  final DateTime createdAt;

  const NotificationHistoryCard({
    super.key,
    required this.title,
    required this.body,
    required this.targetGroup,
    required this.priority,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (priority) {
      case 'URGENT':
        priorityColor = AppColors.error;
      case 'HIGH':
        priorityColor = AppColors.warning;
      default:
        priorityColor = AppColors.info;
    }

    Color targetColor;
    String targetLabel;
    IconData targetIcon;
    switch (targetGroup) {
      case 'DRIVERS':
        targetColor = AppColors.primary;
        targetLabel = 'Tài xế';
        targetIcon = Icons.motorcycle;
      case 'CUSTOMERS':
        targetColor = AppColors.secondary;
        targetLabel = 'Khách hàng';
        targetIcon = Icons.person;
      default:
        targetColor = AppColors.accent;
        targetLabel = 'Toàn mạng';
        targetIcon = Icons.public;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(targetIcon, size: 14, color: targetColor),
                const SizedBox(width: 4),
                Text(
                  targetLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: targetColor,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
