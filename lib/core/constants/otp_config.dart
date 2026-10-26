/// Cấu hình Dịch vụ Xác thực Email OTP Phía Máy Chủ (Cloudflare Worker + Brevo)
/// Đảm bảo mã OTP được sinh độc quyền phía Server (Server-Side), chống dịch ngược file APK
class OtpConfig {
  OtpConfig._();

  /// Endpoint Cloudflare Worker sinh mã OTP 6 số bảo mật
  static const String workerUrl =
      'https://jetpost-otp.nguyenvanhai310805.workers.dev/';
}
