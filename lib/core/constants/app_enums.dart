// Định nghĩa các kiểu Liệt kê (Enums) dùng chung toàn hệ thống JetPost
// Tuân thủ nghiêm ngặt theo Đặc tả CSDL trong KeHoach.md và Báo cáo Chuyên đề.

/// Vai trò người dùng trong hệ thống
enum UserRole {
  customer,
  driver,
  admin;

  String toFirestore() => name;

  static UserRole fromFirestore(String? value) {
    switch (value?.toLowerCase()) {
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Khách hàng';
      case UserRole.driver:
        return 'Đối tác Tài xế';
      case UserRole.admin:
        return 'Quản trị viên';
    }
  }
}

/// Trạng thái hồ sơ eKYC của Đối tác Tài xế
enum DriverApprovalStatus {
  pendingApproval,
  active,
  banned;

  String toFirestore() {
    switch (this) {
      case DriverApprovalStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case DriverApprovalStatus.active:
        return 'ACTIVE';
      case DriverApprovalStatus.banned:
        return 'BANNED';
    }
  }

  static DriverApprovalStatus fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
        return DriverApprovalStatus.active;
      case 'BANNED':
        return DriverApprovalStatus.banned;
      case 'PENDING_APPROVAL':
      default:
        return DriverApprovalStatus.pendingApproval;
    }
  }

  String get displayName {
    switch (this) {
      case DriverApprovalStatus.pendingApproval:
        return 'Chờ phê duyệt';
      case DriverApprovalStatus.active:
        return 'Đang hoạt động';
      case DriverApprovalStatus.banned:
        return 'Đã bị khóa';
    }
  }
}

/// Trạng thái chu trình cuốc xe ôm (Ride)
enum RideStatus {
  pendingDriver,
  accepted,
  arrivedPickup,
  inProgress,
  completed,
  cancelled;

  String toFirestore() {
    switch (this) {
      case RideStatus.pendingDriver:
        return 'PENDING_DRIVER';
      case RideStatus.accepted:
        return 'ACCEPTED';
      case RideStatus.arrivedPickup:
        return 'ARRIVED_PICKUP';
      case RideStatus.inProgress:
        return 'IN_PROGRESS';
      case RideStatus.completed:
        return 'COMPLETED';
      case RideStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static RideStatus fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACCEPTED':
        return RideStatus.accepted;
      case 'ARRIVED_PICKUP':
        return RideStatus.arrivedPickup;
      case 'IN_PROGRESS':
        return RideStatus.inProgress;
      case 'COMPLETED':
        return RideStatus.completed;
      case 'CANCELLED':
        return RideStatus.cancelled;
      case 'PENDING_DRIVER':
      default:
        return RideStatus.pendingDriver;
    }
  }

  String get displayName {
    switch (this) {
      case RideStatus.pendingDriver:
        return 'Đang tìm tài xế';
      case RideStatus.accepted:
        return 'Tài xế đã nhận';
      case RideStatus.arrivedPickup:
        return 'Tài xế đã đến điểm đón';
      case RideStatus.inProgress:
        return 'Đang di chuyển';
      case RideStatus.completed:
        return 'Hoàn thành chuyến';
      case RideStatus.cancelled:
        return 'Đã hủy chuyến';
    }
  }
}

/// Trạng thái chu trình đơn giao bưu kiện (Delivery)
enum DeliveryStatus {
  pendingDriver,
  accepted,
  pickedUp,
  inTransit,
  completed,
  cancelled,
  failedDelivery;

  String toFirestore() {
    switch (this) {
      case DeliveryStatus.pendingDriver:
        return 'PENDING_DRIVER';
      case DeliveryStatus.accepted:
        return 'ACCEPTED';
      case DeliveryStatus.pickedUp:
        return 'PICKED_UP';
      case DeliveryStatus.inTransit:
        return 'IN_TRANSIT';
      case DeliveryStatus.completed:
        return 'COMPLETED';
      case DeliveryStatus.cancelled:
        return 'CANCELLED';
      case DeliveryStatus.failedDelivery:
        return 'FAILED_DELIVERY';
    }
  }

  static DeliveryStatus fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACCEPTED':
        return DeliveryStatus.accepted;
      case 'PICKED_UP':
        return DeliveryStatus.pickedUp;
      case 'IN_TRANSIT':
        return DeliveryStatus.inTransit;
      case 'COMPLETED':
        return DeliveryStatus.completed;
      case 'CANCELLED':
        return DeliveryStatus.cancelled;
      case 'FAILED_DELIVERY':
        return DeliveryStatus.failedDelivery;
      case 'PENDING_DRIVER':
      default:
        return DeliveryStatus.pendingDriver;
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryStatus.pendingDriver:
        return 'Đang tìm tài xế giao';
      case DeliveryStatus.accepted:
        return 'Tài xế đã nhận đơn';
      case DeliveryStatus.pickedUp:
        return 'Đã lấy hàng';
      case DeliveryStatus.inTransit:
        return 'Đang giao hàng';
      case DeliveryStatus.completed:
        return 'Giao thành công';
      case DeliveryStatus.cancelled:
        return 'Đã hủy đơn';
      case DeliveryStatus.failedDelivery:
        return 'Giao không thành công';
    }
  }
}

/// Nhãn phân loại địa chỉ đã lưu trong danh bạ
enum AddressLabel {
  home,
  work,
  other;

  String toFirestore() {
    switch (this) {
      case AddressLabel.home:
        return 'Nhà riêng';
      case AddressLabel.work:
        return 'Cơ quan';
      case AddressLabel.other:
        return 'Khác';
    }
  }

  static AddressLabel fromFirestore(String? value) {
    switch (value) {
      case 'Cơ quan':
        return AddressLabel.work;
      case 'Khác':
        return AddressLabel.other;
      case 'Nhà riêng':
      default:
        return AddressLabel.home;
    }
  }
}

/// Mức độ ưu tiên của thông báo hệ thống (Broadcast Alerts)
enum NotificationPriority {
  normal,
  high,
  urgent;

  String toFirestore() {
    switch (this) {
      case NotificationPriority.normal:
        return 'NORMAL';
      case NotificationPriority.high:
        return 'HIGH';
      case NotificationPriority.urgent:
        return 'URGENT';
    }
  }

  static NotificationPriority fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'HIGH':
        return NotificationPriority.high;
      case 'URGENT':
        return NotificationPriority.urgent;
      case 'NORMAL':
      default:
        return NotificationPriority.normal;
    }
  }
}
