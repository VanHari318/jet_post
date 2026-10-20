import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_enums.dart';

/// Thực thể Dữ liệu Địa chỉ Quen thuộc (Saved Addresses Sub-collection)
/// Nằm trong đường dẫn: users/{userId}/saved_addresses/{addrId}
class SavedAddressModel {
  final String id; // ID tự sinh Auto ID
  final String userId; // Khóa ngoại liên kết USERS.id
  final AddressLabel label; // Nhà riêng | Cơ quan | Khác
  final String addressText; // Tên địa chỉ hiển thị (VD: Đại học Thủy Lợi, 175 Tây Sơn)
  final double lat; // Vĩ độ
  final double lng; // Kinh độ
  final DateTime createdAt; // Thời điểm lưu

  SavedAddressModel({
    required this.id,
    required this.userId,
    this.label = AddressLabel.home,
    required this.addressText,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  factory SavedAddressModel.fromFirestore(DocumentSnapshot doc, String userId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SavedAddressModel(
      id: doc.id,
      userId: userId,
      label: AddressLabel.fromFirestore(data['label'] as String?),
      addressText: data['addressText'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label.toFirestore(),
      'addressText': addressText,
      'lat': lat,
      'lng': lng,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
