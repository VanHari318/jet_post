# KẾ HOẠCH CHI TIẾT TRIỂN KHAI PHÂN HỆ KHÁCH HÀNG (MODULE 1)

**Dự án:** JetPost - Ứng dụng Giao vận & Xe công nghệ Hợp nhất  
**Phân hệ phụ trách:** Module 1 - Khách hàng & Dịch vụ Đặt cuốc (Customer & Booking Module)  
**Thành viên chịu trách nhiệm chính:** Thành viên 1  
**Thư mục mã nguồn:** `lib/modules/customer/`  
**Tuân thủ:** Kế hoạch tổng thể [KeHoach.md](file:///d:/ChuyenDeCNTT/jet_post/KeHoach.md), Kiến trúc Hệ thống & Quyết định Kỹ thuật Đồng bộ  

---

## 1. Đánh Giá Hiện Trạng Kết Nối Hệ Thống (3 Phân Hệ Đã Xây Dựng)

Dưới góc nhìn chuyên gia hệ thống, kiến trúc nền tảng của 3 phân hệ đã hoàn thành được đánh giá như sau:

### 1.1. Phân hệ User (Module 3 - Cổng vào, Xác thực & P2P Chat)
* **Trạng thái:** Hoàn thiện 100%, chạy ổn định, không lỗi cú pháp (`flutter analyze: 0 issues`).
* **Hạ tầng cung cấp cho Customer:**
  - Cung cấp cổng vào hợp nhất [WelcomeGateScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/user/screens/welcome_gate_screen.dart) với cơ chế lưu phiên tự động (Auto-login qua `SharedPreferences`) và kiểm soát vai trò RBAC. Khi khách hàng bấm "Tôi là Khách hàng", hệ thống tự động kiểm tra phiên và gọi route `AppRoutes.customerHome`.
  - Xác thực đa kênh: Đăng nhập SMS OTP (Firebase Phone Auth tích hợp Whitelist Test Numbers miễn phí) và Email/Mật khẩu (OTP Brevo REST API qua Cloudflare Worker).
  - Quản lý Hồ sơ cá nhân: Cập nhật họ tên, đổi avatar qua Cloudinary CDN (Signed Upload với HMAC-SHA1), đổi số điện thoại bảo mật (chuẩn `updatePhoneNumber`), liên kết Email, đổi mật khẩu tài khoản.
  - Trung tâm nhắn tin trực tiếp P2P [DirectChatScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/user/screens/direct_chat_screen.dart): Khách hàng có thể mở chat 1-1 trực tiếp với tài xế đang chạy đơn hoặc liên hệ hỗ trợ Admin mà không làm gián đoạn chuyến đi.

### 1.2. Phân hệ Đối tác Tài xế (Module 2 - Vận hành & Cuốc xe)
* **Trạng thái:** Hoàn thiện 100%, chạy tốt trên thiết bị thật (`RFCX5024LRF`).
* **Điểm nối nghiệp vụ với Customer:**
  - Cơ chế quét đơn thời gian thực: `DriverDashboardScreen` và `IncomingOrderSheet` liên tục lắng nghe hai collections `rides` và `deliveries` trên Firestore ở trạng thái `pendingDriver` trong bán kính Geohash định vị.
  - Máy trạng thái chuyến đi (`DriverTripScreen`):
    - Chu trình Xe ôm: `accepted` ➔ `arriving` ➔ `inTrip` ➔ `completed`.
    - Chu trình Giao hàng: `accepted` ➔ `pickingUp` ➔ `inTransit` ➔ (Chụp ảnh bằng chứng giao hàng PoD tải lên Cloudinary `jetpost/deliveries_pod` + Xác thực mã OTP 4 số từ người nhận) ➔ `delivered` / `completed`.
  - Cập nhật vị trí GPS liên tục: Foreground Service của tài xế cập nhật `currentLat`, `currentLng`, `heading` vào tài liệu `drivers/{driverId}` trên Firestore, tạo điều kiện cho Customer hiển thị Live Tracking chuyển động mượt mà.

### 1.3. Phân hệ Quản trị Admin (Module 4 - Điều hành & Radar)
* **Trạng thái:** Hoàn thiện 100%.
* **Điểm nối nghiệp vụ với Customer:**
  - Bàn cờ Radar toàn thành phố (`AdminRadarScreen`): Giám sát vị trí toàn bộ tài xế và theo dõi lộ trình các cuốc xe đang hoạt động của khách hàng.
  - Cấu hình biểu cước linh hoạt (`AdminPricingScreen`): Cập nhật giá mở cửa (0-2km), đơn giá mỗi km tiếp theo, phụ phí giao hàng cồng kềnh, tỷ lệ chiết khấu vào tài liệu `system_settings/pricing`. Customer Service sẽ đọc bảng giá này để tính cước Upfront chuẩn xác.
  - Giải quyết khiếu nại & Đối soát PoD (`AdminDisputeScreen`): Đối chiếu ảnh chụp PoD của tài xế và mã xác thực nhận hàng khi có phản ánh từ khách hàng.
  - Kênh phát thông báo Broadcast (`AdminBroadcastScreen`): Phát thông báo bảo trì, ưu đãi cước tới toàn bộ khách hàng.

### 1.4. Khoảng Trống Kết Nối Cần Lấp Đầy (Integration Gap)
* Hiện tại, phân hệ Customer chưa có màn hình và service thực thi, khiến Driver và Admin đang phải đợi dữ liệu cuốc xe giả lập hoặc chưa có luồng tạo đơn thực tế từ phía khách hàng.
* Route `AppRoutes.customerHome` và các routes con (`rideBooking`, `deliveryBooking`, `liveTracking`, `consigneeTracking`, `customerActivity`, `savedAddresses`) đã được định nghĩa trong `AppRoutes` nhưng chưa được ánh xạ widget.
* **Mục tiêu cấp bách:** Xây dựng trọn vẹn Phân hệ Customer để tạo thành chu trình khép kín hoàn chỉnh 4 phân hệ: **Khách đặt cuốc (M1) ➔ Tài xế nhận cuốc & giao hàng PoD (M2) ➔ Admin giám sát Radar & phân xử (M4) ➔ User định danh, xác thực & Chat P2P (M3)**.

---

## 2. Kế Hoạch Chi Tiết 8 Task Phân Hệ Khách Hàng (Chuẩn Công Nghiệp)

Tuân thủ nghiêm ngặt theo đặc tả mục 3.1 của [KeHoach.md](file:///d:/ChuyenDeCNTT/jet_post/KeHoach.md):

### Task 1.1 - Màn Hình & Dịch Vụ Đặt Xe Ôm (Ride-hailing Booking)
* **Mục tiêu:** Cho phép khách hàng đặt xe máy di chuyển tức thì từ điểm A đến điểm B với giá cước Upfront cố định minh bạch.
* **Kiến trúc & Luồng thực thi:**
  1. *Xác định vị trí hiện tại:* Sử dụng `Geolocator` tự động lấy tọa độ GPS chính xác của khách hàng làm "Điểm đón mặc định", hiển thị tên đường phố qua Geocoding.
  2. *Tìm kiếm điểm đến:* Tích hợp ô tìm kiếm địa chỉ đến gọi `OpenRouteClient.searchPlaces(query)` (sử dụng Nominatim OpenStreetMap với debounce 400ms và gợi ý danh sách địa điểm tại Việt Nam). Hỗ trợ chọn nhanh từ **Danh bạ địa chỉ quen thuộc (Nhà riêng / Cơ quan)**.
  3. *Vẽ tuyến đường & Tính cước Upfront:*
     - Gọi `OpenRouteClient.getDirections(start, end)` lấy khoảng cách (km), thời gian di chuyển dự kiến (phút) và danh sách tọa độ Polyline nối giữa điểm đón và điểm trả.
     - Đọc biểu cước từ `system_settings/pricing` (giá mở cửa 2km đầu + đơn giá/km tiếp theo) để tính ra số tiền cước cố định (VNĐ), hiển thị qua `CurrencyFormatter.formatVND(price)`.
  4. *Tạo đơn & Cơ chế Hàng chờ Xe Ôm (Ride Queue - Tối đa 1 phần tử):*
     - **Quy tắc bất biến:** Mỗi khách hàng tại một thời điểm chỉ có thể duy trì **duy nhất 1 cuốc xe ôm** (`pendingDriver`, `accepted`, `arrivedPickup`, `inProgress`). Khi mở màn hình đặt xe hoặc bấm tạo đơn, hệ thống kiểm tra qua `CustomerService.getActiveRide(uid)`. Nếu đã có cuốc xe đang hoạt động, hệ thống lập tức chặn tạo đơn trùng và chuyển hướng đến màn hình chuyến đi hiện tại.
     - Khách hàng bấm **"Đặt xe ngay"** ➔ `CustomerService.createRideBooking()` khởi tạo tài liệu trong collection `rides`:
       - `status: RideStatus.pendingDriver`
       - `customerId`, `customerName`, `customerPhone` (lấy từ User hiện tại)
       - `pickupAddress`, `pickupLat`, `pickupLng`, `pickupGeohash`
       - `dropoffAddress`, `dropoffLat`, `dropoffLng`
       - `distanceKm`, `price`, `paymentMethod: 'CASH'`, `routePolyline`
     - **Trải nghiệm linh hoạt không bắt khách chờ cứng:**
       - Thay vì ép khách hàng nhìn đồng hồ đếm ngược 45s, hệ thống hiển thị Dialog thông báo cuốc xe đã vào hàng chờ.
       - Khách có thể chọn *"Ở lại theo dõi"* (tiếp tục quan sát radar đếm ngược 45s) hoặc *"Về Trang Chủ"* để thực hiện các tác vụ khác (đặt giao hàng, nhắn tin chat P2P...).
       - Trên Trang chủ (`CustomerHomeScreen`), Banner nổi bật thời gian thực sẽ hiển thị: *"Xe ôm JetBike: Đang tìm tài xế... Chạm để theo dõi"* giúp khách hàng kiểm soát chuyến đi mọi lúc. Khi tài xế nhận cuốc, banner chuyển ngay sang thông tin tài xế và tiến trình chuyến.

### Task 1.2 - Giao Diện & Dịch Vụ Tạo Đơn Giao Hàng Nhanh (Express Delivery)
* **Mục tiêu:** Tạo đơn vận chuyển bưu phẩm, tài liệu, hàng hóa kèm cơ chế bảo mật bàn giao chuẩn logistics và mô hình Bể đơn hàng (Waiting Pool) linh hoạt.
* **Kiến trúc & Luồng thực thi:**
  1. *Thông tin tuyến đường & Chi tiết địa chỉ:*
     - Điểm lấy hàng: Tọa độ GPS/địa chỉ đã chọn + ô nhập chi tiết (`pickupDetail`: Số nhà, tòa nhà, số tầng, phòng...).
     - Điểm giao hàng: Tích hợp Dual-Engine Search (Photon + Nominatim) + Quick Address Chips + ô nhập chi tiết (`dropoffDetail`: Tòa nhà, căn hộ, số phòng, chỉ dẫn giao hàng).
  2. *Thông tin người nhận & Kiểm duyệt chặt chẽ (Validation):*
     - Họ tên người nhận: Bắt buộc, tối thiểu 2 ký tự.
     - Số điện thoại người nhận: Chuẩn hóa E.164 qua `AppValidators.validatePhone`. **Ràng buộc:** Số điện thoại người nhận không được trùng với số điện thoại của người gửi (`receiverPhone != senderPhone`).
  3. *Phân loại bưu phẩm, Khối lượng & Dịch vụ gia tăng:*
     - Chọn loại hàng: **Tài liệu** | **Đồ ăn / Thức uống** | **Quần áo / Mỹ phẩm** | **Đồ điện tử** | **Hàng cồng kềnh**.
     - Khối lượng hàng hóa (`weightKg`): Bộ tăng giảm `[-] [+]` linh hoạt từ 0.5kg đến 30kg. Cước khối lượng tính theo: `weightKg * pricePerKgDelivery` (mặc định +10.000 đ/kg, Admin chỉnh sửa được trong cấu hình).
     - Tùy chọn **"Hàng dễ vỡ, xin nhẹ tay"** (`isFragile`): Tự động cộng phụ phí bảo quản an toàn (mặc định +10.000 đ, Admin chỉnh sửa được).
     - Tùy chọn **"Giao hỏa tốc ưu tiên trong 1h"** (`isExpress`): Ưu tiên điều phối tài xế nhanh nhất (mặc định +20.000 đ, Admin chỉnh sửa được).
  4. *Hình thức thanh toán & Thu hộ COD:*
     - Tiền thu hộ COD (`codAmount`): Ô nhập tiền mặt thu hộ, giới hạn hạn mức tối đa **3.000.000 đ/đơn**.
     - Người trả cước (`payer`): Cho phép chọn **Người gửi thanh toán (SENDER)** hoặc **Người nhận thanh toán khi nhận hàng (RECEIVER)**.
  5. *Công thức tính cước Upfront minh bạch:*
     $$\text{Cước giao hàng} = \text{Cước cự ly (khoảng cách)} + \text{Phụ phí khối lượng} + \text{Phụ phí dễ vỡ} + \text{Phụ phí hỏa tốc} + \text{Phụ phí loại hàng}$$
     - Cự ly $\le 2\text{km}$: `basePriceDelivery` (18.000 đ).
     - Cự ly $> 2\text{km}$: `basePriceDelivery + (distanceKm - 2) * pricePerKmDelivery` (7.000 đ/km).
     - Khối lượng: `weightKg * pricePerKgDelivery` (10.000 đ/kg).
     - Dễ vỡ: `isFragile ? fragileSurcharge (10.000 đ) : 0`.
     - Hỏa tốc: `isExpress ? expressSurcharge (20.000 đ) : 0`.
     - Tất cả các đơn giá đều được đồng bộ thời gian thực từ tài liệu `system_settings/global_config` do Admin quản trị.
  6. *Kiểm tra giới hạn cự ly (Distance Validation):* Cự ly đơn giao hàng phải từ **100m trở lên** (tránh chọn trùng điểm lấy) và **tối đa 40km** (phù hợp năng lực xe máy nội ô).
  7. *Mô hình Bể đơn hàng (Waiting Pool Architecture):*
     - Không ép khách hàng phải chờ cứng ở màn hình radar như xe ôm.
     - Sau khi bấm tạo đơn thành công, đơn hàng được đẩy lên collection `deliveries` với trạng thái `pendingDriver` (+1 vào danh sách chờ).
     - Hộp thoại thành công cung cấp 2 lựa chọn:
       - **"Tạo Đơn Khác":** Tự động reset form người nhận/giao để khách tiếp tục tạo đơn tiếp theo (rất tiện lợi cho các chủ shop, người gửi nhiều đơn trong ngày).
       - **"Xem Danh Sách":** Chuyển ngay sang tab **"Hoạt động" ➔ "Đang diễn ra"** (`CustomerActivityScreen`) để theo dõi tất cả các đơn hàng đang chờ tiếp nhận hoặc đang giao.
  8. *Quy trình Bàn giao Hàng hóa & Vai trò Sống còn của Mã OTP:*
     - Khi tạo đơn: Hệ thống sinh ngẫu nhiên **Mã OTP 4 số bí mật** (`handoverOtp`). Mã này lưu tại `deliveries/{id}` và **chỉ hiển thị ở phía Người Nhận** (trên tab "Đơn nhận" / `ConsigneeTrackingScreen` hoặc qua SMS chia sẻ từ Người gửi).
     - Khi tài xế đến điểm giao (Dropoff):
       1. Tài xế bấm "Đã đến nơi giao" và liên hệ người nhận.
       2. Người nhận ra kiểm tra kiện hàng.
       3. Tài xế dùng ứng dụng mở máy ảnh chụp ảnh gói hàng thực tế (Proof of Delivery - PoD) tải lên Cloudinary (`jetpost/deliveries_pod`).
       4. Tài xế yêu cầu người nhận đọc mã OTP 4 số và nhập vào app (`DriverTripScreen`).
       5. Hệ thống xác thực mã khớp ➔ chuyển trạng thái `completed`.
     - **Vai trò của mã OTP:**
       - **Bằng chứng giao hàng không thể chối bỏ (Non-repudiation):** Người nhận không thể nói "Chưa nhận được hàng" vì chỉ người nhận mới có mã OTP để đọc cho tài xế.
       - **Chống gian lận tài xế (Anti-fraud):** Tài xế không thể tự ý bấm "Đã hoàn thành" hoặc đánh tráo gói hàng từ xa.
       - **Xác thực danh tính (Identity Verification):** Đảm bảo giao đúng người được ủy quyền, tránh thất thoát tại chung cư, sảnh tòa nhà.
       - **Căn cứ đối soát cho Admin (`AdminDisputeScreen`):** Khi phát sinh khiếu nại, sự kết hợp giữa ảnh chụp PoD và xác thực mã OTP là bằng chứng pháp lý minh bạch 100%.

### Task 1.3 - Theo Dõi Hành Trình Thời Gian Thực (Live Real-time Tracking)
* **Mục tiêu:** Tái hiện toàn bộ chuyển động của tài xế và tiến trình chuyến đi trên bản đồ sống động.
* **Kiến trúc & Luồng thực thi:**
  1. *Lắng nghe cuốc xe:* Khởi tạo Firestore Stream theo dõi tài liệu cuốc xe `rides/{rideId}` hoặc `deliveries/{deliveryId}`.
  2. *Phát hiện tài xế nhận cuốc:* Khi `status == accepted`, màn hình chuyển ngay sang chế độ Live Tracking:
     - Lấy `driverId`, truy vấn thông tin tài xế từ `drivers/{driverId}` (ảnh avatar, tên, biển số xe, loại xe, số sao uy tín).
     - Cung cấp nút **"Gọi điện"** (sử dụng giao thức `tel:`, áp dụng che số riêng tư) và nút **"Nhắn tin P2P"** (mở thẳng `DirectChatScreen` qua `AppRoutes.directChat`).
  3. *Bản đồ di chuyển mượt mà:*
     - Lắng nghe stream tọa độ tài xế (`currentLat`, `currentLng`, `heading`) từ `drivers/{driverId}`.
     - Cập nhật Marker biểu tượng xe máy trên bản đồ xoay theo đúng góc hướng di chuyển (`heading`).
     - Vẽ tuyến đường Polyline chỉ dẫn từ vị trí tài xế đến điểm đón / điểm giao.
  4. *Tiến trình trực quan (Trip Stepper):* Hiển thị thanh tiến trình 4 giai đoạn tương ứng với trạng thái thực tế:
     - Với Xe ôm: *Tài xế đang đến ➔ Đã đến điểm đón ➔ Đang chở bạn ➔ Đã đến đích*.
     - Với Giao hàng: *Tài xế đang đến lấy hàng ➔ Đã lấy hàng ➔ Đang giao đến người nhận ➔ Giao hàng thành công*.

### Task 1.4 - Tra Cứu Đơn Bưu Kiện Gửi Cho Tôi (Consignee Tracking Tab)
* **Mục tiêu:** Cung cấp trải nghiệm nhận hàng chuyên nghiệp, bảo mật cho người nhận mà không cần tài xế phải gọi điện làm phiền nhiều lần.
* **Kiến trúc & Luồng thực thi:**
  1. *Truy vấn đơn tự động:* Truy vấn Firestore collection `deliveries` với điều kiện `where('receiverPhone', isEqualTo: currentUser.phone)`.
  2. *Hiển thị danh sách bưu kiện đang giao đến:*
     - Tên người gửi, loại hàng hóa, địa chỉ lấy và địa chỉ giao.
     - Huy hiệu trạng thái giao hàng rõ ràng.
  3. *Hiển thị Mã OTP Nhận Hàng (4 số):*
     - Khi đơn chuyển sang trạng thái `inTransit` (Đang giao), giao diện hiển thị hộp số to nổi bật chứa **Mã OTP 4 số** (VD: `8392`) kèm hướng dẫn: *"Đọc mã này cho tài xế JetPost khi nhận hàng để xác thực bàn giao thành công"*.

### Task 1.5 - Hoàn Tất Chuyến, Đối Soát PoD & Đánh Giá Dịch Vụ
* **Mục tiêu:** Đối soát minh bạch chi phí, bằng chứng giao nhận và thu thập phản hồi khách hàng để duy trì chất lượng dịch vụ.
* **Kiến trúc & Luồng thực thi:**
  1. *Tự động kích hoạt khi hoàn thành:* Khi nhận tín hiệu `status == completed` hoặc `status == delivered`:
     - Tự động hiển thị Hóa đơn thanh toán tiền mặt với số tiền cước chuẩn xác.
  2. *Đối soát bằng chứng giao hàng (PoD Review):*
     - Với đơn giao hàng: Hiển thị ảnh chụp Proof of Delivery do tài xế tải lên Cloudinary (`jetpost/deliveries_pod`), hỗ trợ bấm xem ảnh phóng to toàn màn hình.
  3. *Đánh giá sao & Tag nhận xét:*
     - Chọn số sao (1 đến 5 sao).
     - Bộ thẻ đánh giá nhanh: *"Lái xe cẩn thận"*, *"Thân thiện & Lịch sự"*, *"Đúng giờ"*, *"Giao hàng an toàn"*, *"Xe sạch sẽ"*.
     - Ô nhập nhận xét chi tiết ➔ Bấm **"Gửi đánh giá"** ➔ Cập nhật trường `rating` và `reviewComment` vào tài liệu cuốc xe, đồng thời tính lại điểm trung bình sao cho tài xế trong collection `drivers`.

### Task 1.6 - Xử Lý Hủy Chuyến & Ngoại Lệ
* **Mục tiêu:** Xử lý linh hoạt, công bằng khi khách đổi ý hoặc khi không có tài xế quanh khu vực.
* **Kiến trúc & Luồng thực thi:**
  1. *Khách hàng chủ động hủy chuyến:*
     - Khi cuốc đang ở trạng thái `pendingDriver` hoặc `accepted` (chưa bắt đầu chở/lấy hàng): Khách bấm nút "Hủy chuyến".
     - Hiển thị Dialog chọn lý do hủy: *"Thay đổi kế hoạch"*, *"Thời gian chờ quá lâu"*, *"Đặt nhầm địa chỉ"*, *"Lý do khác"*.
     - Cập nhật trạng thái `cancelled`, `cancelledBy: 'customer'`, thông báo popup xác nhận và hoàn tất đóng luồng.
  2. *Timeout không tìm thấy tài xế (Hết 45s):*
     - Nếu đồng hồ 45 giây đếm ngược về 0 mà chưa có tài xế nào bấm nhận: Hệ thống tạm dừng quét, hiển thị hộp thoại thông báo: *"Rất tiếc, hiện tại các tài xế quanh khu vực đều đang bận"*.
     - Cung cấp 2 lựa chọn rõ ràng:
       - 🔄 **"Tìm kiếm lại"**: Reset đồng hồ 45s và tiếp tục quét.
       - ❌ **"Hủy yêu cầu"**: Cập nhật trạng thái đơn thành `cancelled`, `cancelledBy: 'system'`.

### Task 1.7 - Quản Lý Danh Bạ Địa Chỉ Quen Thuộc (Saved Addresses)
* **Mục tiêu:** Tăng tốc độ đặt xe và gửi hàng 1 chạm, mang lại tiện ích vượt trội cho người dùng.
* **Kiến trúc & Luồng thực thi:**
  1. *Lưu trữ sub-collection:* Dữ liệu lưu tại `users/{userId}/saved_addresses/{addrId}` theo cấu trúc của [SavedAddressModel](file:///d:/ChuyenDeCNTT/jet_post/lib/models/saved_address_model.dart).
  2. *Phân loại nhãn trực quan:*
     - 🏠 **Nhà riêng (Home)**
     - 🏢 **Cơ quan (Work)**
     - 📍 **Địa chỉ khác (Other)**
  3. *Quản lý:* Thêm mới, chỉnh sửa tên địa chỉ, chọn vị trí trên bản đồ, xóa địa chỉ.
  4. *Tích hợp 1 chạm tại Màn hình Đặt xe / Giao hàng:*
     - Hiển thị thanh Quick Action Chips ở đầu màn hình. Khách hàng chỉ cần bấm 1 chạm là hệ thống tự điền tọa độ và tên đường vào ô Điểm đến hoặc Điểm đón, tự động vẽ đường và tính giá cước ngay lập tức.

### Task 1.8 - Trung Tâm Hoạt Động, Lịch Sử Cuốc Xe & Đặt Lại (Re-order)
* **Mục tiêu:** Cung cấp nhật ký hoạt động đầy đủ, cho phép tra cứu, đánh giá bù và đặt lại đơn hàng quen thuộc siêu tốc.
* **Kiến trúc & Luồng thực thi:**
  1. *Phân chia 2 Tab khoa học:*
     - 🟡 **Đang diễn ra:** Các cuốc đang quét tìm xe, tài xế đang đến, bưu phẩm đang giao.
     - 🟢 **Lịch sử:** Toàn bộ các chuyến đã hoàn tất hoặc đã hủy theo thứ tự thời gian mới nhất.
  2. *Thẻ tóm tắt chuyến đi (Order Summary Card):* Icon phân biệt Xe ôm / Giao hàng, ngày giờ, lộ trình điểm đón - điểm trả, số tiền cước, huy hiệu trạng thái.
  3. *Màn hình Chi tiết Đơn hàng (Order Detail Screen):*
     - Bản đồ thu nhỏ tái hiện tuyến đường đã đi.
     - Thông tin tài xế phục vụ.
     - Ảnh chụp PoD bàn giao gói hàng.
     - Khung Đánh giá: Nếu khách chưa đánh giá lúc kết thúc chuyến, hiển thị nút **"Đánh giá ngay"** để chấm điểm bổ sung.
  4. *Tính năng Đặt lại (Re-order 1 chạm):* Khách bấm nút **"Đặt lại chuyến này"** ➔ Tự động mở màn hình Đặt xe / Giao hàng với các thông số điểm đón, điểm trả đã được điền sẵn.

---

## 3. Tiêu Chuẩn Thiết Kế UI/UX Đồng Bộ Hoàn Hảo Với Phân Hệ Driver

Để ứng dụng JetPost đạt chuẩn mực công nghiệp và mang lại cảm giác nhất quán giữa 2 phía (Khách hàng và Tài xế), phân hệ Customer áp dụng bộ nguyên tắc thiết kế sau:

### 3.1. Bảng Màu & Ngôn Ngữ Nhận Diện (Brand Identity)
* **Màu sắc chủ đạo (Primary):** `AppColors.primary` (`#00A86B` - Xanh ngọc lục bảo) làm tone màu nhận diện xuyên suốt cho các nút bấm hành động chính, tab đặt xe JetBike, biểu tượng định vị điểm đón và appbar.
* **Màu dịch vụ hỏa tốc (Secondary):** `AppColors.secondary` (`#FF6B00` - Cam rực rỡ) dành riêng cho dịch vụ Giao hàng hỏa tốc JetExpress, nút theo dõi đơn bưu phẩm và cảnh báo quan trọng.
* **Tương thích hoàn hảo Dark / Light Mode:**
  - Hỗ trợ đầy đủ bộ màu nền `AppColors.backgroundLight` / `AppColors.backgroundDark`, thẻ `AppColors.cardLight` / `AppColors.cardDark`.
  - Tự động thay đổi màu chữ `textPrimaryLight` / `textPrimaryDark` sắc nét, không bị chìm nền khi đổi chế độ sáng/tối trong App Settings.

### 3.2. Bản Đồ Trực Quan Mượt Mà (OpenStreetMap + FlutterMap)
* Sử dụng chung thư viện `flutter_map` và CartoDB Tile Layer chuẩn xác như Driver Dashboard.
* **Bộ Marker trực quan đồng bộ:**
  - Điểm đón (Pickup): Pin xanh lá viền trắng nổi bật kèm biểu tượng người đứng đón.
  - Điểm đến (Dropoff): Pin đỏ cam viền trắng kèm biểu tượng cờ đích.
  - Xe máy tài xế: Icon xe máy màu xanh lá chuyển động xoay theo góc `heading`, hiển thị mượt mà trên nền bản đồ.
  - Tuyến đường di chuyển: Đường Polyline màu xanh dương `AppColors.routePolyline` (`#0070BA`) dày 5dp bo tròn 2 đầu nét vẽ.

### 3.3. Cấu Trúc Khung Nhìn Tránh Lỗi Kỹ Thuật (Anti-Glitch Architecture)
Rút kinh nghiệm sâu sắc từ quá trình kiểm thử thiết bị thật ở các phân hệ trước:
1. **Khắc phục triệt để lỗi Double Bottom Inset:** Tuyệt đối không cộng thủ công `viewInsets.bottom` vào chân trang khi Scaffold đã có `resizeToAvoidBottomInset: true`.
2. **Bảo vệ Vùng An Toàn Phím Home (Safe Area Padding):** Mọi container điều khiển ở đáy màn hình đều được bao bọc bởi `SafeArea(bottom: true)` hoặc cộng khoảng đệm `MediaQuery.of(context).padding.bottom + 14` để đảm bảo nút bấm không bao giờ bị thanh điều hướng ảo 3 nút của Android che khuất.
3. **Chuẩn hóa Thông Báo Lỗi Qua Popup (Alert Dialog):** Thay thế toàn bộ SnackBar bằng `AppDialogs.showError`, `AppDialogs.showSuccess` và `AppDialogs.showConfirm` hiển thị ở trung tâm màn hình, có icon phân loại rõ ràng và nút bấm xác nhận bắt buộc.
4. **Hệ Thống Ghi Log Đồng Bộ:** Sử dụng `AppLogger.userAction`, `AppLogger.navigation`, `AppLogger.error` để dễ dàng theo dõi luồng tương tác của khách trên Terminal.

---

## 4. Cấu Trúc Thư Mục & Phân Tách Trách Nhiệm (Clean Architecture)

```
lib/modules/customer/
├── KeHoachCustomer.md              # Kế hoạch chi tiết & Tài liệu kiến trúc phân hệ
├── services/
│   └── customer_service.dart       # Xử lý CSDL Firestore (Rides, Deliveries, SavedAddresses, Pricing)
├── screens/
│   ├── customer_home_screen.dart   # Màn hình chính Khách hàng (Bản đồ OSM, BottomNav 3 tab)
│   ├── ride_booking_screen.dart    # Task 1.1: Đặt xe ôm JetBike & Radar quét tài xế 45s
│   ├── delivery_booking_screen.dart# Task 1.2: Tạo đơn bưu phẩm JetExpress & OTP bàn giao
│   ├── live_tracking_screen.dart   # Task 1.3: Theo dõi thời gian thực xe tài xế & Trip Stepper
│   ├── consignee_tracking_screen.dart # Task 1.4: Tab tra cứu bưu kiện gửi cho tôi & Mã OTP nhận hàng
│   ├── customer_activity_screen.dart  # Task 1.8: Hoạt động & Lịch sử cuốc xe
│   ├── order_detail_screen.dart    # Task 1.5 & 1.8: Chi tiết đơn hàng, đối soát PoD, đánh giá bù & Re-order
│   └── saved_addresses_screen.dart # Task 1.7: Quản lý danh bạ địa chỉ quen thuộc
└── widgets/
    ├── booking_bottom_sheet.dart   # BottomSheet chọn điểm đón/trả, xem giá cước & nút đặt
    ├── service_selection_card.dart # Thẻ chọn JetBike vs JetExpress
    ├── quick_address_chips.dart    # Chip bấm nhanh Nhà riêng / Cơ quan
    ├── live_trip_stepper.dart      # Thanh tiến trình chu trình cuốc xe đồng bộ Driver
    ├── driver_contact_card.dart    # Thẻ thông tin tài xế, biển số, nút gọi & nút chat P2P
    ├── trip_rating_dialog.dart     # Popup hóa đơn tiền mặt, đối soát ảnh PoD & chấm 1-5 sao
    └── order_history_card.dart     # Thẻ hiển thị tóm tắt đơn hàng trong tab Lịch sử
```

---

## 5. Lộ Trình Triển Khai Thực Hiện Chuẩn Chỉ

* **Bước 1: Xây dựng Tầng Dịch vụ Dữ liệu (`CustomerService`):**
  - Đọc cấu hình bảng giá từ `system_settings/pricing`.
  - Hàm tạo cuốc `createRideBooking()`, hàm tạo đơn `createDeliveryBooking()`.
  - Hàm cập nhật trạng thái hủy cuốc `cancelRide()`, `cancelDelivery()`.
  - Stream theo dõi cuốc xe `streamRide()`, stream theo dõi đơn hàng `streamDelivery()`.
  - Stream danh sách đơn nhận `streamConsigneeDeliveries()`.
  - Stream lịch sử hoạt động `streamCustomerRides()`, `streamCustomerDeliveries()`.
  - Quản lý địa chỉ đã lưu `getSavedAddresses()`, `addSavedAddress()`, `deleteSavedAddress()`.
  - Đánh giá cuốc xe `rateRide()`, `rateDelivery()`.

* **Bước 2: Xây dựng Màn hình Chính Khách Hàng (`CustomerHomeScreen`):**
  - Tích hợp BottomNavigationBar 3 tab (Trang chủ / Hoạt động / Đơn nhận).
  - Bản đồ nền OSM hiển thị vị trí hiện tại của khách hàng.
  - Các thẻ chọn nhanh dịch vụ JetBike / JetExpress và Quick Address Chips.
  - Tích hợp Drawer menu hoặc Top Bar dẫn đến Hồ sơ cá nhân, Cài đặt ứng dụng, Hộp thư chat P2P.

* **Bước 3: Hoàn thiện Màn hình Đặt Xe Ôm (`RideBookingScreen`) & Radar 45s:**
  - Tìm kiếm điểm đến (Nominatim), vẽ polyline (OpenRouteService), tính cước Upfront.
  - Radar đếm ngược 45s quét tài xế lân cận.
  - Chuyển tiếp tự động sang Live Tracking ngay khi tài xế bấm nhận.

* **Bước 4: Hoàn thiện Màn hình Giao Hàng (`DeliveryBookingScreen`):**
  - Form nhập người nhận, loại bưu kiện, phụ phí, tự sinh mã OTP 4 số.
  - Nút chia sẻ mã đơn hàng qua SMS / Zalo.

* **Bước 5: Hoàn thiện Màn hình Theo Dõi Trực Tuyến (`LiveTrackingScreen`) & Đối Soát PoD:**
  - Lắng nghe tọa độ GPS tài xế, marker xe di chuyển mượt mà.
  - Trip Stepper hiển thị tiến trình. Thẻ liên lạc tài xế (Gọi / Chat P2P).
  - Dialog hoàn thành cuốc: Xem hóa đơn tiền mặt, ảnh PoD và chấm sao đánh giá.

* **Bước 6: Hoàn thiện Tab Tra Cứu Đơn Nhận (`ConsigneeTrackingScreen`):**
  - Hiển thị hộp số OTP 4 số to rõ nét cho người nhận đọc cho tài xế.

* **Bước 7: Hoàn thiện Hoạt Động & Lịch Sử (`CustomerActivityScreen`, `OrderDetailScreen`, `SavedAddressesScreen`):**
  - Danh bạ địa chỉ quen thuộc (Nhà / Cơ quan).
  - Xem lại chi tiết đơn, đánh giá bù và nút đặt lại chuyến (Re-order).

* **Bước 8: Ghép Nối Routes & Kiểm Thử Toàn Diện 4 Phân Hệ:**
  - Đăng ký các routes vào [AppRoutes](file:///d:/ChuyenDeCNTT/jet_post/lib/routes/app_routes.dart).
  - Liên kết nút "Tôi là Khách hàng" trong `WelcomeGateScreen`.
  - Chạy `flutter analyze` đảm bảo 0 cảnh báo, 0 lỗi.
  - Kiểm thử kịch bản liên thông trên thiết bị thật: Khách đặt đơn ➔ Tài xế nhận cuốc & giao hàng PoD ➔ Admin giám sát radar ➔ Hoàn tất đối soát.


---

## 6. Hiện Trạng Triển Khai Thực Tế & Kết Quả Đã Hoàn Thành (Implementation Log)

Toàn bộ 8 task nghiệp vụ và bộ widgets giao diện chuẩn công nghiệp đã được lập trình hoàn tất, đồng bộ 100% với phân hệ Driver và hệ sinh thái JetPost:

1. **Tầng Dịch Vụ Nghiệp Vụ (`CustomerService`):**
   - Đặt tại [customer_service.dart](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/services/customer_service.dart).
   - Đọc bảng giá Upfront từ `system_settings/pricing` (có cơ chế cache tối ưu).
   - Tạo cuốc xe `createRideBooking()`, tạo đơn hàng `createDeliveryBooking()` kèm tự động sinh mã OTP 4 số bàn giao an toàn.
   - Quản lý Stream thời gian thực cuốc xe, tài xế, đơn nhận của tôi, lịch sử hoạt động và danh bạ địa chỉ quen thuộc.
   - Giao dịch đối soát đánh giá sao tài xế qua `rateRide()` và `rateDelivery()`.

2. **Hệ Thống Giao Diện Màn Hình (Screens):**
   - [CustomerHomeScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/customer_home_screen.dart): Màn hình chính 3 tab (Trang chủ, Hoạt động, Đơn nhận), bản đồ OSM nền, thẻ tìm kiếm nhanh, Quick Chips địa chỉ, banner chuyến đi đang diễn ra.
   - [RideBookingScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/ride_booking_screen.dart) (Task 1.1): Bản đồ OSM, Geocoding Nominatim, vẽ Polyline OpenRouteService, tính cước Upfront cố định & Radar quét tài xế đếm ngược 45s.
   - [DeliveryBookingScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/delivery_booking_screen.dart) (Task 1.2): Tạo đơn bưu phẩm JetExpress, phân loại hàng + phụ phí, sinh mã OTP 4 số và nút chia sẻ hành trình qua SMS/Zalo.
   - [LiveTrackingScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/live_tracking_screen.dart) (Task 1.3 & 1.5): Lắng nghe tọa độ GPS tài xế, icon xe máy xoay theo góc `heading`, hiển thị `LiveTripStepper`, `DriverContactCard` (Gọi / Chat P2P), hiển thị mã OTP và tự động kích hoạt `TripRatingDialog` khi hoàn tất.
   - [ConsigneeTrackingScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/consignee_tracking_screen.dart) (Task 1.4): Tra cứu bưu phẩm gửi cho tôi theo SĐT, hiển thị hộp số Mã OTP Nhận Hàng 4 số to rõ nét để đọc cho tài xế khi nhận hàng.
   - [CustomerActivityScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/customer_activity_screen.dart) (Task 1.8): Phân chia 2 tab "Đang diễn ra" và "Lịch sử chuyến đi", hỗ trợ chấm điểm đánh giá bù.
   - [OrderDetailScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/order_detail_screen.dart) (Task 1.5 & 1.8): Bản đồ thu nhỏ lộ trình, thông tin tài xế, xem ảnh PoD phóng to và tính năng **"Đặt lại chuyến này (Re-order)"** 1 chạm.
   - [SavedAddressesScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/screens/saved_addresses_screen.dart) (Task 1.7): Quản lý danh bạ địa chỉ quen thuộc (Nhà riêng / Cơ quan).

3. **Bộ Widget Đồng Bộ Với Driver:**
   - [LiveTripStepper](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/live_trip_stepper.dart): Stepper 4 bước hiển thị tiến trình chu trình cuốc xe khớp với DriverTripScreen.
   - [DriverContactCard](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/driver_contact_card.dart): Card nhận diện tài xế, biển số xe, số sao, nút Gọi điện ẩn danh và nút Nhắn tin P2P.
   - [TripRatingDialog](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/trip_rating_dialog.dart): Hộp thoại thanh toán tiền mặt, xem ảnh PoD bàn giao và chấm điểm 1-5 sao.
   - [QuickAddressChips](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/quick_address_chips.dart): Thanh phím chọn nhanh Nhà riêng / Cơ quan.
   - [ServiceSelectionCard](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/service_selection_card.dart): Thẻ lựa chọn JetBike vs JetExpress.
   - [OrderHistoryCard](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/customer/widgets/order_history_card.dart): Thẻ tóm tắt cuốc xe trong lịch sử.

4. **Đồng Bộ Điều Hướng Toàn Hệ Thống:**
   - Toàn bộ routes của Customer đã được đăng ký vào [AppRoutes](file:///d:/ChuyenDeCNTT/jet_post/lib/routes/app_routes.dart).
   - Nút "Tôi là Khách hàng" trong [WelcomeGateScreen](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/user/screens/welcome_gate_screen.dart) kết nối trực tiếp vào `CustomerHomeScreen`.

5. **Khắc Phục Lỗi Biên Dịch Thực Chiến (Compiler Bug Fixes):**
   - *Lỗi thiếu method `getUserProfile(uid)` trong `UserService`:* Đã bổ sung chính thức phương thức `getUserProfile(String uid)` vào [UserService](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/user/services/user_service.dart), cho phép truy vấn trực tiếp hồ sơ người dùng từ Firestore `users/{uid}` theo chuẩn nghiệp vụ.
   - *Lỗi cú pháp widget `BoxBoxConstraints`:* Đã chuẩn hóa về `BoxConstraints` trong danh sách kết quả tìm kiếm địa điểm tại `RideBookingScreen`, `DeliveryBookingScreen` và `SavedAddressesScreen`.
   - *Lỗi bản đồ hiển thị 'API KEY REQUIRED carto.com/basemaps/apikey':*
     + *Nguyên nhân:* Phân hệ Customer ban đầu trỏ vào máy chủ thương mại `cartocdn.com` (yêu cầu đăng ký tài khoản và API Key trả phí), trong khi Phân hệ Driver trỏ vào máy chủ cộng đồng phi lợi nhuận chính thức của OpenStreetMap (`tile.openstreetmap.org` và `tile.openstreetmap.de` - 100% miễn phí vĩnh viễn không cần API Key).
     + *Giải pháp:* Đã đồng bộ 100% cấu hình `TileLayer` của Customer sang máy chủ OpenStreetMap chính thức tại cả 4 màn hình (`CustomerHomeScreen`, `RideBookingScreen`, `LiveTrackingScreen`, `OrderDetailScreen`), loại bỏ hoàn toàn watermark và mở bản đồ tức thì.


    - *Lỗi bản đồ xám, không tìm được đường & cự ly hiển thị 0.0 km • 0 phút:*
      + *Nguyên nhân gốc rễ:*
        1. Người dùng khi lưu địa chỉ bằng nút "Lấy vị trí GPS hiện tại" đã lưu tọa độ của chính thiết bị thử nghiệm (`20.9094, 105.8851`). Khi vào màn hình đặt xe, điểm đón mặc định lấy GPS hiện tại và người dùng bấm chọn địa chỉ đã lưu này làm điểm đến ➔ Điểm đón và Điểm đến trùng nhau.
        2. Khi 2 điểm trùng tọa độ, OpenRouteService trả về lỗi/cự ly 0 ➔ Thuật toán Fallback trả về `distanceKm = 0.0`, thời gian 0 phút, cước tối thiểu 15.000đ và polyline nối thẳng 2 điểm.
        3. Hàm `_fitMapBounds` gọi khung bao trên 2 điểm trùng nhau khiến camera phóng cực đại vượt ngưỡng (`zoom >= 19`). Tại zoom 19, máy chủ OpenStreetMap không có sẵn tile dựng sẵn cho nhiều khu vực tại Việt Nam và trả về HTTP 404, làm bản đồ rơi vào màn hình xám trơn.
      + *Giải pháp triệt để đã triển khai:*
        1. **Kiểm tra va chạm tọa độ (Coordinate Guard):** Bổ sung hàm kiểm tra `GeoCalculator.distanceInMeters()`. Nếu điểm đến trùng hoặc cách điểm đón dưới 50m, hệ thống lập tức hiển thị cảnh báo yêu cầu người dùng chọn địa điểm khác, ngăn chặn việc đặt chuyến đi tại chỗ.
        2. **Giới hạn thu phóng bản đồ (`maxZoom: 16.5`):** Trong `_fitMapBounds`, đặt trần thu phóng tối đa 16.5 và nếu cự ly < 100m chỉ di chuyển tâm camera tới điểm đón ở zoom 15.5, tuyệt đối không để camera vượt ngưỡng 18 gây lỗi mất tile OSM.
        3. **Nâng cấp Hệ thống Định tuyến 3 Cấp độ (3-Tier Routing Engine) trong `OpenRouteClient`:**
           - *Cấp 1:* OSRM Public Driving Engine (`router.project-osrm.org`) - Tính đường đi uốn lượn chính xác theo mạng lưới giao thông thực tế của OpenStreetMap, miễn phí 100%, không cần API key.
           - *Cấp 2:* OpenRouteService Directions API (`api.openrouteservice.org`) làm dự phòng trực tuyến.
           - *Cấp 3:* Thuật toán Haversine kết hợp hệ số uốn khúc đường bộ 1.35x làm dự phòng ngoại tuyến.

    - *Hệ thống Gợi ý Địa điểm (Autocomplete Suggestions) Chuẩn Google Maps & Grab:*
      + *Cơ chế hoạt động:*
        1. **Debounce 400ms:** Chống spam request lên server Nominatim khi người dùng gõ phím, loại bỏ hoàn toàn hiện tượng bị giới hạn tốc độ (HTTP 429).
        2. **Danh mục Địa danh Phổ biến tức thì (Instant Popular Hubs):** Tích hợp sẵn bộ địa danh nổi tiếng (ĐH Thủy Lợi, ĐH Bách Khoa, BV Bạch Mai, Vincom Royal City, BV 108, Hồ Gươm, Bến xe Mỹ Đình, Bến xe Giáp Bát, Sân bay Nội Bài,...). Ngay khi người dùng chạm vào ô tìm kiếm (focus), danh sách này hiển thị ngay lập tức với độ trễ 0ms.
        3. **Bộ lọc không dấu Tiếng Việt:** Hỗ trợ tìm kiếm nhanh không cần gõ dấu ("thuy loi", "bach khoa", "royal", "noi bai").
        4. **Nhận diện tự động Tọa độ GPS:** Tự động bắt chuỗi Regex dạng "20.9094, 105.8851" để định vị ngay điểm đến mà không cần gọi mạng.
        5. **Giao diện Gợi ý Google Maps Style:** Mỗi mục gợi ý gồm icon nhận diện theo danh mục (Trường học, Bệnh viện, TTTM, Bến xe, Sân bay, Thắng cảnh), tên địa danh in đậm, địa chỉ chi tiết màu xám và huy hiệu cự ly tính theo thời gian thực từ vị trí đón của khách (VD: `2.4 km`).
        6. **Dịch ngược tọa độ (Reverse Geocoding):** Khi người dùng bấm "Lấy vị trí GPS hiện tại" tại màn hình Quản lý Địa chỉ đã lưu, hệ thống tự động dịch ngược tọa độ thành tên đường phố thực tế thay vì chỉ lưu chuỗi tọa độ thô.

    - *Lỗi biên dịch 'Undefined name GeoCalculator':*
      + *Nguyên nhân:* Tại `ride_booking_screen.dart` và `delivery_booking_screen.dart` có sử dụng `GeoCalculator.distanceInMeters()` và `GeoCalculator.distanceInKm()` nhưng trước đó thiếu dòng `import '../../../core/utils/geo_calculator.dart';`, khiến tiến trình Gradle `compileFlutterBuildDebug` dừng với exit value 1.
      + *Giải pháp:* Đã bổ sung import `GeoCalculator` đầy đủ vào cả 2 màn hình, đưa mã nguồn về trạng thái biên dịch sạch 100%.

    - *Lỗi biên dịch 'Member not found: AppDialogs.showWarning':*
      + *Nguyên nhân:* Tiện ích `AppDialogs` ban đầu chỉ có `showError`, `showSuccess` và `showConfirm`, chưa có `showWarning` với biểu tượng màu cam cảnh báo chuyên dụng.
      + *Giải pháp:* Đã bổ sung chính thức phương thức `showWarning(BuildContext context, {String title, required String message, ...})` vào [AppDialogs](file:///d:/ChuyenDeCNTT/jet_post/lib/core/utils/app_dialogs.dart), hỗ trợ hiển thị popup cảnh báo đồng bộ trên toàn ứng dụng.

    - *Nâng Cấp Đột Phá Bộ Máy Tìm Kiếm Đa Tầng (Dual-Engine Geocoding with Proximity Biasing):*
      + *Vấn đề thực tế:* Người dùng gõ tên địa điểm thực tế (VD: *"bệnh viện bưu điện"*), trên bản đồ có hiển thị cơ sở 2 tại Phố Huế nhưng ô tìm kiếm không ra kết quả do Nominatim đối sánh từ khóa khắt khe, thiếu tìm kiếm mờ (Fuzzy search), thiếu định vị theo bán kính người dùng và timeout mạng quá ngắn (4s).
      + *Giải pháp hoàn thiện đã triển khai:*
        1. **Định vị Bán kính Lân cận (Proximity Biasing):** Truyền tọa độ GPS khách hàng (`userLat`, `userLng`) vào truy vấn Nominatim với tham số `viewbox` (bán kính ~35km quanh người dùng) + `bounded=0` và `accept-language=vi`, ưu tiên đẩy các kết quả ở cùng quận/thành phố lên đầu.
        2. **Động cơ Kép Kết Hợp Photon OSM:** Tích hợp Photon Geocoding API (`photon.komoot.io`) chạy trên nền Elasticsearch n-gram chuyên biệt cho OpenStreetMap. Hỗ trợ tìm kiếm mờ cực nhạy cho từ viết tắt, tiếng Việt không dấu và lỗi chính tả.
        3. **Nâng Cấp Phản Hồi Giao Diện (UX States):** Bổ sung trạng thái xoay Loading *"Đang tìm kiếm quanh bạn..."* khi đang gọi API, và trạng thái Empty State thông minh khi không có kết quả kèm gợi ý trực quan.
        4. **Tính Năng Chạm Điểm Trên Bản Đồ (Map Tap Pinning):** Cho phép người dùng chạm trực tiếp vào bất kỳ vị trí nào trên bản đồ (như tòa nhà bệnh viện, ngõ nhỏ) để tự động dịch ngược tọa độ (Reverse Geocode), cắm cờ điểm đến và vẽ tuyến đường ngay tức khắc.

    - *Lỗi tràn khung hiển thị (Overflow by 3.1 pixels) tại Admin Dashboard:*
      + *Nguyên nhân:* Tại `AdminDashboardScreen`, khối 4 thẻ KPI tổng quan 7 ngày qua sử dụng `GridView.count` với tỷ lệ `childAspectRatio: 1.3`. Khi kết hợp nội dung thẻ `AdminStatCard` (gồm icon, giá trị số lớn, tiêu đề và phụ đề), chiều cao thẻ bị bó hẹp ở mức ~121px trong khi chiều cao tối thiểu cần thiết là ~125px, gây ra vạch vàng đen lỗi tràn viền `BOTTOM OVERFLOWED BY 3.1 PIXELS`.
      + *Giải pháp:* Đã điều chỉnh tỷ lệ khung hình `childAspectRatio` từ 1.3 về 1.18 (tăng chiều cao hiển thị của thẻ thêm ~12px), đồng thời tối ưu hóa đệm `padding` (từ 14px về 10px dọc) và khoảng cách `SizedBox` trong [AdminStatCard](file:///d:/ChuyenDeCNTT/jet_post/lib/modules/admin/widgets/admin_stat_card.dart), tạo thêm hơn 25px khoảng trống an toàn, loại bỏ hoàn toàn lỗi tràn viền trên mọi kích thước màn hình điện thoại.
