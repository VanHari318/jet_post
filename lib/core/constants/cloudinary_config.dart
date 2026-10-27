/// Cấu hình Thông số Đám mây Cloudinary Toàn hệ thống JetPost
/// Quản lý API Keys, Cloud Name và Phân cấp Cây Thư mục (Folder Hierarchy)
class CloudinaryConfig {
  CloudinaryConfig._();

  // Thông số chứng thực Cloudinary
  static const String cloudName = 'dojcgjli4';
  static const String apiKey = '557373213469619';
  static const String apiSecret = '8rj9e7Hho6F8OzjQiHtfNQGkU-Q';

  // API Endpoint
  static const String uploadApiUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  // Cấu trúc phân cấp Thư mục ảnh (Folder Hierarchy)
  static const String rootFolder = 'jetpost';

  /// Thư mục ảnh đại diện người dùng (Users / Drivers / Admin)
  static const String avatarsFolder = '$rootFolder/avatars';

  /// Thư mục hồ sơ định danh điện tử tài xế (CCCD 2 mặt, Giấy phép lái xe)
  static const String driversKycFolder = '$rootFolder/drivers_ekyc';

  /// Thư mục ảnh bằng chứng giao hàng an toàn (Proof of Delivery - PoD)
  static const String deliveriesPodFolder = '$rootFolder/deliveries_pod';
}
