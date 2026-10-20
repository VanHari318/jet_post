# JetPost - Ứng dụng Xe Công nghệ & Giao nhận Hàng hóa (Hệ thống Giao vận)

Dự án Chuyên đề Công nghệ Thông tin - Nhóm 14 (Trường Đại học Thủy Lợi).

---

## 1. Kiến trúc Tổng quan (Architecture)
Hệ thống được thiết kế theo mô hình **Single All-in-One Multi-Role Flutter App**:
- Tích hợp 4 phân hệ trong **1 Project duy nhất** và đóng gói thành **1 file APK duy nhất**.
- Cổng vào hợp nhất (**UI Entry Point Gate**) và công tắc chuyển đổi vai trò nhanh (**Demo Role Switcher**).
- Hạ tầng Serverless Google Firebase (Authentication, Cloud Firestore, Storage) và dịch vụ bản đồ OpenStreetMap / OpenRouteService.

---

## 2. Phân chia Phân hệ Nghiệp vụ (Modules)

| STT | Phân hệ (Module) | Thư mục mã nguồn | Thành viên phụ trách |
| :---: | :--- | :--- | :--- |
| 1 | **Phân hệ 1: Khách hàng & Đặt cuốc** | `lib/modules/customer/` | Thành viên 1 |
| 2 | **Phân hệ 2: Đối tác Tài xế & Vận chuyển** | `lib/modules/driver/` | Thành viên 2 (Nguyễn Văn Hải) |
| 3 | **Phân hệ 3: User & Hạ tầng Định danh** | `lib/modules/user/` | Thành viên 3 |
| 4 | **Phân hệ 4: Quản trị Điều hành & Nền tảng** | `lib/modules/admin/` | Thành viên 4 |

---

## 3. Quy tắc làm việc trên Git (Git Workflow)

1. **Phân nhánh độc lập:** Mỗi thành viên làm việc trên nhánh riêng tương ứng với phân hệ của mình:
   - `feature/customer` (Thành viên 1)
   - `feature/driver` (Thành viên 2)
   - `feature/user` (Thành viên 3)
   - `feature/admin` (Thành viên 4)
2. **Nguyên tắc cô lập mã nguồn (Isolation):**
   - Chỉ lập trình và commit bên trong thư mục `lib/modules/[tên_phân_hệ]/` của mình.
   - Tuyệt đối không tự ý sửa `lib/main.dart` hoặc các file trong `lib/core/` khi chưa họp thống nhất nhóm.

---

## 4. Tài khoản Kiểm thử Xác thực Số điện thoại (Firebase Testing Whitelist)

Để tránh cạn kiệt hạn mức SMS OTP của gói Firebase Free Tier, toàn bộ nhóm **sử dụng các số điện thoại thử nghiệm sau** để đăng nhập:
- **Khách hàng 1:** `+84 988888888` | OTP mặc định: `123456`
- **Khách hàng 2:** `+84 977777777` | OTP mặc định: `123456`
- **Tài xế 1:** `+84 966666666` | OTP mặc định: `123456`
- **Tài xế 2:** `+84 912345678` | OTP mặc định: `123456`

---

## 5. Hướng dẫn Khởi chạy Dự án (Getting Started)

```bash
# 1. Cài đặt các thư viện
flutter pub get

# 2. Khởi chạy ứng dụng lên thiết bị Android hoặc máy ảo
flutter run
```
