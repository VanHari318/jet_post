# KẾ HOẠCH CHI TIẾT TRIỂN KHAI PHÂN HỆ USER (MODULE 3)


**Dự án:** JetPost - Ứng dụng Giao vận & Xe công nghệ Hợp nhất
**Phân hệ phụ trách:** Module 3 - User, Định danh Điện tử eKYC & Trung tâm Chat P2P
**Thành viên chịu trách nhiệm chính:** Thành viên 3
**Thư mục mã nguồn:** `lib/modules/user/`
**Tuân thủ:** Kế hoạch tổng thể [KeHoach.md](file:///d:/ChuyenDeCNTT/jet_post/KeHoach.md) & Quyết định Kiến trúc Hệ thống

---

## 1. TỔNG QUAN KIẾN TRÚC & GIẢI PHÁP KỸ THUẬT CUỐI CÙNG

### 1.1. Phạm vi & Trách nhiệm Nghiệp vụ của Phân hệ User

Phân hệ User đóng vai trò là **"Cổng vào huyết mạch và Hạ tầng Định danh"** của toàn bộ ứng dụng JetPost. Phân hệ chịu trách nhiệm:

1. **Quản lý Cổng vào (Welcome Gate) & Điều phối Vai trò:** Tiếp nhận người dùng, điều hướng vào đúng 4 phân hệ (Khách hàng, Tài xế, User, Admin) và cung cấp công tắc đổi vai trò nhanh (**Demo Role Switcher**) phục vụ chấm điểm đồ án.
2. **Xác thực Đa tầng Số điện thoại (Firebase Phone Auth):** Định danh chuẩn E.164 (`+84...`), kiểm duyệt đầu số nhà mạng Việt Nam, gửi và xác thực mã SMS OTP 6 số, bảo vệ chống spam (Rate-limiting 60s) và tích hợp sẵn danh sách Whitelist Testing Numbers để kiểm thử không tốn phí SMS viễn thông.
3. **Định danh Điện tử eKYC Đối tác Tài xế:** Thu thập thông tin phương tiện, chụp ảnh CCCD 2 mặt và Giấy phép lái xe (GPLX), nạp ảnh lên **Cloudinary** (folder `jetpost/drivers_ekyc`), đẩy hồ sơ vào collection `drivers` ở trạng thái `PENDING_APPROVAL` để Admin thẩm định.
4. **Hồ sơ Cá nhân & Bảo mật Tài khoản (Profile):** Cập nhật họ tên, ảnh đại diện Avatar qua Cloudinary (`jetpost/avatars`), đổi số điện thoại kèm xác thực OTP.
5. **Bộ gác cổng Phân quyền (RBAC Guard) & Tự động Đăng nhập (Auto-login):** Quản lý phiên làm việc trong `SharedPreferences`, tự động mở đúng giao diện, chặn tài xế chưa duyệt bật trực tuyến (`status != ACTIVE`), bảo vệ các màn hình quản trị của Admin.
6. **Cài đặt Hệ thống (Settings):** Chuyển đổi giao diện Sáng / Tối (Dark/Light mode hỗ trợ tài xế chạy xe ban đêm), cấu hình âm thanh, rung thông báo cuốc xe.
7. **Trung tâm Nhắn tin Trực tiếp Đa người dùng (Direct P2P User Chat):** Nền tảng chat 1-1 thời gian thực giữa 2 người dùng bất kỳ trên Firestore (Stream `conversations/{chatId}/messages`), hoàn toàn độc lập với cuốc xe.

### 1.2. Giải pháp Lưu trữ Ảnh & Đa phương tiện (Final Decision)

* **Dịch vụ sử dụng:** **Cloudinary** (Thay thế 100% Firebase Storage để tránh yêu cầu thẻ tín dụng và rủi ro phát sinh chi phí).
* **Cơ chế tải lên:** Ký số an toàn phía client (Signed Upload với HMAC-SHA1) qua [CloudinaryService](file:///d:/ChuyenDeCNTT/jet_post/lib/core/services/cloudinary_service.dart).
* **Quy ước thư mục lưu trữ:**
  * Ảnh đại diện người dùng: `jetpost/avatars/avatar_{userId}.jpg`
  * Ảnh eKYC tài xế: `jetpost/drivers_ekyc/{driverId}_{docType}_{timestamp}.jpg`
* **Hiển thị & Tối ưu CDN:** Sử dụng hàm `CloudinaryService.instance.getOptimizedUrl()` tự động nén `q_auto`, định dạng WebP `f_auto` và resize `c_fill` trực tiếp qua URL.

### 1.3. Cơ chế Phân định Xác thực: Người dùng Di động (Phone OTP) vs Quản trị viên (Admin Auth) (Final Decision)

* **Người dùng di động đầu cuối (Khách hàng & Tài xế):**
  * Bắt buộc sử dụng **Số điện thoại + SMS OTP 6 số** (Passwordless Authentication).
  * *Lý do kiến trúc:* Phù hợp trải nghiệm di động khi di chuyển ngoài đường, gắn chặt với SIM vật lý để đối soát cuộc gọi thực tế và mã bàn giao hàng hóa PoD 4 số.
* **Quản trị viên Hệ thống (Admin - Module 4 / Task 4.1):**
  * **Không sử dụng SMS OTP qua mạng viễn thông**. Admin sử dụng phương thức đăng nhập quản trị nội bộ bảo mật (Email/Password quản trị viên) kết hợp kiểm soát quyền nghiêm ngặt **RBAC (Role-Based Access Control)** trên Firestore (`role == 'admin'`).
  * *Lý do kiến trúc & bảo mật:*
    1. *Bảo vệ Hạn ngạch (Quota Protection):* Tránh tiêu tốn hạn ngạch SMS miễn phí cực kỳ hạn chế của Firebase Spark (10 SMS/ngày), phòng ngừa rủi ro khóa hệ thống xác thực.
    2. *Độ sẵn sàng cao (High Availability):* Bàn cờ điều hành Radar và duyệt eKYC cần truy cập tức thời bởi nhân sự vận hành, không bị gián đoạn hay phụ thuộc vào sóng di động, nghẽn mạng SMS viễn thông.
    3. *Hỗ trợ Demo & Chấm thi thuận tiện:* Tích hợp cơ chế **Demo Role Switcher** tại Cổng chào (Welcome Gate) và Settings, giúp Hội đồng chấm thi chuyển đổi trực tiếp sang vai trò Admin trong 1 chạm để đánh giá tính năng mà không bị cản trở bởi bước xác thực SMS.

### 1.4. Kiến Trúc An Ninh Xác Thực & Nguyên Tắc Không Lưu Mật Khẩu Trong Database (Final Architecture Decision)

* **Tách biệt Trách nhiệm Giữa Identity Provider (IdP) và Database:**
  * **Firebase Authentication (Identity Provider - IdP):** Là hạ tầng định danh độc lập của Google. Quản lý toàn bộ thông tin đăng nhập nhạy cảm (Credentials gồm Email, Password, Số điện thoại, Session Tokens).
  * **Cloud Firestore (NoSQL Database):** Chỉ lưu trữ các thuộc tính nghiệp vụ (Business Domain Model) trong collection `users/{uid}`: `id`, `fullName`, `phone`, `email`, `role`, `avatarUrl`, `authProviders`, `isEmailVerified`, `createdAt`, `updatedAt`.
* **Nguyên tắc An ninh Quốc tế (OWASP & NIST SP 800-63B):**
  * **TUYỆT ĐỐI KHÔNG lưu trữ mật khẩu (dù là plaintext hay băm thô) trong database Firestore:**
    1. *Phòng chống rò rỉ dữ liệu (Data Breach Prevention):* Nếu lưu mật khẩu trong Firestore, bất kỳ sơ suất nào về Firestore Security Rules hoặc mã phía client cũng có thể làm lộ dữ liệu mật khẩu của người dùng.
    2. *Thuật toán băm mật mã học cấp cao:* Firebase Auth băm mật khẩu bằng thuật toán mật mã chuyên dụng của Google (**Modified Scrypt** kết hợp Salt ngẫu nhiên và Server Pepper). Ngay cả Quản trị viên hệ thống (Admin) hay lập trình viên đều KHÔNG THỂ đọc hoặc giải mã được mật khẩu.
    3. *Trao đổi Token an toàn (JWT-based):* Khi người dùng đăng nhập bằng `signInWithEmailAndPassword`, SDK trao đổi trực tiếp với Google Identity Endpoint qua kênh bảo mật TLS 1.3, nhận về cặp JWT (`idToken` và `refreshToken`). Ứng dụng dùng UID này để truy vấn Firestore `users/{uid}` mà không bao giờ cần chạm vào mật khẩu.

### 1.5. Hướng Dẫn Cấu Hình Bắt Buộc Trên Firebase Console (Zero-Cost Setup Guide)

Để hệ thống xác thực Đa kênh hoạt động hoàn hảo 100% không phát sinh chi phí:

1. **Bật Email/Password Provider:**
   * Truy cập **Firebase Console** -> Dự án `jet-post` -> **Build** -> **Authentication** -> Tab **Sign-in method**.
   * Nhấp chọn provider **Email/Password** -> Bật công tắc **Enable** đầu tiên (*Allow users to sign up using their email address and password*).
   * Bấm **Save** (Không cần bật toggle thứ hai *"Email link"* vì hệ thống đã sử dụng Cloudflare Worker Server-Side OTP).
2. **Cấu hình Phone Provider & Danh Sách Số Whitelist Testing:**
   * Tại tab **Sign-in method**, kiểm tra provider **Phone** đã được **Enable**.
   * Mở rộng mục **Phone numbers for testing (optional)**, khai báo danh sách số mẫu và mã OTP cố định để kiểm thử không mất phí SMS viễn thông:
     * `+84988888888` ➔ OTP: `123456`
     * `+84977777777` ➔ OTP: `123456`
     * `+84966666666` ➔ OTP: `123456`
     * `+84912345678` ➔ OTP: `123456`
     * *(Khuyến nghị):* Thêm số điện thoại thực tế của thành viên phát triển/Hội đồng chấm thi kèm mã OTP `123456` để demo đăng nhập trực tiếp trên thiết bị thật.
3. **Quy Tắc Bảo Mật Firestore (Security Rules):**
   * Truy cập **Build** -> **Firestore Database** -> Tab **Rules**.
   * Đảm bảo cho phép người dùng truy cập dữ liệu cá nhân theo ID:
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{userId} {
           allow read: if request.auth != null;
           allow write: if request.auth != null && request.auth.uid == userId;
         }
         match /drivers/{driverId} {
           allow read: if request.auth != null;
           allow write: if request.auth != null && request.auth.uid == driverId;
         }
         match /conversations/{chatId}/{document=**} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```

---

## 2. DANH MỤC MÀN HÌNH (SCREENS) VÀ ĐIỀU HƯỚNG ROUTES

|     STT     | Tên Màn hình                                     | Route Name               | File Mã nguồn                        | Mục đích & Nghiệp vụ                                               |
| :---------: | :-------------------------------------------------- | :----------------------- | :------------------------------------- | :---------------------------------------------------------------------- |
| **1** | **Cổng Chào & Điều phối Vai trò**       | `/` (welcomeGate)      | `screens/welcome_gate_screen.dart`   | Cổng vào 4 phân hệ, Demo Switcher, kiểm tra Auto-login             |
| **2** | **Xác thực Đăng nhập Số Điện thoại** | `/user/phone-auth`     | `screens/phone_auth_screen.dart`     | Nhập SĐT VN, gửi SMS OTP, nhập 6 số OTP xác thực                 |
| **3** | **Đăng ký Đối tác Tài xế (eKYC)**     | `/user/driver-ekyc`    | `screens/driver_ekyc_screen.dart`    | Nhập xe/biển số, chụp CCCD 2 mặt, chụp GPLX tải Cloudinary       |
| **4** | **Chờ Phê duyệt Hồ sơ Tài xế**         | `/user/kyc-pending`    | `screens/kyc_pending_screen.dart`    | Thông báo hồ sơ đang xét duyệt, chờ Admin duyệt ở Task 4.3    |
| **5** | **Quản lý Hồ sơ Cá nhân**               | `/user/profile`        | `screens/user_profile_screen.dart`   | Xem/sửa Họ tên, đổi Avatar Cloudinary, đổi SĐT, Đăng xuất    |
| **6** | **Cài đặt Ứng dụng & Trải nghiệm**     | `/user/settings`       | `screens/app_settings_screen.dart`   | Dark/Light mode, Âm thanh & Rung, Demo Role Switcher                   |
| **7** | **Hộp thư Hội thoại P2P (Inbox)**         | `/user/messages-inbox` | `screens/messages_inbox_screen.dart` | Danh sách chat gần nhất, tìm kiếm người dùng, badge chưa đọc |
| **8** | **Phòng Chat Trực tiếp 1-1**               | `/user/direct-chat`    | `screens/direct_chat_screen.dart`    | Chat bong bóng 2 chiều real-time Firestore stream, gửi text          |

---

## 3. THIẾT KẾ CHI TIẾT UX/UI VÀ LUỒNG HOẠT ĐỘNG TỪNG MÀN HÌNH

---

### MÀN HÌNH 1: CỔNG CHÀO & ĐIỀU PHỐI VAI TRÒ (WELCOME GATE SCREEN)

* **File:** `lib/modules/user/screens/welcome_gate_screen.dart`
* **Route:** `AppRoutes.welcomeGate` (`/`)
* **Ngữ cảnh sử dụng:** Mở ra khi khởi động app lần đầu, hoặc sau khi người dùng bấm "Đăng xuất" từ bất kỳ phân hệ nào.

#### Thiết kế UX/UI:

* **Header / Hero Banner:**
  * Gradient xanh lá nhận diện JetPost (`#00A86B` ➔ `#007A4D`).
  * Badge trạng thái mạ kính (Glassmorphism): `"Firebase Cloud Connected"`.
  * Tiêu đề: `"Hệ Thống Giao Vận JetPost"` - Đồ án Chuyên đề CNTT Nhóm 14.
* **Khu vực Cổng vào 4 Phân hệ (4 Role Cards):**
  1. 🟢 **Phân hệ Khách Hàng (Module 1):** Icon xe ôm ghim vị trí, mô tả: *"Đặt xe ôm di chuyển, tạo đơn gửi hàng & theo dõi hành trình"*, tag: *"Thành viên 1"*.
  2. 🟡 **Đối Tác Tài Xế JetPost (Module 2):** Icon xe máy hai bánh, mô tả: *"Bật trực tuyến GPS, nhận cuốc 15s & xác nhận giao hàng PoD"*, tag: *"Thành viên 2"*.
  3. 🟣 **Tài Khoản & Định Danh eKYC (Module 3):** Icon khiên bảo mật, mô tả: *"Xác thực SMS OTP, nộp CCCD/bằng lái & Chat P2P trực tiếp"*, tag: *"Thành viên 3"*.
  4. 🔵 **Quản Trị Điều Hành Hệ Thống (Module 4):** Icon radar admin, mô tả: *"Bàn cờ Radar toàn thành phố, thẩm định eKYC & cấu hình cước"*, tag: *"Thành viên 4"*.
* **Nút Demo Role Switcher (Góc AppBar):**
  * Icon biểu tượng chuyển đổi nhanh vai trò giúp Hội đồng chấm thi đổi qua lại giữa 4 phân hệ trong tích tắc mà không cần nhập lại OTP.

#### Luồng hoạt động (Activity Flow):

1. Khi mở app, `initState()` kích hoạt `UserService.instance.checkAutoLogin()`:
   * Nếu đã lưu phiên hợp lệ trong `shared_preferences` ➔ Điều hướng thẳng vào Dashboard của vai trò tương ứng (Khách hàng / Tài xế / Admin).
   * Nếu chưa đăng nhập hoặc vừa bấm Đăng xuất ➔ Giữ nguyên Welcome Gate.
2. Người dùng chọn 1 trong 4 cổng:
   * Chọn **"Khách hàng"**: Nếu chưa đăng nhập ➔ Mở màn hình Phone Auth (vai trò customer); nếu đã đăng nhập ➔ Vào thẳng `AppRoutes.customerHome`.
   * Chọn **"Đối tác Tài xế"**: Kiểm tra nếu chưa eKYC ➔ Chuyển hướng sang màn hình Đăng ký eKYC; nếu đang chờ duyệt ➔ Mở `KycPendingScreen`; nếu đã duyệt `ACTIVE` ➔ Mở `AppRoutes.driverDashboard`.
   * Chọn **"Quản trị Admin"**: Mở luồng xác thực Admin bảo mật (Task 4.1).
   * Chọn **"Đăng ký eKYC"**: Mở thẳng màn hình `AppRoutes.driverKyc`.

---

### MÀN HÌNH 2: XÁC THỰC ĐA TẦNG QUA SỐ ĐIỆN THOẠI (PHONE AUTH SCREEN)

* **File:** `lib/modules/user/screens/phone_auth_screen.dart`
* **Route:** `AppRoutes.phoneAuth` (`/user/phone-auth`)
* **Ngữ cảnh sử dụng:** Đăng ký tài khoản mới hoặc đăng nhập vào hệ thống JetPost.

#### Thiết kế UX/UI (Stateful Widget 2 giai đoạn mượt mà - AnimatedSwitcher):

* **Giai đoạn 1: Nhập Số Điện Thoại (Phone Input State)**

  * Minh họa Hero minh họa đồ họa vector viễn thông bảo mật.
  * Tiêu đề: `"Nhập Số Điện Thoại"`. Phụ đề: `"JetPost sẽ gửi mã xác thực SMS OTP gồm 6 chữ số về số điện thoại của bạn"`.
  * Ô nhập liệu chuẩn quốc tế:
    * Tiền tố cố định: Cờ Việt Nam 🇻🇳 kèm mã quốc gia `+84`.
    * Bàn phím số chuyên dụng (`keyboardType: TextInputType.phone`).
    * Trình kiểm duyệt Regex tức thời: Bắt buộc 10 chữ số, chỉ chấp nhận các đầu số nhà mạng VN hợp lệ (`03, 05, 07, 08, 09`). Nếu nhập sai ➔ Viền đỏ báo lỗi: *"Số điện thoại không hợp lệ!"*.
  * Hộp thông báo hỗ trợ Demo (Testing Numbers Helper Card):
    * Hiển thị danh sách 4 số điện thoại nội bộ dùng thử nghiệm miễn phí: `0988888888`, `0977777777`, `0966666666`, `0912345678` (Mã OTP cố định: `123456`).
    * Bấm 1 chạm vào số bất kỳ ➔ Tự động điền nhanh vào ô nhập liệu để giảng viên/sinh viên demo ngay.
  * Nút bấm hành động: `"Tiếp tục nhận mã OTP"` (ElevatedButton màu xanh chủ đạo).
* **Giai đoạn 2: Nhập Mã Xác thực OTP (OTP Verification State)**

  * Hiển thị số điện thoại vừa gửi mã dạng: `+84 988 *** 8888` kèm nút icon bút chì `"Đổi số khác"` để quay lại Giai đoạn 1.
  * Cụm 6 ô vuông nhập mã OTP (Pin Code Input / Pinput Widget):
    * Kích thước 48x54dp bo góc, viền xanh neon nổi bật khi focus.
    * Tự động nhảy con trỏ sang ô tiếp theo khi nhập từng số.
    * Hỗ trợ tự động điền mã (SMS Auto-fill / Clipboard Paste 6 số).
  * Bộ đếm ngược Chống Spam (Rate-limiting Cooldown Timer):
    * Hiển thị: `"Gửi lại mã sau 00:59"`.
    * Nút "Gửi lại mã OTP" bị vô hiệu hóa (disabled) trong suốt 60 giây. Sau 60 giây nút mới sáng lại.
  * Nút bấm: `"Xác nhận & Đăng nhập"` (Hiển thị CircularProgressIndicator khi đang xác thực).

#### Luồng hoạt động (Activity Flow):

1. Người dùng bấm "Tiếp tục" ➔ Chuẩn hóa SĐT sang chuẩn E.164 (`0988...` ➔ `+84988...`).
2. Gọi `UserService.instance.verifyPhoneNumber()`:
   * Kích hoạt `FirebaseAuth.instance.verifyPhoneNumber`.
   * Nhận `verificationId` và chuyển giao diện sang Giai đoạn 2.
3. Người dùng nhập đủ 6 số OTP ➔ Tự động kích hoạt hàm kiểm tra `verifyOtpCode()`:
   * Tạo `PhoneAuthCredential` và đăng nhập Firebase: `signInWithCredential()`.
   * Kiểm tra document người dùng trên Firestore collection `users`:
     * Nếu là người dùng mới ➔ Tạo document mới với `role: 'customer'`, `isBanned: false`, thời gian khởi tạo.
     * Nếu là người dùng cũ ➔ Đọc `role` hiện tại.
   * Lưu token phiên vào `shared_preferences`.
   * Điều hướng vào giao diện chính tương ứng.

---

### MÀN HÌNH 3: ĐĂNG KÝ ĐỊNH DANH ĐỐI TÁC TÀI XẾ (DRIVER eKYC SCREEN)

* **File:** `lib/modules/user/screens/driver_ekyc_screen.dart`
* **Route:** `AppRoutes.driverKyc` (`/user/driver-ekyc`)
* **Ngữ cảnh sử dụng:** Khách hàng hoặc người mới muốn đăng ký làm Đối tác Tài xế xe ôm / giao hàng của JetPost.

#### Thiết kế UX/UI (Quy trình 3 Bước trực quan - Stepper UI):

* **Thanh tiến trình (Progress Stepper):**
  * Bước 1: Thông tin xe ➔ Bước 2: Chụp CCCD ➔ Bước 3: Chụp Giấy phép lái xe.
* **Nội dung từng bước:**
  * **Bước 1 - Phương tiện di chuyển:**
    * Dropdown chọn Loại xe (Mặc định: *Xe máy Honda / Yamaha / Khác*).
    * Ô nhập Biển số xe máy (Ví dụ: `29-E1 123.45` hoặc `59-X3 678.90`). Định dạng tự động viết hoa.
  * **Bước 2 - Căn cước công dân (CCCD 2 mặt):**
    * 2 Khung ảnh tải lên: *Mặt trước CCCD* và *Mặt sau CCCD*.
    * Giao diện khung chụp có đường kẻ đứt viền chữ nhật hướng dẫn đặt thẻ đúng tâm.
    * Nút chọn: Chụp ảnh trực tiếp từ Camera hoặc Chọn ảnh rõ nét từ Thư viện.
    * Khi chọn xong: Hiển thị ảnh thu nhỏ (preview) kèm thanh trạng thái upload Cloudinary (`jetpost/drivers_ekyc`).
  * **Bước 3 - Giấy phép lái xe (GPLX):**
    * Khung tải ảnh Bằng lái xe A1/A2.
    * Checkbox cam kết: *"Tôi cam kết thông tin và giấy tờ tùy thân cung cấp là hoàn toàn chính xác và chịu trách nhiệm trước pháp luật"*.
* **Nút bấm gửi hồ sơ:** `"Gửi Hồ Sơ Thẩm Định"` (Kiểm tra đủ 3 ảnh mới cho bấm).

#### Luồng hoạt động (Activity Flow):

1. Người dùng chọn/chụp ảnh ➔ Gọi `CloudinaryService.instance.uploadDriverKyc()`:
   * Tải ảnh mặt trước ➔ Nhận `idCardFrontUrl`.
   * Tải ảnh mặt sau ➔ Nhận `idCardBackUrl`.
   * Tải ảnh bằng lái ➔ Nhận `licenseUrl`.
2. Bấm "Gửi hồ sơ" ➔ Ghi dữ liệu vào collection `drivers` trên Firestore:
   ```dart
   {
     'id': currentUser.uid,
     'plateNumber': '29-E1 123.45',
     'vehicleType': 'motorcycle',
     'idCardFrontUrl': idCardFrontUrl,
     'idCardBackUrl': idCardBackUrl,
     'licenseUrl': licenseUrl,
     'status': 'PENDING_APPROVAL',
     'isOnline': false,
     'isBusy': false,
     'walletBalance': 0.0,
     'rating': 5.0,
     'lastActiveAt': FieldValue.serverTimestamp(),
   }
   ```
3. **BẢO MẬT PHÂN QUYỀN (RBAC Guard):** Giữ nguyên vai trò `'customer'` trong `users/{uid}`, chỉ tạo bản ghi đăng ký đối tác `'PENDING_APPROVAL'` trong `drivers/{uid}`. Vai trò `'driver'` chỉ được kích hoạt chính thức khi Admin thẩm định CCCD/GPLX và bấm **Phê duyệt** (Task 4.3).
4. Điều hướng sang Màn hình Chờ Phê duyệt (`KycPendingScreen`).

---

### MÀN HÌNH 4: CHỜ PHÊ DUYỆT HỒ SƠ TÀI XẾ (KYC PENDING SCREEN)

* **File:** `lib/modules/user/screens/kyc_pending_screen.dart`
* **Route:** `/user/kyc-pending`
* **Ngữ cảnh sử dụng:** Tài xế vừa nộp eKYC hoặc tài xế mở app khi tài khoản chưa được Admin duyệt (`status == 'PENDING_APPROVAL'`).

#### Thiết kế UX/UI:

* Hình minh họa đồng hồ cát / thẻ định danh đang quét radar.
* Tiêu đề: `"Hồ Sơ Đang Chờ Thẩm Định"`.
* Nội dung thông báo: *"JetPost đã tiếp nhận hồ sơ đăng ký đối tác của bạn. Ban Quản trị (Admin) đang tiến hành đối soát CCCD và Bằng lái xe. Kết quả sẽ được cập nhật trong vòng 24 giờ."*
* Hộp thông tin tóm tắt hồ sơ: Biển số xe, thời gian nộp, nhãn vàng cam: `ĐANG XÉT DUYỆT`.
* Nút bấm:
  * `"Kiểm tra trạng thái xét duyệt"` (Truy vấn lại Firestore xem Admin đã bấm duyệt ở Task 4.3 chưa).
  * `"Quay về Trang chủ Khách hàng"` (Cho phép tiếp tục dùng app với vai trò Khách trong lúc chờ duyệt).

---

### MÀN HÌNH 5: QUẢN LÝ HỒ SƠ CÁ NHÂN (USER PROFILE SCREEN)

* **File:** `lib/modules/user/screens/user_profile_screen.dart`
* **Route:** `AppRoutes.userProfile` (`/user/profile`)
* **Ngữ cảnh sử dụng:** Xem, chỉnh sửa thông tin cá nhân của Khách hàng hoặc Tài xế.

#### Thiết kế UX/UI:

* **Avatar Header:**
  * Ảnh tròn lớn (CircleAvatar bán kính 50dp).
  * Nút icon máy ảnh nhỏ ở góc dưới avatar: Chạm vào để mở BottomSheet chọn ảnh đại diện mới.
  * Tải ảnh mới lên Cloudinary (`jetpost/avatars`) ➔ Cập nhật ngay trường `avatarUrl` trong `users/{uid}`.
* **Danh sách Trường thông tin (Profile Form):**
  * Họ và tên: Cho phép gõ sửa và bấm nút lưu (Save).
  * Số điện thoại: Hiển thị SĐT hiện tại kèm huy hiệu `"Đã xác minh"`.
  * Vai trò tài khoản: Huy hiệu nổi (Khách hàng / Đối tác Tài xế / Quản trị viên).
  * Ngày tham gia nền tảng.
* **Chức năng nâng cao:**
  * Nút `"Đổi Số Điện Thoại"`: Mở dialog nhập số điện thoại mới ➔ Gửi OTP xác thực số mới ➔ Cập nhật SĐT trên Firestore.
* **Khu vực Đăng xuất:**
  * Nút bấm đỏ viền cong: `"Đăng xuất khỏi thiết bị"`. Bấm vào hiển thị AlertDialog xác nhận ➔ Xóa token phiên và quay về Welcome Gate.

---

### MÀN HÌNH 6: CÀI ĐẶT ỨNG DỤNG & TRẢI NGHIỆM (APP SETTINGS SCREEN)

* **File:** `lib/modules/user/screens/app_settings_screen.dart`
* **Route:** `AppRoutes.appSettings` (`/user/settings`)
* **Ngữ cảnh sử dụng:** Tùy biến theme giao diện, âm thanh, thông báo và hỗ trợ demo chuyển vai trò.

#### Thiết kế UX/UI:

* **Nhóm 1 - Giao diện & Hiển thị (Theme Mode):**
  * Tùy chọn 3 chế độ:
    * ☀️ **Giao diện Sáng (Light Mode):** Tối ưu đọc ban ngày ngoài trời nắng.
    * 🌙 **Giao diện Tối (Dark Mode):** Nền đen xám sang trọng, dịu mắt tài xế lái xe ban đêm, tiết kiệm pin AMOLED.
    * ⚙️ **Theo Hệ thống (System Default):** Tự động đồng bộ theo cài đặt điện thoại.
* **Nhóm 2 - Âm thanh & Báo động (Sound & Haptics):**
  * Switch gạt: *"Âm thanh chuông báo cuốc xe mới"* (Bật/Tắt chuông reo to 15s cho tài xế).
  * Switch gạt: *"Rung khi có tin nhắn & cập nhật đơn hàng"*.
* **Nhóm 3 - Công cụ Chấm điểm & Kiểm thử (Hội đồng Đồ án):**
  * **"Demo Role Switcher" Card:** Cho phép chọn nhanh vai trò để nhảy thẳng vào giao diện:
    * Chuyển sang Khách hàng (`customer`)
    * Chuyển sang Đối tác Tài xế (`driver`)
    * Chuyển sang Quản trị viên (`admin`)
* **Nhóm 4 - Thông tin Sản phẩm:**
  * Phiên bản JetPost v1.0.0 (Build 2026).
  * Đề tài Chuyên đề CNTT - Nhóm 14 - TLU.

---

### MÀN HÌNH 7: HỘP THƯ HỘI THOẠI P2P (MESSAGES INBOX SCREEN)

* **File:** `lib/modules/user/screens/messages_inbox_screen.dart`
* **Route:** `AppRoutes.messagesInbox` (`/user/messages-inbox`)
* **Ngữ cảnh sử dụng:** Trung tâm hiển thị toàn bộ các cuộc trò chuyện 1-1 của tài khoản hiện tại.

#### Thiết kế UX/UI:

* **Thanh tìm kiếm (Search Bar):** Tìm kiếm hội thoại theo tên người liên hệ hoặc số điện thoại.
* **Danh sách Hội thoại Thời gian thực (Real-time StreamBuilder từ `conversations`):**
  * Query: `where('participants', arrayContains: currentUserId).snapshots()`. Sắp xếp mảng in-memory theo `updatedAt` mới nhất để đảm bảo 100% Real-time mà không cần tạo Composite Index thủ công trên Firebase Console.
  * Mỗi item trong danh sách (ConversationCard):
    * Avatar tròn của người đối thoại (hiển thị qua `CloudinaryService.getOptimizedUrl(..., width: 100)`).
    * Tên người đối thoại (in đậm).
    * Trích đoạn tin nhắn gần nhất (`lastMessage`).
    * Mốc thời gian gửi (Ví dụ: `10:30`, `Hôm qua`, `20/10`).
    * Huy hiệu đếm số tin nhắn chưa đọc (Badge màu xanh nổi bật nếu `unreadCount > 0`).
* **Nút Soạn tin nhắn mới (FloatingActionButton):**
  * Bấm vào mở BottomSheet hoặc Dialog: Nhập số điện thoại người cần nhắn tin (hoặc chọn từ danh bạ gợi ý).
  * Tự động sinh mã phòng chat theo chuẩn alphabet: `chatId = minUid_maxUid` ➔ Mở phòng chat tức thì.

---

### MÀN HÌNH 8: PHÒNG CHAT TRỰC TIẾP 1-1 (DIRECT 1-ON-1 CHAT ROOM)

* **File:** `lib/modules/user/screens/direct_chat_screen.dart`
* **Route:** `AppRoutes.directChat` (`/user/direct-chat`)
* **Ngữ cảnh sử dụng:** Màn hình trò chuyện trực tiếp giữa 2 người dùng (Khách - Tài xế, Khách - Người nhận, Người dùng - Admin).

#### Thiết kế UX/UI:

* **AppBar:**
  * Nút Back.
  * Avatar nhỏ + Tên người đối thoại + Trạng thái trực tuyến (chấm xanh Online).
  * Nút Gọi điện thoại nhanh (Deep-link gọi SĐT qua `url_launcher`).
* **Khu vực Nội dung Chat (Message Stream):**
  * Lắng nghe Stream: `conversations/{chatId}/messages.orderBy('timestamp', descending: true)`.
  * Bong bóng chat (Chat Bubbles):
    * **Tin gửi đi (Của tôi):** Nằm bên phải, nền màu xanh lá chủ đạo JetPost (`AppColors.primary`), chữ trắng, bo góc mềm mại.
    * **Tin nhận về (Đối phương):** Nằm bên trái, nền xám nhạt (`#F0F2F5`), chữ đen, bo góc mềm mại.
    * Hiển thị giờ gửi tin nhỏ mờ dưới mỗi bong bóng (`14:25`).
    * Trạng thái đã xem (Đánh dấu tích kép khi đối phương đã đọc).
* **Thanh Soạn thảo Tin nhắn (Bottom Message Bar):**
  * Ô nhập văn bản nhiều dòng tự co giãn (`TextField`).
  * Nút Gửi (`IconButton` biểu tượng máy bay giấy): Tự động sáng xanh khi có ký tự gõ vào, bấm gửi thì đẩy tin tức thì lên Firestore và làm trống ô nhập liệu.

---

## 4. DỮ LIỆU & DỊCH VỤ LÕI: `UserService`

Phân hệ User tập trung toàn bộ logic nghiệp vụ trong [user_service.dart](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/user/services/user_service.dart), tách biệt độc lập với các phân hệ khác:

```dart
class UserService {
  // 1. Quản lý Phiên & Phân quyền
  Future<bool> checkAutoLogin();
  Future<void> saveUserSession(UserModel user);
  Future<void> logout();

  // 2. Xác thực Phone Auth OTP
  Future<void> sendOtpCode(String phone, {required Function(String verificationId) onCodeSent, ...});
  Future<UserCredential?> verifyOtpCode(String verificationId, String smsCode);

  // 3. Quản lý Hồ sơ & eKYC
  Future<UserModel?> getCurrentUserProfile();
  Future<void> updateUserProfile({String? fullName, String? avatarUrl});
  Future<void> submitDriverKyc({required String vehicleType, required String plateNumber, required String idCardFrontUrl, required String idCardBackUrl, required String licenseUrl});
  Future<DriverApprovalStatus> checkDriverKycStatus(String driverId);

  // 4. Chat P2P Thời gian thực
  Stream<List<ConversationModel>> getConversationsStream();
  Stream<List<MessageModel>> getMessagesStream(String chatId);
  Future<String> getOrCreateConversation(String targetUserId);
  Future<void> sendMessage(String chatId, String receiverId, String content);
}
```

### 4.2. Hệ thống Giám sát & Ghi nhận Thao tác Người dùng (AppLogger & Action Audit) (Final Decision)

Toàn bộ thao tác của người dùng trên giao diện và các luồng dịch vụ ngầm đều được gắn log chuẩn hóa thông qua [app_logger.dart](file:///d:/ChuyenDeCNTT/jet_post/lib/core/utils/app_logger.dart) định dạng thẻ ASCII chuẩn để tương thích 100% với môi trường dòng lệnh Windows/PowerShell (không lỗi font CP437):

* **`[USER_ACTION]`**: Ghi nhận chính xác vị trí màn hình, tên nút bấm, chạm chip SĐT mẫu, mở bottom sheet, chuyển tab.
* **`[AUTH]`**: Ghi nhận toàn bộ chu trình xác thực (chuẩn hóa E.164, gửi SMS OTP, nhận verificationId, xác thực mã 6 số, đọc/tạo document Firestore, lưu session SharedPreferences).
* **`[NAV]`**: Ghi nhận hành trình điều hướng giữa các màn hình và tham số truyền theo.
* **`[EKYC]`**: Giám sát tiến độ chụp ảnh, tải ảnh lên Cloudinary (`jetpost/drivers_ekyc`), nộp hồ sơ tài xế và kiểm tra trạng thái phê duyệt.
* **`[CHAT]`**: Giám sát khởi tạo phòng chat, gửi tin nhắn P2P, cuộn tin nhắn và đánh dấu đã đọc.
* **`[SETTINGS]`**: Giám sát thay đổi theme sáng/tối, bật/tắt chuông báo cuốc xe, rung và công tắc Demo Role Switcher.

---

## 5. TIẾN ĐỘ THỰC HIỆN & BÀN GIAO THỰC TẾ (SPRINT DELIVERY)

* **Giai đoạn 1 (Hạ tầng & Dịch vụ):** Hoàn thành `UserService`, `CloudinaryService`, `AppLogger`, Models và Shared Preferences session.
* **Giai đoạn 2 (Widgets Tái sử dụng):** Hoàn thành `PhoneInputField`, `OtpPinInput`, `RoleBadge`, `ConversationCard`, `ChatBubble`.
* **Giai đoạn 3 (Màn hình Giao diện):** Hoàn thành 8 màn hình chuẩn chỉ (Welcome Gate, Phone Auth, Driver eKYC, KYC Pending, Profile, Settings, Inbox, Direct Chat).
* **Giai đoạn 4 (Kiểm định Chất lượng):** `flutter analyze` 0 lỗi, biên dịch thành công `app-debug.apk`, tích hợp đầy đủ hệ thống log giám sát kiểm thử trên thiết bị thật.

---

## 6. TỔNG HỢP CÁC LỖI THỰC TẾ & GIẢI PHÁP TỐI ƯU CUỐI CÙNG (TROUBLESHOOTING & POST-TESTING)

1. **Lỗi Firestore Composite Index (`FAILED_PRECONDITION` tại Màn hình Chat P2P):**
   * *Nguyên nhân:* Truy vấn đồng thời `where('participants', arrayContains: uid)` và `orderBy('updatedAt', descending: true)` yêu cầu tạo Composite Index thủ công trên Firebase Console.
   * *Giải pháp cuối cùng:* Bỏ `orderBy` trong Firestore query, thực hiện sắp xếp thời gian mới nhất trực tiếp trên mảng Dart (`list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));`). App hoạt động mượt mà tức thì mà không cần can thiệp cấu hình console.
2. **Lỗi Tràn Viền Giao Diện (Right Overflowed):**
   * *Màn hình eKYC Tài xế:* Tràn 10px tại Dropdown chọn loại xe máy. Giải pháp: Thêm thuộc tính `isExpanded: true` và `overflow: TextOverflow.ellipsis` cho các `DropdownMenuItem`.
   * *Màn hình Cổng vào (Welcome Gate):* Tràn 26px khi tên người dùng dài (`sbwbwbwbwb1111...`). Giải pháp: Bọc `Text` trong `Flexible` kèm `maxLines: 1` và `TextOverflow.ellipsis`.
3. **Lỗi Kẹt Loading Vô Hạn khi Gửi Lại Mã với Cùng Số Điện Thoại (Phone Auth):**
   * *Nguyên nhân:* Người dùng quay lại màn hình nhập SĐT rồi bấm gửi tiếp cho cùng 1 số trong thời gian cooldown, Firebase Auth trên Android kích hoạt cơ chế throttle nội bộ khiến callback không được kích hoạt lại.
   * *Giải pháp cuối cùng:*
     - Kiểm tra nếu SĐT không thay đổi và mã `_verificationId` còn hiệu lực: Chuyển thẳng sang bước nhập OTP mà không tạo thêm yêu cầu SMS mới.
     - Hỗ trợ truyền `forceResendingToken: _resendToken` khi thực hiện gửi lại mã thực sự.
     - Kích hoạt bộ hẹn giờ an toàn 15 giây (`_safetyTimeoutTimer`): Tự động mở khóa nút bấm nếu máy chủ viễn thông phản hồi chậm.
4. **Giải pháp Triệt Để Hiện tượng Log Rác & Lỗi Phông Chữ Tiếng Việt (Mojibake trên Windows Console):**
   * *Nguyên nhân:* Mặc dù các thẻ tag đã được đổi sang ASCII, nhưng nội dung thông báo và chi tiết thao tác người dùng bằng tiếng Việt có dấu (`Chạm vào chip...`, `Bấm gửi mã OTP...`) khi in ra console Windows (PowerShell/CMD mặc định chạy CodePage 437) sẽ bị vỡ thành các byte ký tự Latin dị dạng (`Chß║ím v├áo chip sß╗æ ─æiß╗çn thoß║íi...`). Đồng thời các ký tự mũi tên Unicode như `➔`, `→` bị hiển thị thành `≡ƒöÉ`, `Γ₧ö`.
   * *Giải pháp cuối cùng:* Triển khai hàm `_stripDiacritics(String text)` và cổng xuất tập trung `_log()` trong [app_logger.dart](file:///d:/ChuyenDeCNTT/jet_post/lib/core/utils/app_logger.dart). Tự động chuyển đổi toàn bộ thông điệp, tham số tiếng Việt có dấu sang tiếng Việt không dấu (Pure ASCII 7-bit) và thay thế mũi tên Unicode bằng `->` trước khi xuất log ra `debugPrint`. Log trên mọi môi trường Windows PowerShell, CMD, Git Bash hoàn toàn sạch đẹp 100%.
   * *Ghi chú log hệ thống:* Log `W/Firestore: Stream closed UNAVAILABLE` và `Error getting App Check token` là log nội bộ của Firebase SDK Android khi chạy dev mode không có AppCheck provider; không ảnh hưởng tới hoạt động của app.
5. **Lỗi Bảo Mật Phân Quyền eKYC (RBAC Flaw) & Điều Hướng Sau Đăng Nhập:**
   * *Nguyên nhân:* Trước đây hàm `submitDriverKyc` tự ý nâng quyền `users/{uid}.role = 'driver'` ngay khi người dùng nộp hồ sơ. Khi đăng xuất và đăng nhập lại bằng SĐT, bộ điều hướng trong `PhoneAuthScreen` chỉ đọc `user.role == UserRole.driver` và lập tức nhảy thẳng vào `/driver/dashboard` (màn hình chưa cấu hình của Phân hệ 2) thay vì kiểm tra trạng thái xét duyệt.
   * *Giải pháp cuối cùng:*
     - Khi nộp eKYC: Giữ nguyên `role: 'customer'` trong `users/{uid}`. Chỉ lưu hồ sơ vào `drivers/{uid}` với `status: 'PENDING_APPROVAL'`.
     - Cài đặt **RBAC Route Guard** tại `PhoneAuthScreen`: Khi đăng nhập tài khoản có `role == driver` hoặc khi người dùng đăng nhập từ cổng tài xế, hệ thống bắt buộc gọi `UserService.instance.getDriverProfile(uid)`:
       - Nếu `driver.status == pendingApproval`: Điều hướng sang `AppRoutes.kycPending` (`KycPendingScreen`).
       - Nếu `driver.status == active`: Cho phép vào `AppRoutes.driverDashboard`.
       - Nếu bị khóa (`banned`): Giữ ở `WelcomeGate` và hiển thị cảnh báo.
6. **Lỗi Nút Back Vô Nghĩa & Đè Chồng Route Trên Màn Hình Cổng Vào (Welcome Gate):**
   * *Nguyên nhân:* Khi người dùng mở `PhoneAuthScreen` từ `WelcomeGateScreen` rồi đăng nhập thành công, trước đây dùng lệnh `Navigator.pushReplacementNamed(..., AppRoutes.welcomeGate)`. Lệnh này chỉ thay thế màn hình auth bằng 1 instance `WelcomeGate` mới đè lên `WelcomeGate` cũ ban đầu. Do trong ngăn xếp vẫn còn route bên dưới, Flutter tự động hiển thị nút mũi tên quay lại (`<-`) trên AppBar. Khi bấm vào, màn hình pop về `WelcomeGate` cũ gây cảm giác "điều hướng tại chỗ vô nghĩa".
   * *Giải pháp cuối cùng:*
     - Đặt thuộc tính `automaticallyImplyLeading: false` cho `AppBar` trong `WelcomeGateScreen` (vì đây là Root Gate Portal của toàn bộ ứng dụng).
     - Khi đăng nhập thành công, sử dụng `Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);` để dọn sạch hoàn toàn navigation stack, tránh hiện tượng đè chồng các màn hình cổng vào.
7. **Lỗi Không Đổi Được Giao Diện (Theme Mode Bị Kẹt Luôn Tối):**
   * *Nguyên nhân:*
     - Biến `themeModeNotifier` trước đây nằm cục bộ trong `main.dart`, trong khi `AppSettingsScreen` khi được mở từ `AppRoutes` không nhận callback `onThemeModeChanged`, dẫn đến hàm `_saveThemeMode` chỉ lưu vào SharedPreferences mà không thể kích hoạt `MaterialApp` render lại.
     - Vì giá trị khởi tạo là `ThemeMode.system` và thiết bị kiểm thử đang bật Dark Mode ở cài đặt hệ điều hành Android, ứng dụng luôn hiển thị giao diện Tối mà không phản hồi thao tác đổi Theme.
   * *Giải pháp cuối cùng:*
     - Chuyển `themeModeNotifier` thành bộ quản trị trạng thái phản ứng tập trung tại [app_theme.dart](file:///d:/ChuyenDeCNTT/jet_post/lib/core/theme/app_theme.dart) (`AppTheme.themeModeNotifier`).
     - Cung cấp phương thức `AppTheme.init()` và `AppTheme.setThemeMode(mode)` quản lý tập trung việc phát tín hiệu và lưu trữ vào `SharedPreferences`.
     - `AppSettingsScreen` gọi trực tiếp `await AppTheme.setThemeMode(mode)`, giúp `MaterialApp` tức thì chuyển đổi giao diện Sáng (Light) / Tối (Dark) / Hệ thống (System) mượt mà 100%.
8. **Lỗi Không Nhận Được SMS OTP Thực Tế (`BILLING_NOT_ENABLED` - Error code 17499):**
   * *Nguyên nhân:* Theo chính sách mới nhất của Google Firebase (áp dụng từ 2024), để gửi tin nhắn SMS viễn thông thực tế tới SIM điện thoại ngoài đời, dự án Firebase bắt buộc phải nâng cấp lên **Gói Blaze (Pay-as-you-go - Có liên kết thẻ tín dụng quốc tế)**. Trên gói miễn phí Spark, Firebase tự động chặn mọi yêu cầu gửi SMS thực với mã lỗi: `[SmsRetrieverHelper] SMS verification code request failed: unknown status code: 17499 BILLING_NOT_ENABLED`.
   * *Giải pháp cuối cùng:*
     - Đúng chuẩn tài liệu kiến trúc [KeHoach.md](file:///d:/ChuyenDeCNTT/jet_post/KeHoach.md) (Task 3.2): Sử dụng cơ chế **Whitelist Testing Numbers** được cấu hình sẵn trên Firebase Console (gắn sẵn các chip chọn nhanh SĐT mẫu kèm OTP cố định `123456`).
     - Nếu muốn test bằng chính số điện thoại cá nhân (ví dụ: `0337225323`), chỉ cần thêm số này vào danh sách *"Phone numbers for testing"* trên Firebase Console với mã OTP tùy chọn (ví dụ: `123456`), hệ thống sẽ cho phép xác thực tức thì 100% mà không bị lỗi `BILLING_NOT_ENABLED` và không tốn phí viễn thông.
9. **Đánh Giá Tính Khả Thi: Phương Án Dùng Thiết Bị Admin Làm Trạm Chuyển Tiếp OTP (Admin SMS / Zalo Relay Gateway):**
   * *Đề xuất thảo luận:* Thiết lập 1 thiết bị mang tài khoản Admin chạy ngầm liên tục, khi Client yêu cầu OTP ➔ Gửi request lên Firestore ➔ Thiết bị Admin sinh mã OTP ngẫu nhiên và tự động gửi tin nhắn SMS hoặc Zalo từ SĐT Admin tới Client.
   * *Đánh giá Chuyên gia Kiến trúc Hệ thống:* Bác bỏ phương án này vì là một Anti-pattern nghiêm trọng:
     - *Đơn điểm chết (SPOF):* Thiết bị Admin hết pin, mất mạng hoặc bị Android Doze Mode làm tê liệt toàn bộ app.
     - *Nguy cơ khóa SIM:* Nhà mạng Việt Nam quét tự động theo Nghị định 91/2020/NĐ-CP; SIM cá nhân gửi nhiều SMS cùng mẫu trong ngày sẽ bị khóa ngay lập tức.
     - *Hạn chế Zalo:* Zalo không có API cho tài khoản cá nhân tự động gửi tin nhắn đến số điện thoại lạ nếu chưa kết bạn (chỉ có dịch vụ Zalo ZNS tính phí dành riêng cho Zalo OA doanh nghiệp).
   * *Giải pháp quyết định:* Không dùng máy Admin làm gateway trung gian.
10. **Kiến Trúc Xác Thực Đa Kênh & Sinh Mã OTP Phía Máy Chủ (Server-Side Cloudflare Worker + Brevo REST API) (Final Architecture Decision):**
    * **Cam kết Chi phí & Kiến trúc An ninh Tuyệt đối:**
      - *Nguyên tắc An ninh Cốt lõi:* **TUYỆT ĐỐI KHÔNG sinh mã OTP trên máy Client (Flutter app)** để ngăn chặn hoàn toàn nguy cơ dịch ngược file APK hoặc can thiệp bộ nhớ RAM để lấy cắp mã OTP.
      - *Hạ tầng Serverless Cấp phát Mã (Server-Side OTP Generator):* Sử dụng **Cloudflare Workers (Edge Serverless Computing)** - 100.000 requests/ngày MIỄN PHÍ VĨNH VIỄN, 100% KHÔNG CẦN THẺ TÍN DỤNG.
        + Máy chủ Worker là nơi độc quyền sinh ngẫu nhiên mã OTP 6 chữ số an toàn (`crypto.getRandomValues`).
        + Máy chủ Worker lưu mã băm + thời hạn 5 phút vào collection `email_otps` trên Firestore.
        + Máy chủ Worker gọi **Brevo Transactional REST API** (miễn phí 300 emails/ngày) gửi email HTML chuẩn JetPost (`#00A86B`) chứa duy nhất mã OTP 6 số (0 đường link) đến hộp thư người dùng.
      - *Xác thực 100% In-App:* Người dùng nhập 6 số trên widget `OtpPinInput` ngay trong ứng dụng di động, không bao giờ phải chuyển sang trình duyệt web ngoài.
    * **Kịch bản Nghiệp vụ Hoàn chỉnh:**
      1. **Đăng ký linh hoạt (Dual Registration):** Người dùng có thể đăng ký bằng Số điện thoại (SMS OTP) HOẶC Email & Mật khẩu. Sau khi đăng ký, có thể vào Profile để liên kết thêm phương thức còn lại.
         - Từ SĐT ➔ Liên kết Email: Nhập Email + Mật khẩu mới ➔ Cloudflare Worker sinh và gửi OTP 6 số vào Email ➔ Nhập OTP trên app để xác thực chính chủ ➔ Hoàn tất liên kết.
         - Từ Email/MK ➔ Liên kết SĐT: Nhập SĐT mới ➔ Firebase gửi SMS OTP để xác thực SIM chính chủ ➔ Hoàn tất liên kết.
      2. **Đăng nhập đa kênh (Dual Login):** Giao diện `PhoneAuthScreen` chuyển đổi thành giao diện Đăng nhập Kép với 2 Tab trực quan: "Số Điện Thoại" (nhập SĐT nhận OTP 6 số) và "Email & Mật Khẩu" (đăng nhập tức thì kèm các Chip tài khoản mẫu `khachhang@jetpost.vn`, `taixe@jetpost.vn`, `admin@jetpost.vn`).
      3. **Quên mật khẩu đa kênh (Forgot Password):** Cho phép nhận mã OTP đặt lại mật khẩu qua Email HOẶC qua Số điện thoại đã liên kết.
      4. **Xác thực Bước nhảy khi Đổi SĐT / Mất SIM (Step-up Account Recovery):**
         - Khi đổi SĐT trong Profile: Hệ thống cung cấp 2 tùy chọn xác minh danh tính bước 1:
           + *Cách 1 (Vẫn còn SIM cũ):* Gửi OTP về SĐT cũ.
           + *Cách 2 (Mất SIM / Mất máy):* Đăng nhập bằng Email/Mật khẩu ➔ Chọn "Gửi mã OTP xác nhận về Email liên kết".
         - Sau khi vượt qua bước 1 ➔ Người dùng nhập SĐT mới ➔ Gửi OTP về SĐT mới ➔ Xác thực hoàn tất cập nhật số.
         - *Trường hợp mất SIM mà chưa liên kết Email:* Hệ thống bảo lưu chính sách bảo mật buộc liên hệ Quản trị viên (Admin) đối soát eKYC hoặc làm lại SIM tại nhà mạng.
    * **Tác động Kéo theo trên Toàn hệ thống (Impacts Analysis):**
      - *Database Firestore (`users`):* Bổ sung trường `email` (String, Nullable), `authProviders` (`['phone', 'email']`), `isEmailVerified` (bool).
      - *Phân hệ 1 (Customer):* Khách hàng có thể đăng ký bằng Email; khi đặt xe/hàng nếu chưa có SĐT app sẽ nhắc bổ sung SĐT để tài xế liên hệ đón/giao.
      - *Phân hệ 2 (Driver):* Tài xế có thể đăng nhập bằng Email; nhưng khi làm eKYC bắt buộc phải có SĐT đã xác thực để phục vụ tổng đài điều phối.
      - *Phân hệ 4 (Admin):* Cổng Admin sử dụng trực tiếp Email/Password; màn hình Quản lý Người dùng (Task 4.4) hỗ trợ tìm kiếm và hiển thị cả Email lẫn SĐT.
11. **Giải Đáp Thắc Mắc Kiến Trúc: Tại Sao Firestore Không Lưu Mật Khẩu & Các Bước Cấu Hình Firebase Console Hoàn Chỉnh:**
    * *Thắc mắc:* Tại sao trong schema collection `users` trên Firestore không có trường `password`? Cần cấu hình gì trên Firebase Console để đăng nhập/đăng ký bằng Email & Mật khẩu hoạt động?
    * *Giải pháp & Cơ sở Kiến trúc:*
      - *Về trường `password`:* Tuân thủ triệt để tiêu chuẩn bảo mật doanh nghiệp (OWASP / Google Identity Platform). Mật khẩu được bảo vệ độc quyền bên trong Firebase Authentication Service bằng thuật toán băm Modified Scrypt và salt ngẫu nhiên của Google. Database Firestore chỉ lưu trữ thông tin hồ sơ nghiệp vụ (`id`, `fullName`, `phone`, `email`, `role`, `avatarUrl`, `authProviders`, `isEmailVerified`). Tuyệt đối không lưu mật khẩu vào NoSQL database để loại bỏ 100% rủi ro lộ lọt thông tin.
      - *Về cấu hình Firebase Console:* Chỉ cần 1 thao tác duy nhất là vào **Authentication** -> **Sign-in method** -> Bật **Enable** cho **Email/Password**. Toàn bộ quy trình xác thực, tạo JWT Token, và liên kết tài khoản (Account Linking) đã được Flutter SDK (`firebase_auth`) và Cloudflare Worker OTP xử lý tự động.
12. **Cơ Chế Kiểm Tra Tính Duy Nhất Tiền Trạm (Pre-flight Uniqueness Check) & Chuẩn Hóa UX Di Động (Final Decision):**
    * *Vấn đề phát hiện:*
      - Khi đổi SĐT mà số mới đã được đăng ký cho tài khoản khác: Hệ thống âm thầm ghi log lỗi nhưng vẫn cho gửi OTP và chuyển sang màn hình nhập OTP; đến bước cuối cùng mới thất bại, gây ức chế cho người dùng.
      - Tương tự với Biển số xe máy trong Đăng ký eKYC: Nếu biển số đã tồn tại trên hệ thống, tài xế vẫn chụp CCCD 2 mặt và bằng lái, đến bước cuối nộp hồ sơ mới bị lỗi hoặc làm trùng lặp dữ liệu CSDL.
      - Thông báo lỗi qua `SnackBar` đáy màn hình bị trôi nhanh và bị che bởi nút Home vật lý / thanh điều hướng 3 nút của Android.
      - Cổng số 3 tại `WelcomeGateScreen` mang tên "Định danh eKYC" nhưng lại điều hướng sang Profile cá nhân.
    * *Giải pháp Kỹ thuật & Chuẩn hóa Hệ thống:*
      1. **Kiểm tra Duy nhất Tiền trạm (Pre-flight Validation):**
         - Thêm các hàm nghiệp vụ trong `UserService`: `isPhoneAlreadyRegistered(phone)`, `isPlateAlreadyRegistered(plate)`, `isEmailAlreadyRegistered(email)`.
         - Khi đổi SĐT: Ngay khi bấm "Tiếp tục" ở bước nhập SĐT mới, gọi truy vấn Firestore kiểm tra; nếu đã tồn tại ➔ Hiển thị Popup lỗi và chặn ngay lập tức, tuyệt đối KHÔNG gửi OTP và KHÔNG chuyển bước.
         - Khi đăng ký eKYC: Ngay tại Bước 1 (Phương tiện), kiểm tra biển số xe trên collection `drivers`; nếu đã tồn tại ➔ Chặn ngay, không bắt tài xế mất công chụp CCCD và GPLX.
      2. **Chuẩn hóa Thông báo Lỗi dạng Popup (Alert Dialog):**
         - Thay thế toàn bộ SnackBar lỗi bằng Popup Dialog nổi bật ở trung tâm màn hình, có icon cảnh báo, thông điệp rõ ràng và nút "Đã hiểu", buộc người dùng đọc và xác nhận.
      3. **Tách Giao Diện Thành Màn Hình Riêng (Dedicated Screens):**
         - Chuyển các luồng bảo mật quan trọng (Đổi số điện thoại, Liên kết Email) từ `ModalBottomSheet` chật chội sang Màn hình riêng (Full Scaffold Screen) có `AppBar`, thanh tiến trình rõ ràng và không gian gõ bàn phím số rộng rãi.
      4. **Khắc phục Lỗi Chân Trang Đè Lên Nút Home (Window Insets Fix):**
         - Cộng thêm `MediaQuery.of(context).padding.bottom` vào chân trang hoặc bao bọc trong `SafeArea(bottom: true)` để đảm bảo mọi nút bấm đều cách thanh điều hướng Android ít nhất 16dp.
      5. **Sửa Điều Hướng eKYC tại Welcome Gate & Bổ Sung Link eKYC Trong Profile:**
          - Mở thẳng `driver_ekyc_screen.dart` khi bấm vào Cổng eKYC.
          - Thêm Card đăng ký eKYC ngay trong màn hình Profile của Khách hàng.


13. **Kiến Trúc Tin Nhắn P2P & Bảo Toàn Dữ Liệu Khi Đổi Số Điện Thoại (Identity Key vs Discovery Key):**
    * *Thắc mắc:* Nếu chức năng nhắn tin P2P hoạt động dựa trên SĐT, khi người dùng đổi SĐT thì tin nhắn có bị mất hoặc gián đoạn không?
    * *Giải pháp & Thiết kế Chuẩn:*
      - **Tách biệt Định danh vĩnh viễn (Identity Key) và Cổng khám phá (Discovery Key):**
        + Trong cơ sở dữ liệu và giao thức mã hóa P2P, định danh duy nhất của người dùng là `userId` (UID từ Firebase Auth). Toàn bộ luồng chat, tin nhắn mã hóa, khóa công khai (Public Key) và lịch sử giao dịch đều gắn chặt với `userId`.
        + Số điện thoại chỉ đóng vai trò là "chìa khóa tìm kiếm" (Discovery Key / Phone Index) giúp người dùng tìm thấy nhau.
      - **Cơ chế cập nhật khi đổi SĐT:**
        + Khi người dùng cập nhật SĐT mới thành công, hệ thống chỉ cập nhật trường `phone` trong tài liệu `users/{userId}`.
        + Toàn bộ lịch sử tin nhắn, nhóm chat, hộp thư đến được bảo toàn 100% mà không bị xáo trộn hay mất mát.
        + Các liên hệ mới khi tìm kiếm bằng SĐT mới sẽ tự động trỏ về đúng `userId` này.

14. **Hoàn Thiện Bộ 3 Tính Năng & Sửa Lỗi Thực Chiến (Final Decisions & Implementations):**
    * *Vấn đề 1 (Lỗi UI khi nhập OTP đổi SĐT):*
      - *Nguyên nhân:* Lỗi nhân đôi khoảng đệm đáy (Double Bottom Inset). Scaffold đã tự động co dãn màn hình theo bàn phím (`viewInsets.bottom`), nhưng container chân trang lại cộng thêm `viewInsets.bottom` lần thứ hai, dẫn đến nút bấm bị đẩy tràn màn hình; widget OTP tạo `FocusNode` mới trong hàm `build()` gây mất focus và kẹt phím Backspace.
      - *Giải pháp:* Tối ưu `OtpPinInput` với `LayoutBuilder` tự co giãn ô nhập (`clamp(36.0, 48.0)`), bắt sự kiện Backspace qua `onKeyEvent`; loại bỏ khoảng đệm dư thừa ở chân trang `ChangePhoneScreen`.
    * *Vấn đề 2 (Thiếu tính năng Đổi mật khẩu):*
      - *Nguyên nhân:* Hệ thống đã hỗ trợ đăng nhập Email/Password nhưng chưa cung cấp giao diện đổi mật khẩu khi đã đăng nhập.
      - *Giải pháp:* Bổ sung API `UserService.changePassword({currentPassword, newPassword})` thực hiện tái xác thực an toàn qua `EmailAuthProvider.credential` trước khi gọi `updatePassword()`. Tích hợp nút và Dialog "Đổi mật khẩu" trực tiếp tại mục Email trong `UserProfileScreen` kèm đầy đủ kiểm tra định dạng và độ mạnh mật khẩu.
    * *Vấn đề 3 (Hồ sơ eKYC đang Pending vẫn cho phép đăng ký lại):*
      - *Nguyên nhân:* `DriverEkycScreen` và các điểm điều hướng (Welcome Gate, Profile) chưa kiểm tra trạng thái hồ sơ của tài xế trước khi mở Stepper 3 bước, khiến tài xế đã nộp hồ sơ vẫn có thể vào lại và nộp đè bản ghi mới.
      - *Giải pháp:* 
        + Tại `WelcomeGateScreen` và `UserProfileScreen`: Kiểm tra trước trạng thái hồ sơ qua `getDriverProfile(uid)`. Nếu đang `pendingApproval` ➔ Điều hướng thẳng tới `KycPendingScreen` kèm biển số xe; nếu đã `active` ➔ Chuyển sang `DriverDashboard`.
        + Tại `DriverEkycScreen`: Thêm Route Guard trong `initState()` tự động chuyển hướng nếu phát hiện hồ sơ đã ở trạng thái Pending hoặc Active, đồng thời chặn nộp trùng lặp tại hàm `_handleSubmitApplication`.

         - Đổi tên Card 3 tại Welcome Gate thành "Hồ Sơ & Bảo Mật Cá Nhân".
         - Mở thẳng `driver_ekyc_screen.dart` khi bấm vào Cổng eKYC.
         - Thêm Card đăng ký eKYC ngay trong màn hình Profile của Khách hàng.
