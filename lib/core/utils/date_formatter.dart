import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Tiện ích định dạng ngày giờ cho toàn hệ thống JetPost
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateTimeFormat = DateFormat('HH:mm - dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  /// Định dạng Timestamp hoặc DateTime thành "HH:mm - dd/MM/yyyy"
  static String formatDateTime(dynamic date) {
    if (date == null) return '--:--';
    final dt = _toDateTime(date);
    return _dateTimeFormat.format(dt);
  }

  /// Định dạng giờ phút "HH:mm"
  static String formatTime(dynamic date) {
    if (date == null) return '--:--';
    final dt = _toDateTime(date);
    return _timeFormat.format(dt);
  }

  /// Định dạng ngày tháng năm "dd/MM/yyyy"
  static String formatDate(dynamic date) {
    if (date == null) return '--/--/----';
    final dt = _toDateTime(date);
    return _dateFormat.format(dt);
  }

  static DateTime _toDateTime(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is DateTime) {
      return date;
    }
    return DateTime.now();
  }
}
