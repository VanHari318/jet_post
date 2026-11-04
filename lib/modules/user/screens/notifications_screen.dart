import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../models/system_notification_model.dart';
import '../../../models/user_model.dart';
import '../../../models/user_notification_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserService.instance.getCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (profileSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thông báo')),
            body: Center(
              child: Text('Không tải được hồ sơ: ${profileSnapshot.error}'),
            ),
          );
        }

        final user = profileSnapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thông báo')),
            body: const Center(
              child: Text('Vui lòng đăng nhập để xem thông báo.'),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Thông báo'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.local_offer_outlined), text: 'Ưu đãi'),
                  Tab(
                    icon: Icon(Icons.receipt_long_outlined),
                    text: 'Đơn hàng',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _BroadcastList(role: user.role),
                _OrderNotificationList(user: user),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BroadcastList extends StatelessWidget {
  final UserRole role;

  const _BroadcastList({required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SystemNotificationModel>>(
      stream: NotificationService.instance.watchBroadcasts(role),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamError(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const _EmptyNotifications();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _NotificationCard(
              title: item.title,
              body: item.body,
              createdAt: item.createdAt,
              icon: Icons.local_offer_outlined,
              color: AppColors.secondary,
            );
          },
        );
      },
    );
  }
}

class _OrderNotificationList extends StatelessWidget {
  final UserModel user;

  const _OrderNotificationList({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserNotificationModel>>(
      stream: NotificationService.instance.watchOrderNotifications(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StreamError(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const _EmptyNotifications();
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _NotificationCard(
              title: item.title,
              body: item.body,
              createdAt: item.createdAt,
              icon: Icons.receipt_long_outlined,
              color: AppColors.primary,
            );
          },
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  const _NotificationCard({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '$body\n${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Chưa có thông báo nào.'));
}

class _StreamError extends StatelessWidget {
  final String message;

  const _StreamError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Không tải được thông báo: $message'),
    ),
  );
}
