import 'package:intl/intl.dart';

/// Tiện ích định dạng tiền tệ Việt Nam Đồng (VNĐ)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  /// Định dạng số tiền sang chuỗi có dấu chấm phân cách hàng nghìn kèm ký hiệu "đ"
  /// Ví dụ: 25000 -> "25.000 đ"
  static String format(num amount) {
    return '${_formatter.format(amount)} đ';
  }

  /// Định dạng chỉ lấy số có phân cách hàng nghìn, không kèm ký hiệu đ
  /// Ví dụ: 25000 -> "25.000"
  static String formatNumber(num amount) {
    return _formatter.format(amount);
  }
}
