import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/app_routes.dart';

class DriverNavigationDrawer extends StatelessWidget {
  final String driverName;
  final String? avatarUrl;
  final bool isOnline;
  final bool isBusy;
  final bool isDemoMode;
  final String currentRoute;
  final VoidCallback? onToggleOnline;

  const DriverNavigationDrawer({
    super.key,
    required this.driverName,
    this.avatarUrl,
    required this.isOnline,
    this.isBusy = false,
    this.isDemoMode = false,
    required this.currentRoute,
    this.onToggleOnline,
  });

  void _openRoute(BuildContext context, String route) {
    Navigator.pop(context);
    if (route == currentRoute) return;

    if (currentRoute == AppRoutes.driverTrip &&
        route == AppRoutes.driverDashboard) {
      Navigator.pushReplacementNamed(
        context,
        route,
        arguments: {'suppressActiveTripRedirect': true},
      );
      return;
    }

    if (route == AppRoutes.welcomeGate) {
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: avatarUrl == null
                    ? null
                    : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 34,
                      )
                    : null,
              ),
              accountName: Text(
                driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              accountEmail: Text(
                isDemoMode
                    ? 'Chế độ xem thử · Tài xế JetPost'
                    : 'Đối tác tài xế JetPost',
              ),
            ),
            if (isBusy)
              const ListTile(
                leading: Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.driverBusy,
                ),
                title: Text('Đang thực hiện chuyến'),
                subtitle: Text('Bạn đang ở chế độ bận'),
              )
            else
              SwitchListTile.adaptive(
                secondary: Icon(
                  isOnline ? Icons.radar_rounded : Icons.radar_outlined,
                  color: isOnline ? AppColors.driverOnline : null,
                ),
                title: Text(isOnline ? 'Đang nhận đơn' : 'Đang offline'),
                subtitle: Text(
                  isDemoMode
                      ? 'Trạng thái chỉ lưu trong phiên xem thử'
                      : 'Bật hoặc tắt nhận chuyến mới',
                ),
                value: isOnline,
                activeTrackColor: AppColors.primaryLight,
                activeThumbColor: AppColors.primary,
                onChanged: onToggleOnline == null
                    ? null
                    : (_) => onToggleOnline!(),
              ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              title: 'Tổng quan tài xế',
              selected: currentRoute == AppRoutes.driverDashboard,
              onTap: () => _openRoute(context, AppRoutes.driverDashboard),
            ),
            _DrawerItem(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Thu nhập & lịch sử',
              selected: currentRoute == AppRoutes.driverIncome,
              onTap: () => _openRoute(context, AppRoutes.driverIncome),
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Tin nhắn',
              selected: currentRoute == AppRoutes.messagesInbox,
              onTap: () => _openRoute(context, AppRoutes.messagesInbox),
            ),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              title: 'Hồ sơ cá nhân',
              selected: currentRoute == AppRoutes.userProfile,
              onTap: () => _openRoute(context, AppRoutes.userProfile),
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              title: 'Cài đặt chung',
              selected: currentRoute == AppRoutes.appSettings,
              onTap: () => _openRoute(context, AppRoutes.appSettings),
            ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.home_outlined,
              title: 'Về cổng chính',
              selected: false,
              onTap: () => _openRoute(context, AppRoutes.welcomeGate),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'JetPost · Phân hệ tài xế',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      selectedColor: AppColors.primary,
      selectedTileColor: AppColors.primaryLight,
      onTap: onTap,
    );
  }
}
