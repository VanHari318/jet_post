import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/system_notification_model.dart';
import '../../../models/user_notification_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Stream<List<SystemNotificationModel>> watchBroadcasts(UserRole role) {
    final targetGroup = role == UserRole.driver ? 'DRIVERS' : 'CUSTOMERS';
    return FirebaseService.firestore
        .collection(FirebaseService.colSystemNotifications)
        .where('targetGroup', whereIn: ['ALL', targetGroup])
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(SystemNotificationModel.fromFirestore)
              .where(
                (notification) =>
                    notification.expiresAt == null ||
                    notification.expiresAt!.isAfter(DateTime.now()),
              )
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  Stream<List<UserNotificationModel>> watchOrderNotifications(String uid) {
    return FirebaseService.firestore
        .collection('user_notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(UserNotificationModel.fromFirestore)
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  Future<void> createOrderStatusNotification({
    required String recipientUid,
    required String title,
    required String body,
    required String orderId,
    required String orderType,
  }) async {
    if (recipientUid.isEmpty) return;
    await FirebaseService.firestore.collection('user_notifications').add({
      'recipientUid': recipientUid,
      'category': 'order',
      'title': title,
      'body': body,
      'orderId': orderId,
      'orderType': orderType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createNewOrderNotification({
    required String driverUid,
    required String orderId,
    required String orderType,
  }) async {
    if (driverUid.isEmpty) return;
    final id = '${orderType}_${orderId}_$driverUid';
    final ref = FirebaseService.firestore
        .collection('user_notifications')
        .doc(id);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set({
      'recipientUid': driverUid,
      'category': 'order',
      'title': 'Đơn hàng mới',
      'body':
          'Bạn có đơn hàng mới! Vui lòng kiểm tra đơn hàng để xem chi tiết!',
      'orderId': orderId,
      'orderType': orderType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
