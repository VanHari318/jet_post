/// Chuỗi văn bản hiển thị và hằng số nhãn dùng chung cho toàn ứng dụng JetPost
class AppStrings {
  AppStrings._();

  // Tên ứng dụng & Định danh
  static const String appName = 'JetPost';
  static const String appTagline = 'Xe Công Nghệ & Giao Vận Siêu Tốc';
  static const String currencySymbol = 'đ';

  // Tên 4 Phân hệ Nghiệp vụ
  static const String customerModule = 'Khách Hàng & Đặt Cuốc';
  static const String driverModule = 'Đối Tác Tài Xế';
  static const String userModule = 'Tài Khoản & Định Danh';
  static const String adminModule = 'Quản Trị Điều Hành';

  // Dịch vụ cốt lõi
  static const String rideHailingService = 'Đặt Xe Ôm';
  static const String deliveryService = 'Giao Hàng Nhanh';
  static const String savedAddresses = 'Địa Chỉ Đã Lưu';
  static const String activityHistory = 'Lịch Sử Hoạt Động';

  // Thông báo trạng thái vận hành
  static const String driverOnlineStickyNotif = 'JetPost Driver đang hoạt động và đồng bộ GPS';
  static const String searchingDriver = 'Đang tìm kiếm tài xế quanh bạn...';
  static const String noDriverFound = 'Không tìm thấy tài xế quanh khu vực này';
  static const String driverFound = 'Đã tìm thấy tài xế!';
  static const String tripCompleted = 'Chuyến đi hoàn tất!';
  static const String deliveryCompleted = 'Đã giao hàng thành công!';

  // Bàn giao hàng an toàn PoD
  static const String podPhotoTitle = 'Chụp ảnh bằng chứng giao hàng (PoD)';
  static const String otpInputPrompt = 'Nhập mã OTP 4 số từ người nhận:';
  static const String otpInvalid = 'Mã OTP không chính xác, vui lòng kiểm tra lại!';
  static const String otpVerified = 'Xác thực mã OTP thành công!';

  // Cảnh báo & Ngoại lệ
  static const String networkError = 'Lỗi kết nối mạng, vui lòng thử lại';
  static const String permissionDeniedLocation = 'Ứng dụng cần quyền GPS để xác định vị trí';
  static const String permissionDeniedCamera = 'Ứng dụng cần quyền Camera để chụp ảnh giấy tờ / hàng hóa';
}
