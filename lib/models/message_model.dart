import 'package:cloud_firestore/cloud_firestore.dart';

/// Thực thể Dữ liệu Tin nhắn Trực tiếp (Messages Sub-collection)
/// Nằm trong đường dẫn: conversations/{conversationId}/messages/{msgId}
class MessageModel {
  final String id; // Mã tin nhắn Auto ID
  final String conversationId; // Khóa ngoại liên kết CONVERSATIONS.id
  final String senderId; // UID người gửi tin
  final String receiverId; // UID người nhận tin
  final String content; // Nội dung văn bản tin nhắn
  final bool isRead; // Trạng thái đã xem tin nhắn
  final DateTime timestamp; // Thời điểm gửi tin nhắn

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.isRead = false,
    required this.timestamp,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc, String conversationId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
