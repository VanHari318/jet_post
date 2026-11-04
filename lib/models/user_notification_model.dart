import 'package:cloud_firestore/cloud_firestore.dart';

class UserNotificationModel {
  final String id;
  final String recipientUid;
  final String category;
  final String title;
  final String body;
  final String orderId;
  final String orderType;
  final DateTime createdAt;

  const UserNotificationModel({
    required this.id,
    required this.recipientUid,
    required this.category,
    required this.title,
    required this.body,
    required this.orderId,
    required this.orderType,
    required this.createdAt,
  });

  factory UserNotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserNotificationModel(
      id: doc.id,
      recipientUid: data['recipientUid'] as String? ?? '',
      category: data['category'] as String? ?? 'order',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      orderId: data['orderId'] as String? ?? '',
      orderType: data['orderType'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
