import 'package:flutter/material.dart';
import '../../../core/constants/app_enums.dart';

/// Huy hiệu hiển thị Vai trò Tài khoản (Role Badge)
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool isCompact;

  const RoleBadge({
    super.key,
    required this.role,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    IconData icon;
    String label;

    switch (role) {
      case UserRole.customer:
        bg = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.person_outline;
        label = 'Khách Hàng';
        break;
      case UserRole.driver:
        bg = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        icon = Icons.two_wheeler;
        label = 'Đối Tác Tài Xế';
        break;
      case UserRole.admin:
        bg = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        icon = Icons.admin_panel_settings_outlined;
        label = 'Quản Trị Viên';
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
