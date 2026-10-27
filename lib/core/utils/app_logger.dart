import 'package:flutter/foundation.dart';

/// Bộ ghi log tập trung phục vụ kiểm thử và giám sát thao tác người dùng
class AppLogger {
  /// Hàm chuẩn hóa chuỗi tiếng Việt có dấu sang ASCII thuần để hiển thị sạch sẽ trên Console Windows/PowerShell
  static String _stripDiacritics(String text) {
    if (text.isEmpty) return text;
    var result = text;
    const vietnamese = [
      'aàáảãạăằắẳẵặâầấẩẫậ',
      'AÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ',
      'dđ',
      'DĐ',
      'eèéẻẽẹêềếểễệ',
      'EÈÉẺẼẸÊỀẾỂỄỆ',
      'iìíỉĩị',
      'IÌÍỈĨỊ',
      'oòóỏõọôồốổỗộơờớởỡợ',
      'OÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ',
      'uùúủũụưừứửữự',
      'UÙÚỦŨỤƯỪỨỬỮỰ',
      'yỳýỷỹỵ',
      'YỲÝỶỸỴ',
    ];
    const ascii = [
      'a', 'A', 'd', 'D', 'e', 'E', 'i', 'I', 'o', 'O', 'u', 'U', 'y', 'Y'
    ];
    for (int i = 0; i < ascii.length; i++) {
      for (int j = 1; j < vietnamese[i].length; j++) {
        result = result.replaceAll(vietnamese[i][j], ascii[i]);
      }
    }

    // Thay thế các ký tự Unicode đặc biệt thường gây lỗi mã hóa trên Windows console
    return result
        .replaceAll('➔', '->')
        .replaceAll('→', '->')
        .replaceAll('•', '-')
        .replaceAll('…', '...')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
  }

  static void _log(String message) {
    debugPrint(_stripDiacritics(message));
  }

  /// Ghi log mọi hành vi tương tác trên giao diện (bấm nút, chọn ảnh, chuyển tab...)
  static void userAction(String screen, String action, [Map<String, dynamic>? details]) {
    final detailsStr = details != null && details.isNotEmpty ? ' | Chi tiet: $details' : '';
    _log('[USER_ACTION] [$screen] -> $action$detailsStr');
  }

  /// Ghi log quy trình định danh và xác thực OTP / Phiên
  static void auth(String action, [Map<String, dynamic>? details]) {
    final detailsStr = details != null && details.isNotEmpty ? ' | Chi tiet: $details' : '';
    _log('[AUTH] -> $action$detailsStr');
  }

  /// Ghi log điều hướng màn hình
  static void navigation(String from, String to, [dynamic args]) {
    final argsStr = args != null ? ' | Tham so: $args' : '';
    _log('[NAV] $from -> $to$argsStr');
  }

  /// Ghi log quy trình nộp & duyệt hồ sơ eKYC
  static void ekyc(String step, String status, [String? detail]) {
    final detailStr = detail != null ? ' ($detail)' : '';
    _log('[EKYC] [$step] -> $status$detailStr');
  }

  /// Ghi log nhắn tin P2P
  static void chat(String action, [Map<String, dynamic>? details]) {
    final detailsStr = details != null && details.isNotEmpty ? ' | Chi tiet: $details' : '';
    _log('[CHAT] -> $action$detailsStr');
  }

  /// Ghi log thay đổi cài đặt hệ thống
  static void settings(String key, dynamic value) {
    _log('[SETTINGS] -> $key thay doi: $value');
  }

  /// Ghi log thông tin nghiệp vụ chung
  static void info(String tag, String message) {
    _log('[INFO] [$tag] -> $message');
  }

  /// Ghi log lỗi ngoại lệ
  static void error(String tag, String message, [dynamic err, StackTrace? stack]) {
    _log('[ERROR] [$tag] LOI: $message ${err != null ? '| $err' : ''}');
    if (stack != null) _log('$stack');
  }
}
