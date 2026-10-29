import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../user/services/user_service.dart';

class AdminDrawerMenu extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const AdminDrawerMenu({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  static const List<_DrawerItem> _items = [
    _DrawerItem(icon: Icons.dashboard_outlined, label: 'Tổng quan'),
    _DrawerItem(icon: Icons.radar, label: 'Radar Điều hành'),
    _DrawerItem(icon: Icons.assignment_ind_outlined, label: 'Duyệt hồ sơ eKYC'),
    _DrawerItem(icon: Icons.manage_accounts_outlined, label: 'Quản lý người dùng'),
    _DrawerItem(icon: Icons.gavel_outlined, label: 'Xử lý tranh chấp'),
    _DrawerItem(icon: Icons.price_change_outlined, label: 'Cấu hình biểu cước'),
    _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Thống kê & Báo cáo'),
    _DrawerItem(icon: Icons.campaign_outlined, label: 'Phát thông báo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'JetPost Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Bảng điều hành hệ thống',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = currentIndex == index;
                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                    size: 22,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  onTap: () {
                    Navigator.of(context).pop();
                    onItemSelected(index);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: AppColors.accent),
                  title: const Text(
                    'Đổi phân hệ (Welcome Gate)',
                    style: TextStyle(color: AppColors.accent, fontSize: 13.5),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.welcomeGate,
                      (route) => false,
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Đăng xuất Quản trị',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    nav.pop();
                    await UserService.instance.clearUserSession();
                    nav.pushNamedAndRemoveUntil(
                      AppRoutes.welcomeGate,
                      (route) => false,
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;

  const _DrawerItem({required this.icon, required this.label});
}
