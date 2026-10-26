/// Bộ Quy tắc Kiểm duyệt Dữ liệu Toàn diện (Validation Rules)
/// Chuẩn hóa cho toàn bộ hệ thống JetPost (Email, SĐT, Mật khẩu, Họ tên, Biển số xe, Ảnh, OTP)
class AppValidators {
  AppValidators._();

  // ==========================================
  // 1. SỐ ĐIỆN THOẠI VIỆT NAM (E.164 & Local)
  // ==========================================
  /// Đầu số nhà mạng Việt Nam hợp lệ: 03, 05, 07, 08, 09 (đúng 10 chữ số)
  static final RegExp _vnPhoneRegex = RegExp(r'^(0)(3|5|7|8|9)[0-9]{8}$');

  /// Kiểm tra số điện thoại Việt Nam hợp lệ
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\.]'), '');
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) {
      return 'Số điện thoại chỉ được chứa các chữ số';
    }
    if (cleanPhone.length != 10) {
      return 'Số điện thoại phải bao gồm đúng 10 chữ số';
    }
    if (!_vnPhoneRegex.hasMatch(cleanPhone)) {
      return 'Đầu số không hợp lệ (chỉ chấp nhận 03, 05, 07, 08, 09)';
    }
    return null; // Hợp lệ
  }

  // ==========================================
  // 2. EMAIL (Chuẩn RFC 5322)
  // ==========================================
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Kiểm tra địa chỉ Email hợp lệ
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    final trimmed = value.trim();
    if (trimmed.contains(' ')) {
      return 'Email không được chứa khoảng trắng';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Định dạng email không hợp lệ (Ví dụ: ten@gmail.com)';
    }
    return null; // Hợp lệ
  }

  // ==========================================
  // 3. MẬT KHẨU & XÁC NHẬN MẬT KHẨU
  // ==========================================
  /// Kiểm tra mật khẩu (Tối thiểu 6 ký tự chuẩn Firebase Auth)
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < minLength) {
      return 'Mật khẩu phải có tối thiểu $minLength ký tự';
    }
    return null; // Hợp lệ
  }

  /// Kiểm tra khớp mật khẩu xác nhận
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận lại mật khẩu';
    }
    if (value != originalPassword) {
      return 'Mật khẩu xác nhận không trùng khớp';
    }
    return null; // Hợp lệ
  }

  // ==========================================
  // 4. HỌ VÀ TÊN NGƯỜI DÙNG
  // ==========================================
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ và tên đầy đủ';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Họ và tên quá ngắn (tối thiểu 2 ký tự)';
    }
    if (trimmed.length > 50) {
      return 'Họ và tên không được vượt quá 50 ký tự';
    }
    // Không chứa các ký tự đặc biệt nguy hiểm hoặc số
    if (RegExp(r'[0-9<>{}\[\]\\\/=~`!@#$%^&*()_+|]').hasMatch(trimmed)) {
      return 'Họ tên không được chứa số hoặc ký tự đặc biệt';
    }
    return null; // Hợp lệ
  }

  // ==========================================
  // 5. BIỂN SỐ XE MÁY VIỆT NAM (eKYC)
  // ==========================================
  /// Định dạng biển xe máy VN: 29-E1 123.45 hoặc 59-X3 6789 hoặc 43-A1 1234
  static final RegExp _plateRegex = RegExp(
    r'^[0-9]{2}-[A-Z0-9]{1,2}\s?[0-9]{3,5}(\.[0-9]{2})?$',
    caseSensitive: false,
  );

  static String? validatePlateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập biển số xe máy';
    }
    final trimmed = value.trim().toUpperCase();
    if (trimmed.length < 7 || trimmed.length > 13) {
      return 'Độ dài biển số không hợp lệ';
    }
    if (!_plateRegex.hasMatch(trimmed)) {
      return 'Định dạng biển số không đúng (Ví dụ: 29-E1 123.45 hoặc 59-X1 6789)';
    }
    return null; // Hợp lệ
  }

  // ==========================================
  // 6. LOẠI PHƯƠNG TIỆN (Vehicle Dropdown)
  // ==========================================
  static String? validateVehicleType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng chọn loại xe máy';
    }
    return null;
  }

  // ==========================================
  // 7. MÃ OTP (6 CHỮ SỐ)
  // ==========================================
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã xác thực OTP';
    }
    final clean = value.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(clean)) {
      return 'Mã OTP chỉ bao gồm các chữ số';
    }
    if (clean.length != 6) {
      return 'Mã OTP phải có đúng 6 chữ số';
    }
    return null;
  }

  // ==========================================
  // 8. TỆP ĐA PHƯƠNG TIỆN / HÌNH ẢNH (Image Validation)
  // ==========================================
  /// Kiểm tra ảnh đã chọn, dung lượng và định dạng hợp lệ
  static String? validateImageFile({
    required String? filePath,
    int maxSizeBytes = 10 * 1024 * 1024, // 10MB
  }) {
    if (filePath == null || filePath.trim().isEmpty) {
      return 'Vui lòng chụp hoặc tải lên hình ảnh';
    }
    final lower = filePath.toLowerCase();
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (!isImage) {
      return 'Định dạng tệp không được hỗ trợ (chỉ nhận JPG, PNG, WEBP)';
    }
    return null;
  }
}
