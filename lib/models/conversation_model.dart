import 'package:cloud_firestore/cloud_firestore.dart';

/// Thực thể Dữ liệu Phiên Trò chuyện Trực tiếp 1-1 (Conversations Collection)
class ConversationModel {
  final String id; // Mã phòng chat: uid1_uid2 (xếp theo thứ tự alphabet)
  final List<String> participants; // Danh sách 2 UID tham gia cuộc trò chuyện
  final Map<String, dynamic> participantDetails; // Thông tin tên và avatar của 2 bên
  final String lastMessage; // Trích đoạn tin nhắn gần nhất
  final String lastSenderId; // UID của người gửi tin nhắn cuối cùng
  final Map<String, int> unreadCount; // Số tin nhắn chưa đọc của từng bên {uid: count}
  final DateTime updatedAt; // Thời điểm cập nhật tin nhắn mới nhất

  ConversationModel({
    required this.id,
    required this.participants,
    required this.participantDetails,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.unreadCount = const {},
    required this.updatedAt,
  });

  /// Tạo ID phòng chat chuẩn hóa alphabet từ 2 UID người dùng
  static String generateId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ConversationModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      participantDetails: Map<String, dynamic>.from(data['participantDetails'] as Map? ?? {}),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderId: data['lastSenderId'] as String? ?? '',
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
