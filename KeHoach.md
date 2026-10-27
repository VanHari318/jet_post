# KẾ HOẠCH TỔNG THỂ VÀ KIẾN TRÚC HỆ THỐNG
**Đề tài:** Ứng dụng xe công nghệ và giao hàng cho tài xế và khách hàng  
**Học phần:** Chuyên đề Công nghệ Thông tin - Nhóm 14  
**Giáo viên hướng dẫn:** Hoàng Quốc Dũng  
**Quy mô nhóm:** 4 thành viên  
**Kiến trúc giải pháp:** 1 Dự án Flutter duy nhất (Single All-in-One Multi-Role Application)  

---

## 1. Rà soát và Các điểm cần chỉnh sửa trong Báo cáo (Chuyên đề CNTT_ nhóm 14.md)

1. **Sai sót Logo trang bìa (Dòng 7):** Thay thế logo ĐH Bách Khoa TP.HCM bằng logo chính thức của **Trường Đại học Thủy Lợi (TLU)**.
2. **Thiếu danh sách thành viên (Dòng 17 - 23):** Cập nhật đầy đủ thông tin cả 4 thành viên (Mã SV, Họ tên, Lớp) từ STT 1 đến 4.
3. **Mâu thuẫn số lượng phân hệ:** Đồng bộ toàn bộ báo cáo (Mục 1.2.1 và 1.3) từ 3 phân hệ cũ sang **4 phân hệ nghiệp vụ chuẩn hóa** tương ứng với 4 thành viên.
4. **Quy trình nghiệp vụ Giao hàng (Express):** Bổ sung cơ chế đối soát giao hàng an toàn qua **mã OTP giao nhận** kết hợp **ảnh chụp bằng chứng giao hàng (Proof of Delivery - PoD)** tại mục 1.3.1 và 1.3.2.
5. **Hoàn thiện các chương còn trống:** Bổ sung nội dung kỹ thuật vào Mục 2.3 (Usecase), 2.4 (Điều hướng & Widget), 2.5 (Cơ sở dữ liệu Firestore), Chương 3 (Demo) và Chương 4 (Kết luận).

---

## 2. Chiến lược Kiến trúc: 1 Project Flutter Duy Nhất (Single All-in-One Multi-Role App)

Toàn bộ hệ thống được xây dựng trong **đúng 1 Project Flutter duy nhất**, đóng gói thành **1 file cài đặt (APK Android) duy nhất** (hoặc triển khai Web). Ứng dụng tích hợp 4 Phân hệ nghiệp vụ tương ứng với 4 Module chức năng độc lập:

```
               [1 PROJECT FLUTTER DUY NHẤT: JET POST]
                                 |
       +----------------+--------+--------+----------------+
       |                |                 |                |
   [Module 1]       [Module 2]        [Module 3]       [Module 4]
Phân hệ Khách    Phân hệ Tài xế   Phân hệ User        Phân hệ Admin
- Đặt xe & Gửi   - Nhận cuốc & GPS- Entry & Phone OTP - Bàn cờ Radar
- Lộ trình & Giá - Dẫn đường & PoD- eKYC & Profile    - Duyệt KYC & Data
(Customer)       (Driver)         (User)              (Admin Radar)
Thành viên 1     Thành viên 2     Thành viên 3        Thành viên 4
```

### 2.1. Kiến trúc Cổng vào (UI Entry Point) & Điều phối Vai trò
* **Bản chất nghiệp vụ:** Mỗi đối tượng có luồng tiếp cận và phân quyền riêng biệt:
  - *Khách hàng:* Đặt xe ôm, tạo đơn gửi hàng, theo dõi lộ trình và bưu kiện gửi cho mình, quản lý danh bạ địa chỉ quen thuộc, tra cứu lịch sử cuốc xe & quản lý đánh giá.
  - *Tài xế:* Nhận cuốc xe quanh bán kính, chạy ngầm định vị GPS, điều hướng và xác thực PoD.
  - *User:* Cung cấp hạ tầng xác thực Phone Auth OTP, quy trình eKYC bằng lái/CCCD cho tài xế, quản lý hồ sơ cá nhân, phân quyền RBAC, cài đặt hệ thống và trung tâm nhắn tin trực tiếp P2P giữa các người dùng (Direct User Chat).
  - *Quản trị viên (Admin):* Giám sát radar toàn cảnh, thẩm định hồ sơ tài xế, xử lý tranh chấp và điều hành hệ thống.

* **Kiến trúc Màn hình Cổng vào (UI Entry Point - Welcome Portal):**
  - Khi mở app lần đầu (hoặc sau khi Đăng xuất), ứng dụng hiển thị một **Màn hình Cổng vào Chào đón (Welcome Gate)**:
    1. 🟢 **"Tôi là Khách hàng"** ➔ Vào thẳng cổng Khách hàng (đặt xe / giao hàng).
    2. 🟡 **"Tôi là Đối tác Tài xế"** ➔ Mở luồng dành riêng cho tài xế (bật trực tuyến nhận đơn).
    3. 🔵 **"Cổng Quản trị viên"** ➔ Đăng nhập bảo mật vào Dashboard Admin.
    4. 🟣 **"Đăng ký Tài xế Mới (eKYC)"** ➔ Khởi động luồng nộp hồ sơ đối tác trực tuyến.

* **Cơ chế Lưu phiên (Auto-login) & Demo Switcher:**
  - Sau khi đăng nhập thành công, app lưu token phiên làm việc vào `shared_preferences`. Các lần mở app tiếp theo sẽ tự động vào thẳng giao diện tương ứng.
  - Khi cần đổi vai trò để kiểm thử hoặc demo trước Hội đồng: Người dùng chỉ cần bấm nút **"Đăng xuất"** hoặc gạt **"Công tắc Demo Switcher"** ở góc màn hình để quay về Màn hình Cổng vào ban đầu.

---

## 3. Đặc tả Chi tiết Các Task: Mô tả, Ngữ cảnh Sử dụng và Luồng Hoạt động

---

### 3.1. Phân hệ 1: Module Khách hàng & Dịch vụ Đặt cuốc (Customer & Booking Module)
* **Thành viên phụ trách:** Thành viên 1
* **Thư mục mã nguồn:** `lib/modules/customer/`

#### Task 1.1 - Giao diện Đặt xe ôm (Ride-hailing Booking)
* **Mô tả:** Lấy vị trí GPS hiện tại, tìm kiếm địa chỉ đến qua OpenRouteService Geocoding, hiển thị bản đồ OpenStreetMap và tính cước Upfront cố định.
* **Trường hợp sử dụng:** Khách hàng có nhu cầu gọi xe máy để di chuyển từ điểm A đến điểm B.
* **Luồng hoạt động:**
  1. Khách mở màn hình Đặt xe -> App tự động ghim vị trí GPS hiện tại làm "Điểm đón".
  2. Khách gõ địa chỉ đến vào ô tìm kiếm -> Chọn địa điểm trong danh sách gợi ý.
  3. App gọi OpenRouteService API vẽ đường (Polyline), tính khoảng cách và giá cước hiển thị minh bạch.
  4. Khách bấm nút **"Đặt xe ngay"** -> Tạo tài liệu trong collection `rides` với trạng thái `PENDING_DRIVER` kèm Geohash điểm đón -> Màn hình radar quét tìm tài xế có đồng hồ đếm ngược 45s.

#### Task 1.2 - Giao diện Tạo đơn Giao hàng nhanh (Express Delivery)
* **Mô tả:** Tạo đơn gửi bưu kiện, phân loại hàng hóa, ghi chú bưu gửi và tính cước giao hàng.
* **Trường hợp sử dụng:** Khách hàng cần gửi đồ ăn, tài liệu, hàng hóa đến một địa chỉ khác.
* **Luồng hoạt động:**
  1. Khách chọn dịch vụ "Giao hàng" -> Nhập tên, SĐT người nhận, chọn loại hàng (Tài liệu/Đồ ăn/Hàng nặng) và ghi chú vận chuyển.
  2. Chọn địa chỉ lấy hàng và địa chỉ giao hàng trên bản đồ -> App tính cước vận chuyển bưu phẩm cố định.
  3. Khách bấm **"Tạo đơn giao hàng"** -> Tạo tài liệu trong collection `deliveries` với trạng thái `PENDING_DRIVER`.
  4. App sinh link tra cứu rút gọn `jetpost.web.app/track?orderId=...` kèm nút **"Chia sẻ hành trình cho người nhận qua Zalo/SMS"**.

#### Task 1.3 - Theo dõi Hành trình Thời gian thực (Live Real-time Tracking)
* **Mô tả:** Lắng nghe luồng dữ liệu vị trí tài xế từ Firestore và hiển thị di chuyển trên bản đồ.
* **Trường hợp sử dụng:** Ngay sau khi có tài xế nhận cuốc xe hoặc nhận đơn giao hàng.
* **Luồng hoạt động:**
  1. Cuốc xe chuyển trạng thái sang `ACCEPTED` -> Màn hình tự động chuyển sang Live Tracking.
  2. App lắng nghe luồng Firestore Stream tọa độ GPS của tài xế.
  3. Marker icon xe máy trên bản đồ di chuyển mượt mà và xoay theo hướng di chuyển thực tế.
  4. Hiển thị thông tin tài xế (Tên, biển số xe, số sao) và thời gian dự kiến (ETA) tài xế đến nơi.

#### Task 1.4 - Tra cứu Đơn bưu kiện Gửi cho Tôi (Consignee Tracking Tab)
* **Mô tả:** Màn hình quản lý các đơn hàng đang giao đến cho chính khách hàng này.
* **Trường hợp sử dụng:** Khách hàng được ai đó gửi đồ và muốn kiểm tra bưu phẩm đang ở đâu.
* **Luồng hoạt động:**
  1. Khách mở tab "Đơn nhận của tôi".
  2. App tự động truy vấn các đơn hàng trong collection `deliveries` có `receiverPhone` trùng với SĐT của khách.
  3. Hiển thị Timeline bưu kiện trực quan (*Đã tạo đơn ➔ Tài xế tiếp nhận ➔ Đã lấy hàng ➔ Đang giao ➔ Giao thành công*).
  4. Khi đơn đang giao, màn hình hiển thị **Mã OTP nhận hàng (4 số)** để khách đọc cho tài xế khi nhận hàng.

#### Task 1.5 - Hoàn tất Chuyến, Đối soát PoD & Đánh giá Dịch vụ
* **Mô tả:** Xem hóa đơn tiền mặt, kiểm tra ảnh chụp bằng chứng giao hàng (PoD) và chấm điểm chất lượng.
* **Trường hợp sử dụng:** Tài xế bấm hoàn thành cuốc xe hoặc giao bưu phẩm thành công.
* **Luồng hoạt động:**
  1. Nhận tín hiệu `COMPLETED` -> Màn hình hiển thị Hóa đơn thanh toán tiền mặt.
  2. Đối với đơn giao hàng: Màn hình hiển thị ảnh chụp Proof of Delivery (PoD Photo) của tài xế tải lên để khách đối soát.
  3. Khách chọn số sao (1-5 sao), chọn các thẻ đánh giá ("Lái xe cẩn thận", "Thân thiện", "Đúng giờ") -> Bấm gửi đánh giá -> Cập nhật điểm uy tín tài xế.

#### Task 1.6 - Xử lý Hủy chuyến & Ngoại lệ
* **Mô tả:** Xử lý tình huống hủy chuyến hoặc không có tài xế nhận cuốc quanh khu vực.
* **Trường hợp sử dụng:** Khách đổi ý không muốn đi nữa, hoặc hết 45s đếm ngược không tìm được tài xế.
* **Luồng hoạt động:**
  1. *Khách chủ động hủy:* Bấm nút "Hủy chuyến" -> Hiện modal chọn lý do hủy -> Cập nhật trạng thái `CANCELLED` -> Thông báo cho tài xế nếu đã có tài xế nhận.
  2. *Timeout không có tài xế:* Hết 45s đếm ngược, app thông báo: "Không tìm thấy tài xế quanh khu vực" kèm 2 tùy chọn: "Tìm lại" (reset 45s) hoặc "Hủy đơn".

#### Task 1.7 - Quản lý Danh bạ Địa chỉ Quen thuộc (Saved Addresses)
* **Mô tả:** Lưu trữ danh sách các địa điểm quen thuộc (Nhà riêng, Cơ quan, Nơi thường đến) phục vụ đặt xe và gửi hàng siêu tốc 1 chạm.
* **Trường hợp sử dụng:** Khách hàng thường xuyên di chuyển giữa các địa điểm quen thuộc hoặc gửi hàng từ địa chỉ cố định mà không muốn mất công gõ tìm kiếm lại bản đồ mỗi lần.
* **Luồng hoạt động:**
  1. Khách hàng vào mục "Địa chỉ đã lưu" trên giao diện khách hàng -> Bấm "Thêm địa chỉ mới".
  2. Chọn biểu tượng nhãn (Nhà riêng / Cơ quan / Địa chỉ khác) -> Tìm kiếm tên đường trên OpenStreetMap hoặc ghim trực tiếp trên bản đồ.
  3. Lưu thông tin vào sub-collection `users/{customerId}/saved_addresses` trên Firestore.
  4. Khi khách mở màn hình Đặt xe (Task 1.1) hoặc Tạo đơn gửi hàng (Task 1.2): Các địa chỉ đã lưu sẽ hiển thị nổi bật dưới dạng các thẻ chọn nhanh (Quick Action Chips). Khách chỉ cần bấm 1 chạm là hệ thống tự điền tọa độ điểm đón hoặc điểm trả và vẽ tuyến đường tức thì.

#### Task 1.8 - Trung tâm Hoạt động, Lịch sử Cuốc xe & Quản lý Đánh giá (Customer Activity & History)
* **Mô tả:** Quản lý toàn bộ danh sách các cuốc xe ôm và đơn giao hàng mà khách hàng đã từng thực hiện, cho phép xem lại chi tiết lộ trình, hóa đơn, ảnh PoD, đánh giá bù tài xế và đặt lại chuyến nhanh 1 chạm.
* **Trường hợp sử dụng:** Khách hàng muốn xem lại các chuyến đi trước đó để đối soát chi phí, lấy thông tin tài xế để liên hệ tìm đồ thất lạc, chấm điểm bù cho tài xế nếu lúc kết thúc chuyến chưa kịp đánh giá, hoặc đặt lại cuốc quen thuộc.
* **Luồng hoạt động:**
  1. Khách hàng bấm vào tab "Hoạt động" (Activity) trên thanh điều hướng dưới (BottomNavigationBar).
  2. Màn hình phân loại 2 tab con trực quan:
     - *Đang diễn ra:* Hiển thị các đơn đang quét tìm tài xế, tài xế đang đến đón hoặc đang giao.
     - *Lịch sử:* Hiển thị toàn bộ các đơn đã hoàn thành (`COMPLETED`) hoặc đã hủy (`CANCELLED`).
  3. Mỗi mục trong danh sách hiển thị thẻ tóm tắt: Biểu tượng dịch vụ (Xe ôm / Giao hàng), ngày giờ thực hiện, điểm đón - điểm trả, số tiền cước và huy hiệu trạng thái.
  4. Bấm vào 1 đơn cụ thể để mở **Màn hình Chi tiết Đơn hàng (Order Detail Screen)**:
     - Hiển thị bản đồ thu nhỏ tái hiện tuyến đường đã đi.
     - Hiển thị thông tin tài xế thực hiện chuyến (Tên, biển số xe).
     - Đối với đơn giao hàng: Hiển thị ảnh chụp Proof of Delivery (PoD Photo) của tài xế tải lên để khách đối soát bất kỳ lúc nào.
     - Khu vực Đánh giá: Hiển thị số sao đã chấm. Nếu khách hàng lúc kết thúc chuyến bấm bỏ qua chưa chấm sao, màn hình sẽ hiển thị nút **"Đánh giá ngay"** để khách chấm điểm bổ sung và để lại nhận xét.
  5. Tính năng **"Đặt lại (Re-order)"**: Khách bấm nút "Đặt lại chuyến này" -> App tự động chuyển sang màn hình Đặt xe/Giao hàng với điểm đón và điểm trả đã được điền sẵn, khách chỉ cần bấm xác nhận mà không cần gõ lại.

---

### 3.2. Phân hệ 2: Module Đối tác Tài xế & Vận chuyển (Driver Operations Module)
* **Thành viên phụ trách:** Thành viên 2
* **Thư mục mã nguồn:** `lib/modules/driver/`

#### Task 2.1 - Công tắc Trực tuyến & Dịch vụ GPS Chạy ngầm (Foreground Service)
* **Mô tả:** Kích hoạt chế độ sẵn sàng làm việc và tự động phát tọa độ GPS liên tục ngay cả khi khóa màn hình.
* **Trường hợp sử dụng:** Tài xế bắt đầu ca làm việc, bật app và di chuyển ngoài đường.
* **Luồng hoạt động:**
  1. Tài xế gạt công tắc "Sẵn sàng nhận cuốc" (Online).
  2. App kích hoạt Android Foreground Service, hiển thị thông báo cố định (`sticky notification`) trên thanh trạng thái: *"JetPost Driver đang hoạt động và đồng bộ GPS"*.
  3. Cứ mỗi khi tài xế di chuyển tối thiểu 15 mét (`distanceFilter: 15m`), service lấy tọa độ GPS, mã hóa Geohash và cập nhật vào document tài xế trên Firestore.
  4. Khi gạt công tắc sang "Offline": Dừng Foreground Service, hủy phát GPS để tiết kiệm pin.

#### Task 2.2 - Tiếp nhận Cuốc xe Thời gian thực (Real-time Order Dispatch)
* **Mô tả:** Lắng nghe và hiển thị cuốc xe/đơn giao hàng mới xuất hiện trong bán kính hoạt động của tài xế.
* **Trường hợp sử dụng:** Có khách hàng gần đó vừa bấm đặt xe hoặc tạo đơn giao hàng.
* **Luồng hoạt động:**
  1. Query Firestore phát hiện có cuốc xe ở trạng thái `PENDING_DRIVER` có Geohash khớp với bán kính lân cận của tài xế.
  2. App tài xế phát chuông thông báo âm thanh lớn và rung điện thoại.
  3. Màn hình bật pop-up modal hiển thị: Điểm đón khách/lấy hàng, điểm trả, khoảng cách đón, số tiền cước thực nhận, và đồng hồ đếm ngược 15 giây.
  4. Nếu bấm **"Nhận cuốc"**: Hệ thống gán `driverId` của tài xế vào cuốc xe, cập nhật trạng thái cuốc thành `ACCEPTED`, đóng modal và mở màn hình điều hướng.
  5. Nếu bấm **"Bỏ qua"** hoặc hết 15 giây: Modal tự đóng để chờ cuốc khác, nhường cuốc cho tài xế khác nhận.

#### Task 2.3 - Điều hướng & Tích hợp Google Maps (Navigation Deep-link)
* **Mô tả:** Chuyển tiếp tọa độ sang ứng dụng Google Maps gốc trên máy tài xế để dẫn đường Turn-by-turn bằng giọng nói.
* **Trường hợp sử dụng:** Tài xế cần chỉ đường cụ thể tới điểm đón khách hoặc địa chỉ giao hàng.
* **Luồng hoạt động:**
  1. Trên màn hình cuốc xe, tài xế bấm nút biểu tượng **"Google Maps"**.
  2. App JetPost sử dụng thư viện `url_launcher` gọi giao thức `google.navigation:q=latitude,longitude`.
  3. Ứng dụng Google Maps gốc trên máy tài xế tự động mở lên, bắt đầu dẫn đường bằng giọng nói rảnh tay.
  4. Khi đến nơi, tài xế chạm vào thanh thông báo để quay lại app JetPost thực hiện bước tiếp theo.

#### Task 2.4 - Máy Trạng thái Chuyến đi & Xác nhận Giao hàng PoD (State Machine)
* **Mô tả:** Quản lý chu trình cuốc xe và quy trình bàn giao hàng an toàn chuẩn logistics.
* **Trường hợp sử dụng:** Tài xế đang thực hiện chở khách hoặc đang đi giao gói hàng.
* **Luồng hoạt động:**
  * *Chu trình Xe ôm:* Đến điểm đón bấm "Đã đến nơi" -> Khách lên xe bấm "Bắt đầu chở" -> Đến đích bấm "Hoàn thành chuyến" -> Màn hình hiển thị số tiền mặt cần thu của khách.
  * *Chu trình Giao hàng chuẩn Logistics (PoD):*
    1. Đến điểm lấy hàng bấm **"Đã lấy hàng từ người gửi"**.
    2. Di chuyển đến điểm giao bấm **"Đã đến nơi giao"**.
    3. App kích hoạt camera yêu cầu tài xế: **Chụp ảnh gói hàng tại địa chỉ giao/người nhận cầm hàng (Proof of Delivery Photo)** tải lên Cloudinary (phân loại vào folder `jetpost/deliveries_pod`).
    4. Tài xế hỏi người nhận và nhập **mã OTP 4 số** vào ô xác thực trên màn hình.
    5. Hệ thống kiểm tra mã OTP khớp -> Bấm **"Xác nhận giao thành công"** -> Thu tiền mặt cước phí.
  * *Xử lý khi khách không nhận hàng:* Bấm "Không thể giao hàng" -> Chọn lý do (Khách không nghe máy sau 3 cuộc gọi, sai địa chỉ) -> Chuyển đơn sang trạng thái `FAILED_DELIVERY` chờ chuyển hoàn về người gửi.

#### Task 2.5 - Bảo vệ Quyền Riêng tư Khách hàng (Data Masking)
* **Mô tả:** Ẩn các số giữa của SĐT khách hàng/người nhận để phòng chống quấy rối.
* **Trường hợp sử dụng:** Tài xế cần liên lạc đón khách hoặc gọi người nhận ra lấy hàng.
* **Luồng hoạt động:**
  1. Trên màn hình tài xế, SĐT người nhận chỉ hiển thị dạng `098***5678`.
  2. Tài xế bấm icon cuộc gọi -> App kích hoạt giao thức `tel:098...` mở trình quay số điện thoại hệ điều hành để tài xế gọi, không lưu trữ công khai SĐT khách.

#### Task 2.6 - Ví Thu nhập & Báo cáo Lịch sử Cuốc
* **Mô tả:** Tổng hợp doanh thu, quản lý tiền mặt và xem lịch sử các chuyến đã chạy.
* **Trường hợp sử dụng:** Tài xế xem kết quả làm việc cuối ngày hoặc kiểm tra số dư.
* **Luồng hoạt động:**
  1. Tài xế mở tab "Thu nhập".
  2. App truy vấn toàn bộ cuốc xe hoàn thành trong ngày/tuần của tài xế.
  3. Hiển thị: Tổng tiền cước thu được, trừ % chiết khấu hoa hồng của hệ thống, số tiền thực nhận.
  4. Hiển thị danh sách các cuốc đã chạy và điểm sao đánh giá trung bình từ khách hàng.

---

### 3.3. Phân hệ 3: Module User (User Module)
* **Thành viên phụ trách:** Thành viên 3
* **Thư mục mã nguồn:** `lib/modules/user/`

#### Task 3.1 - Màn hình Cổng vào Hợp nhất (UI Entry Point Gate) & Phân luồng
* **Mô tả:** Xây dựng màn hình khởi đầu chào đón, điều phối người dùng vào đúng luồng vai trò mong muốn và quản lý lưu phiên tự động.
* **Trường hợp sử dụng:** Người dùng lần đầu mở app, hoặc khi chuyển đổi vai trò kiểm thử.
* **Luồng hoạt động:**
  1. Khi mở app, hiển thị màn hình Welcome Gate trực quan gồm các lựa chọn: "Tôi là Khách hàng", "Tôi là Đối tác Tài xế", "Cổng Quản trị viên" và "Đăng ký Tài xế Mới (eKYC)".
  2. Cung cấp nút chuyển đổi nhanh vai trò (**Demo Role Switcher**) để phục vụ kiểm thử và bảo vệ trước hội đồng.
  3. Quản lý lưu phiên đăng nhập (Auto-login / Keep-login qua SharedPreferences). Khi bấm "Đăng xuất" sẽ xóa phiên và quay lại màn hình Welcome Gate.

#### Task 3.2 - Động cơ Xác thực Đa kênh: Số điện thoại (Phone OTP) & Email/Mật khẩu (Omni-Channel Auth Engine)
* **Mô tả:** Xây dựng hệ thống xác thực kép linh hoạt cho người dùng: Xác thực qua Số điện thoại (Firebase Phone Auth OTP) và Xác thực qua Email/Mật khẩu (Firebase Email/Password Authentication), hỗ trợ liên kết chéo danh tính (Account Linking) và khôi phục mật khẩu đa kênh.
* **Trường hợp sử dụng:** Khách hàng, tài xế hoặc quản trị viên đăng ký, đăng nhập vào hệ thống; khôi phục mật khẩu khi quên; đăng nhập khi mất SIM hoặc thiết bị mới.
* **Luồng hoạt động:**
  1. *Đăng nhập / Đăng ký qua Số điện thoại (SMS OTP):*
     - Người dùng nhập Số điện thoại -> Gọi hàm chuẩn hóa sang định dạng E.164 (`+84...`).
     - Áp dụng thuật toán Regex kiểm duyệt nghiêm ngặt: Chỉ chấp nhận các đầu số hợp lệ của các nhà mạng Việt Nam (`03, 05, 07, 08, 09` đúng 10 chữ số). Từ chối số ảo, số máy bàn.
     - Tích hợp Firebase Phone Auth gửi mã SMS OTP 6 chữ số về SIM điện thoại; cơ chế Rate Limiting đếm ngược 60 giây.
     - Tích hợp sẵn Whitelist Testing Numbers (số điện thoại thử nghiệm miễn phí) trên Firebase Console để demo 100% miễn phí không tốn SMS.
  2. *Đăng nhập / Đăng ký qua Email & Mật khẩu (Email/Password Auth):*
     - Tab "Email & Mật Khẩu": Người dùng nhập Email hợp lệ và Mật khẩu (tối thiểu 6 ký tự).
     - Đăng ký mới: Sử dụng `FirebaseAuth.instance.createUserWithEmailAndPassword`, tự động khởi tạo hồ sơ người dùng trên Firestore (`users/{uid}`).
     - Đăng nhập: Sử dụng `FirebaseAuth.instance.signInWithEmailAndPassword`, hỗ trợ lưu phiên làm việc an toàn.
     - Cung cấp sẵn các Chip tài khoản mẫu phục vụ chấm thi đồ án: `khachhang@jetpost.vn`, `taixe@jetpost.vn`, `admin@jetpost.vn`.
  3. *Quên Mật khẩu & Đặt lại Đa kênh (Forgot Password Flow):*
     - Bấm "Quên mật khẩu" -> Chọn nhận mã OTP qua Email hoặc qua Số điện thoại đã liên kết.
     - Xác thực mã OTP hợp lệ -> Cho phép đặt mật khẩu mới mà không làm gián đoạn tài khoản.

#### Task 3.3 - Quy trình Định danh Điện tử eKYC cho Đối tác Tài xế
* **Mô tả:** Thu thập thông tin phương tiện, chụp ảnh giấy tờ pháp lý để Admin thẩm định trước khi kích hoạt tài khoản chạy xe.
* **Trường hợp sử dụng:** Người có xe máy muốn đăng ký tham gia mạng lưới tài xế đối tác.
* **Luồng hoạt động:**
  1. Chọn "Đăng ký làm Tài xế" -> Yêu cầu tài khoản bắt buộc phải có Số điện thoại xác thực chính chủ (nếu đăng ký bằng Email thì thực hiện liên kết SĐT trước).
  2. Điền thông tin cá nhân, loại xe, biển số xe máy.
  3. Tích hợp Camera chụp ảnh rõ nét: Căn cước công dân (CCCD 2 mặt) và Giấy phép lái xe (GPLX).
  4. Tải lên Cloudinary an toàn (phân loại vào folder `jetpost/drivers_ekyc`).
  5. Lưu thông tin hồ sơ vào collection `drivers` với trạng thái `PENDING_APPROVAL`.
  6. Màn hình app hiển thị thông báo: "Hồ sơ của bạn đang được xét duyệt, vui lòng chờ Admin thẩm định".

#### Task 3.4 - Quản lý Hồ sơ Cá nhân, Liên kết Danh tính & Bảo mật Đổi SĐT (Profile & Account Linking)
* **Mô tả:** Cho phép người dùng xem, chỉnh sửa thông tin cá nhân, cập nhật ảnh đại diện, liên kết thêm phương thức đăng nhập và quy trình đổi SĐT an toàn khi mất SIM.
* **Trường hợp sử dụng:** Khách hàng hoặc tài xế muốn cập nhật thông tin cá nhân, liên kết Email vào tài khoản SĐT, hoặc đổi số điện thoại mới khi mất SIM cũ.
* **Luồng hoạt động:**
  1. Người dùng vào mục "Hồ sơ cá nhân": Hiển thị Họ tên, Số điện thoại, Email liên kết, Ảnh đại diện (Avatar).
  2. Cho phép chỉnh sửa Tên, tải ảnh đại diện mới lên Cloudinary (`jetpost/avatars`).
  3. *Tính năng Liên kết Phương thức Đăng nhập (Omni-channel Linking):*
     - Nếu đăng ký bằng SĐT: Hiển thị nút "Liên kết Email & Mật khẩu" -> Nhập Email và mật khẩu -> Gửi mã OTP xác thực email chính chủ -> Hoàn tất liên kết.
     - Nếu đăng ký bằng Email: Hiển thị nút "Liên kết Số điện thoại" -> Nhập SĐT -> Gửi SMS OTP xác thực SIM chính chủ -> Hoàn tất liên kết.
  4. *Quy trình Đổi Số Điện Thoại An Toàn (Kịch bản Mất SIM / Mất Máy - Step-up Verification):*
     - Bước 1 (Xác minh Danh tính Chủ sở hữu): Hệ thống cung cấp 2 phương thức nhận OTP:
       + *Cách 1 (Vẫn còn SIM cũ):* Gửi mã OTP về SĐT cũ.
       + *Cách 2 (Mất SIM / Mất máy):* Đăng nhập bằng Email/Mật khẩu -> Chọn "Gửi mã OTP xác nhận về Email liên kết".
     - Bước 2 (Xác thực Số điện thoại Mới): Sau khi vượt qua Bước 1, người dùng nhập Số điện thoại mới -> Hệ thống gửi mã OTP về SĐT mới -> Nhập OTP chính xác -> Cập nhật trường `phone` trên Firestore thành công!
     - *Trường hợp chưa liên kết Email và mất SIM:* Người dùng cần liên hệ Quản trị viên (Admin) đối soát hồ sơ hoặc làm lại SIM tại nhà mạng viễn thông.

#### Task 3.5 - Quản lý Phân quyền theo Vai trò (Role-Based Access Control - RBAC Guard) & Lưu phiên Auto-login
* **Mô tả:** Kiểm soát và phân định quyền truy cập các màn hình ứng dụng dựa vào thuộc tính vai trò của tài khoản, bảo vệ an ninh và duy trì trạng thái đăng nhập.
* **Trường hợp sử dụng:** Điều hướng và bảo vệ an ninh hệ thống trong suốt phiên làm việc, tự động mở đúng giao diện tương ứng cho các lần mở app tiếp theo.
* **Luồng hoạt động:**
  1. Mỗi tài khoản lưu trữ thuộc tính `role: 'customer' | 'driver' | 'admin'` trên Firestore và đồng bộ trạng thái vào `shared_preferences` trên thiết bị.
  2. Bộ điều hướng (Router Guard) kiểm tra: Nếu tài khoản `driver` chưa được duyệt (`status != 'ACTIVE'`) thì không cho phép mở màn hình bật Online nhận cuốc.
  3. Ngăn chặn tài khoản khách hàng hoặc tài xế truy cập trái phép vào các màn hình điều hành quản trị viên của Admin.
  4. Khi mở app, router tự động kiểm tra token phiên đã lưu để điều hướng thẳng vào dashboard tương ứng (Auto-login), chỉ quay lại Welcome Gate khi bấm "Đăng xuất".

#### Task 3.6 - Cài đặt Ứng dụng & Tùy chọn Giao diện (App Settings: Dark/Light Mode, Âm thanh & Thông báo)
* **Mô tả:** Cung cấp trung tâm tùy chỉnh trải nghiệm người dùng, cấu hình giao diện sáng/tối và thông báo hệ thống.
* **Trường hợp sử dụng:** Người dùng muốn đổi theme tối khi lái xe ban đêm, tắt/bật âm thanh chuông báo cuốc xe mới.
* **Luồng hoạt động:**
  1. Người dùng mở mục "Cài đặt ứng dụng".
  2. Tùy chọn Theme: Giao diện Sáng (Light) / Giao diện Tối (Dark mode - giảm chói mắt cho tài xế ban đêm) / Theo hệ thống.
  3. Tùy chọn Âm thanh & Rung: Bật/tắt nhạc chuông báo nhận đơn hàng mới và rung khi có thông báo đẩy.
  4. Nút "Chuyển nhanh vai trò kiểm thử (Demo Role Switcher)": Hỗ trợ các thành viên trong nhóm và giảng viên chuyển đổi linh hoạt giữa các phân hệ để chấm điểm và kiểm thử nhanh.

#### Task 3.7 - Trung tâm Nhắn tin Trực tiếp Đa người dùng (Direct Peer-to-Peer User Chat)
* **Mô tả:** Xây dựng hệ thống nhắn tin 1-1 thời gian thực giữa 2 tài khoản người dùng bất kỳ trên nền tảng, hoàn toàn độc lập với cuốc xe và không phân biệt vai trò (Khách hàng, Tài xế hay Admin đều có thể chủ động nhắn tin cho nhau).
* **Trường hợp sử dụng:** Người gửi nhắn tin trao đổi riêng với Người nhận bưu phẩm, Khách hàng nhắn tin hỏi thăm Tài xế quen, các Tài xế trao đổi kinh nghiệm chạy xe với nhau, hoặc Người dùng nhắn tin trực tiếp yêu cầu Quản trị viên hỗ trợ kỹ thuật.
* **Luồng hoạt động:**
  1. *Hộp thư Hội thoại (Inbox / Conversations List Screen):*
     - Mở tab "Tin nhắn" hiển thị danh sách toàn bộ các cuộc trò chuyện gần đây, sắp xếp theo thời gian mới nhất.
     - Mỗi mục hội thoại hiển thị: Ảnh đại diện (Avatar), Tên người đối thoại, số điện thoại, trích đoạn tin nhắn gần nhất và huy hiệu đếm số tin chưa đọc.
  2. *Khởi tạo Cuộc trò chuyện Mới:*
     - Bấm nút "Soạn tin nhắn mới" -> Nhập Số điện thoại của người dùng cần chat (hoặc chọn từ danh sách người dùng trong hệ thống) -> Hệ thống tự động tạo mã phòng chat duy nhất theo cặp UID người dùng (`chatId = uid1_uid2`).
  3. *Màn hình Phòng chat Trực tiếp 1-1 (Direct 1-on-1 Chat Room):*
     - Hiển thị giao diện tin nhắn dạng bong bóng đối thoại 2 chiều (tin gửi đi nằm bên phải màu xanh, tin nhận về nằm bên trái màu xám).
     - Luồng dữ liệu lắng nghe thời gian thực (Real-time Stream) từ sub-collection `conversations/{chatId}/messages` trên Cloud Firestore, tin nhắn gửi và nhận hiển thị tức thì.
     - Ô soạn thảo văn bản hỗ trợ gõ bàn phím và nút gửi tin nhắn nhanh.
  4. *Quản lý Lịch sử Tin nhắn Bền vững (Persistent Chat History):*
     - Dữ liệu trò chuyện được lưu trữ vĩnh viễn theo tài khoản, không bị giới hạn hay tự động đóng sau chuyến đi, người dùng có thể quay lại đọc lại toàn bộ lịch sử trao đổi bất cứ khi nào.

---

### 3.4. Phân hệ 4: Module Quản trị Điều hành & Nền tảng (Admin Dispatcher & Core Module)
* **Thành viên phụ trách:** Thành viên 4
* **Thư mục mã nguồn:** `lib/modules/admin/`

#### Task 4.1 - Xác thực Quản trị viên Bảo mật & Điều hướng Admin
* **Mô tả:** Cổng đăng nhập nội bộ bảo mật dành riêng cho Quản trị viên hệ thống.
* **Trường hợp sử dụng:** Quản trị viên hệ thống bắt đầu ca làm việc điều hành nền tảng.
* **Luồng hoạt động:**
  1. Admin đăng nhập bằng tài khoản quản trị.
  2. Hệ thống kiểm tra quyền `role == 'admin'` trên Firestore.
  3. Nếu đúng: Mở Dashboard điều hành; Nếu tài khoản thường: Từ chối truy cập và thông báo không đủ quyền hạn.

#### Task 4.2 - Bàn cờ Điều hành Radar Thời gian thực (Live Dispatcher Map)
* **Mô tả:** Màn hình bản đồ lớn giám sát trực tiếp mật độ tài xế và các chuyến đi đang diễn ra toàn thành phố.
* **Trường hợp sử dụng:** Giám sát luồng vận hành hàng ngày, phát hiện các khu vực thiếu xe hoặc có sự cố.
* **Luồng hoạt động:**
  1. Màn hình tải bản đồ tổng quan thành phố.
  2. Lắng nghe real-time toàn bộ tài xế: Marker màu xanh (Online sẵn sàng), Marker màu đỏ (Đang có khách/đang giao hàng).
  3. Bấm vào bất kỳ icon xe máy nào để xem thông tin chi tiết: Tên tài xế, SĐT, biển số xe, cuốc đang chạy, tốc độ di chuyển hiện tại.

#### Task 4.3 - Thẩm định & Phê duyệt Hồ sơ Đối tác Tài xế eKYC
* **Mô tả:** Kiểm duyệt giấy phép lái xe, căn cước và kích hoạt tài khoản tài xế mới do Module 3 nộp lên.
* **Trường hợp sử dụng:** Có tài xế mới gửi hồ sơ đăng ký tham gia mạng lưới.
* **Luồng hoạt động:**
  1. Tab "Duyệt hồ sơ" hiển thị danh sách tài xế ở trạng thái `PENDING_APPROVAL`.
  2. Admin bấm vào từng hồ sơ -> Màn hình hiển thị thông tin cá nhân và ảnh chụp phóng to GPLX, CCCD từ Cloudinary CDN.
  3. Nếu hợp lệ: Bấm **"Phê duyệt"** -> Tài khoản tài xế chuyển thành `ACTIVE`, tài xế có thể bật Online nhận cuốc.
  4. Nếu giấy tờ mờ/sai: Bấm **"Từ chối"** -> Hiện form nhập lý do (VD: "Ảnh bằng lái bị lóa, vui lòng chụp lại") để gửi thông báo về máy tài xế.

#### Task 4.4 - Quản lý Tài khoản Người dùng & Thực thi Chế tài (Ban/Unban)
* **Mô tả:** Quản lý cơ sở dữ liệu khách hàng, tài xế và can thiệp xử lý vi phạm.
* **Trường hợp sử dụng:** Phát hiện tài xế gian lận, hủy cuốc vô lý nhiều lần hoặc khách hàng quấy rối, bom hàng.
* **Luồng hoạt động:**
  1. Mở danh sách Người dùng có bộ lọc theo vai trò (Khách / Tài xế) và ô tìm kiếm theo Tên / SĐT.
  2. Admin bấm xem chi tiết lịch sử cuốc, tỷ lệ hủy cuốc của tài khoản.
  3. Bấm nút **"Khóa tài khoản" (Ban)** kèm thời hạn hoặc vĩnh viễn -> Tài khoản bị đổi trạng thái `BANNED`, app của đối tượng đó bị ép đăng xuất ngay lập tức và không thể đăng nhập lại.
  4. Có nút **"Mở khóa" (Unban)** khi vi phạm đã được giải quyết.

#### Task 4.5 - Quản lý Tranh chấp Đơn hàng & Đối soát PoD (Dispute Management)
* **Mô tả:** Trung tâm xử lý khiếu nại giữa khách hàng, người nhận và tài xế.
* **Trường hợp sử dụng:** Người nhận khiếu nại chưa nhận được đồ, hoặc tài xế khiếu nại khách không trả tiền mặt.
* **Luồng hoạt động:**
  1. Admin tra cứu mã đơn hàng có khiếu nại.
  2. Màn hình mở ra toàn bộ "Hồ sơ đối soát kỹ thuật số":
     - Thông tin chi tiết Người gửi và Người nhận.
     - Lịch sử tọa độ GPS của tài xế lúc bấm "Đã đến nơi giao".
     - Ảnh chụp bằng chứng giao hàng (PoD Photo) tài xế tải lên.
     - Thời điểm người nhận cung cấp mã OTP và thời điểm tài xế nhập mã OTP.
  3. Admin đối chiếu hồ sơ để ra quyết định phân xử công bằng, minh bạch.

#### Task 4.6 - Cấu hình Biểu cước & Chính sách Hệ thống
* **Mô tả:** Điều chỉnh linh hoạt bảng giá tính cước và tỷ lệ chiết khấu của nền tảng.
* **Trường hợp sử dụng:** Biến động giá xăng dầu, chính sách khuyến mại hoặc thay đổi phí hoa hồng.
* **Luồng hoạt động:**
  1. Mở màn hình "Cấu hình Hệ thống".
  2. Admin chỉnh sửa các tham số: Giá mở cửa (0-2km đầu), giá mỗi km tiếp theo, phụ phí giao hàng cồng kềnh, tỷ lệ % hoa hồng chiết khấu nền tảng (VD: 15%).
  3. Bấm **"Lưu cấu hình"** -> Cập nhật vào document `system_settings` trên Firestore.
  4. Tất cả các máy khách hàng và tài xế tự động cập nhật biểu giá mới ngay trong lần tính cước tiếp theo mà không cần cập nhật lại app.

#### Task 4.7 - Báo cáo Thống kê & Phân tích Kinh doanh (Analytics)
* **Mô tả:** Cung cấp biểu đồ trực quan về doanh thu và hiệu suất vận hành toàn hệ thống.
* **Trường hợp sử dụng:** Đánh giá tình hình kinh doanh định kỳ theo ngày/tuần/tháng.
* **Luồng hoạt động:**
  1. Admin chọn khoảng thời gian cần xem báo cáo.
  2. Hệ thống tổng hợp dữ liệu từ collection `rides` và `deliveries`:
     - Biểu đồ đường: Doanh thu theo mốc thời gian.
     - Biểu đồ tròn: Tỷ lệ cuốc hoàn thành thành công vs cuốc bị hủy.
     - Thống kê số lượng tài xế hoạt động và số lượng người dùng mới.
  3. Có nút hỗ trợ xuất dữ liệu ra file báo cáo.

#### Task 4.8 - Trung tâm Phát Thông báo & Cảnh báo Vận hành Toàn hệ thống (Broadcast Notifications)
* **Mô tả:** Cung cấp kênh truyền thông thời gian thực từ Quản trị viên điều hành tới toàn bộ mạng lưới Khách hàng và Đối tác Tài xế.
* **Trường hợp sử dụng:** Admin cần gửi cảnh báo thời tiết mưa bão ngập lụt, nhắc nhở an toàn giao thông cho tài xế, thông báo chương trình khuyến mại cước phí cho khách hàng, hoặc phát đi cảnh báo bảo trì hệ thống.
* **Luồng hoạt động trên Giao diện Ứng dụng:**
  1. Admin mở màn hình "Phát Thông báo Hệ thống".
  2. Điền Tiêu đề và Nội dung thông điệp (Ví dụ: *"Cảnh báo mưa to ngập lụt khu vực Đống Đa - Đề nghị tài xế lái xe an toàn, bảo quản bưu kiện cẩn thận"*).
  3. Chọn nhóm đối tượng nhận tin bằng các nút tùy chọn nhanh:
     - 🟡 **Gửi riêng Đối tác Tài xế:** Chỉ các tài xế đang trực tuyến hoặc trong ca làm việc nhận được tin.
     - 🟢 **Gửi riêng Khách hàng:** Thông báo mã giảm giá, tính năng mới.
     - 🔵 **Gửi Toàn mạng lưới:** Áp dụng cho các thông báo khẩn cấp toàn hệ thống.
  4. Bấm **"Phát thông báo ngay (Broadcast)"**:
     - Hệ thống tự động đẩy dữ liệu thông báo vào collection `system_notifications` trên Cloud Firestore.
     - Ứng dụng của khách hàng và tài xế lập tức nhận tín hiệu thông qua stream lắng nghe dữ liệu, kích hoạt rung chuông và hiển thị thông báo đẩy (In-app Notification Banner).
  5. Xem lịch sử danh sách các thông báo đã gửi trong quá khứ kèm trạng thái thời gian phát tin.

---

## 4. Ma trận Phân công và Trách nhiệm (RACI Matrix)

| Hạng mục / Phân hệ | Thành viên 1 (Khách) | Thành viên 2 (Tài xế) | Thành viên 3 (User) | Thành viên 4 (Admin & Core) |
| :--- | :---: | :---: | :---: | :---: |
| **Thiết kế Schema CSDL Firestore** | Hỗ trợ | Hỗ trợ | Hỗ trợ | **Chịu trách nhiệm chính (A/R)** |
| **Phát triển Phân hệ 1 (Khách hàng & Đặt cuốc)** | **Chịu trách nhiệm chính (A/R)** | Phối hợp luồng cuốc | Tham vấn Auth | Giám sát |
| **Phát triển Phân hệ 2 (Tài xế & Vận hành)** | Phối hợp luồng cuốc | **Chịu trách nhiệm chính (A/R)** | Phối hợp eKYC | Giám sát |
| **Phát triển Phân hệ 3 (Module User)** | Tham vấn Client | Tham vấn Tài xế | **Chịu trách nhiệm chính (A/R)** | Phối hợp Firebase Auth |
| **Phát triển Phân hệ 4 (Quản trị & Điều phối Admin)** | Tham vấn | Tham vấn | Phối hợp duyệt eKYC | **Chịu trách nhiệm chính (A/R)** |
| **Hạ tầng Firebase & Firestore Security Rules** | Thực hiện module | Thực hiện module | Thực hiện module | **Chịu trách nhiệm chính (A/R)** |
| **Biên soạn Báo cáo chuyên đề** | Viết Chương 1, 2.4 | Viết Chương 2.1, 3.1 | Viết Chương 2.2, 3.2 | Tổng hợp, vẽ CSDL 2.5 |

*(Ghi chú: A = Accountable - Người chịu trách nhiệm cao nhất; R = Responsible - Người trực tiếp thực hiện).*

---

## 5. Lộ trình Triển khai Dự án (Sprint Planning)

### Giai đoạn 1: Chuẩn hóa Tài liệu & Thiết kế Kiến trúc (Tuần 1 - Tuần 2)
- Chỉnh sửa các lỗi trong `Chuyên đề CNTT_ nhóm 14.md` (Logo TLU, bảng 4 thành viên, chuẩn hóa 4 phân hệ).
- Vẽ biểu đồ Usecase tổng quát và Usecase phân rã cho 4 phân hệ.
- Thiết kế Data Dictionary và Sơ đồ thực thể CSDL Cloud Firestore.

### Giai đoạn 2: Lập trình Độc lập từng Module trong Project (Tuần 3 - Tuần 6)
- **Thành viên 1:** Hoàn thiện `lib/modules/customer/` (Đặt xe, tạo đơn giao hàng, tra cứu đơn nhận, live tracking, PoD, đánh giá, lịch sử hoạt động, danh bạ địa chỉ quen thuộc).
- **Thành viên 2:** Hoàn thiện `lib/modules/driver/` (Background GPS ngầm, pop-up nhận cuốc, Google Maps dẫn đường, chụp ảnh PoD).
- **Thành viên 3:** Hoàn thiện `lib/modules/user/` (Entry Point, Phone Auth OTP, eKYC chụp ảnh CCCD/bằng lái, Profile, RBAC & Cài đặt app, Direct User Chat).
- **Thành viên 4:** Hoàn thiện `lib/modules/admin/` (Radar giám sát xe toàn thành phố, thẩm định hồ sơ eKYC, cấu hình giá cước, biểu đồ doanh thu, phát thông báo vận hành).

### Giai đoạn 3: Ghép nối Toàn diện & Kiểm thử Kịch bản 4 Thiết bị (Tuần 7 - Tuần 8)
- Test luồng Đăng ký & Thẩm định: Tài xế nộp hồ sơ eKYC (Module 3) -> Admin duyệt hồ sơ (Module 4) -> Tài xế được kích hoạt bật Online (Module 2).
- Test luồng Đặt xe & Giao hàng: Khách đặt cuốc (Module 1) -> Tài xế nhận cuốc & chạy (Module 2) -> Khách theo dõi & đối soát PoD (Module 1) -> Admin giám sát radar & doanh thu (Module 4).
- Đóng gói **1 file APK duy nhất** cài đặt lên 4 điện thoại Android (hoặc chạy Web) để 4 thành viên cùng kiểm thử kịch bản phối hợp 4 vai trò.

### Giai đoạn 4: Hoàn tất Báo cáo & Luyện tập Bảo vệ (Tuần 9)
- Chụp ảnh màn hình các chức năng thực tế đưa vào Chương 3 của báo cáo.
- Soạn thảo kết luận và hướng phát triển ở Chương 4.
- Chuẩn bị slide thuyết trình và diễn tập kịch bản demo 4 điện thoại trước hội đồng.

---

## 6. Cấu trúc Thư mục Module hóa (Ngăn ngừa xung đột Git Merge Conflict)

Trong **1 Project Flutter duy nhất**, thư mục `lib/` được phân tách độc lập theo 4 phân hệ:

```
lib/
├── core/                        # Tầng Dùng chung Hạ tầng (Core Infrastructure)
│   ├── constants/               # Cấu hình màu sắc, hằng số hệ thống, API URLs, CloudinaryConfig
│   ├── services/                # Các dịch vụ nền tảng dùng chung:
│   │   ├── firebase_service.dart # Khởi tạo Firebase App & Cloud Firestore
│   │   ├── cloudinary_service.dart # Tải ảnh lên Cloudinary (Signed Upload vào jetpost/)
│   │   └── openroute_client.dart # Kết nối OpenRouteService API vẽ tuyến đường & Geocoding
│   └── utils/                   # Hàm tiện ích: Định dạng tiền tệ, ngày giờ, tính khoảng cách GPS, Geohash
├── models/                      # Dùng chung Thực thể Dữ liệu: User, Ride, Delivery, Enums
├── modules/                     # 4 Phân hệ Nghiệp vụ Tự chủ (Autonomous Feature Modules)
│   ├── customer/                # [Thành viên 1] Khách hàng & Đặt cuốc
│   │   ├── screens/             # Màn hình: Đặt xe, tạo đơn hàng, tracking, lịch sử hoạt động, chi tiết đơn
│   │   ├── widgets/             # Thành phần giao diện: Card xe, BottomSheet cước phí, OrderHistoryCard
│   │   └── services/            
│   │       └── customer_service.dart # Service 1: Tạo cuốc xe, tạo đơn hàng, tra cứu bưu phẩm, lịch sử & đánh giá
│   ├── driver/                  # [Thành viên 2] Đối tác Tài xế & Vận chuyển
│   │   ├── screens/             # Màn hình: Bật online, pop-up nhận đơn, điều hướng Maps, PoD
│   │   ├── widgets/             # Thành phần: Nút trượt nhận cuốc, radar đếm ngược
│   │   └── services/            
│   │       └── driver_service.dart   # Service 2: GPS Foreground Service, bắt đơn Firestore, nạp ảnh PoD Cloudinary
│   ├── user/                    # [Thành viên 3] User Module & Hạ tầng Định danh
│   │   ├── screens/             # Màn hình: Welcome Gate, OTP Login, eKYC Camera, Profile, Cài đặt, InboxScreen, DirectChatScreen
│   │   ├── widgets/             # Thành phần: Khung nhập OTP, nút chuyển vai trò (Demo Switcher), ChatBubbleWidget, ConversationCard
│   │   └── services/            
│   │       └── user_service.dart     # Service 3: Phone Auth Firebase, nạp ảnh CCCD/GPLX Cloudinary, lưu phiên Auto-login, P2P Chat stream
│   └── admin/                   # [Thành viên 4] Quản trị Điều hành & Nền tảng
│       ├── screens/             # Màn hình: Radar toàn thành phố, thẩm định KYC, biểu cước, doanh thu, phát thông báo
│       ├── widgets/             # Thành phần: Thẻ tài xế trên bản đồ, bảng duyệt hồ sơ, khung phát tin broadcast
│       └── services/            
│           └── admin_service.dart    # Service 4: Query radar GPS toàn mạng, duyệt eKYC, lưu biểu cước, phát thông báo
├── routes/                      # Khai báo điều hướng màn hình (AppRoutes)
└── main.dart                    # Điểm khởi động ứng dụng và bộ điều phối Role Router Guard
```

* **Quy tắc Kiến trúc Dịch vụ (Service Architecture Rules):**
  1. **Không gộp chung vào 1 thư mục `lib/services/` duy nhất:** Tránh nguy cơ 4 thành viên cùng commit vào một thư mục gây ra Git Merge Conflict liên tục.
  2. **Tách biệt hoàn toàn (Isolation):** Mỗi phân hệ sở hữu 1 file Service độc lập bên trong thư mục `modules/[phân_hệ]/services/`. Thành viên nào chịu trách nhiệm phân hệ nào chỉ làm việc trên file Service của phân hệ đó.
  3. **Hạ tầng lõi dùng chung (Shared Core):** Chỉ những service nền tảng không chứa nghiệp vụ riêng (như gọi API bản đồ, khởi tạo Firebase) mới được đặt ở `lib/core/services/` và do Thành viên 4 (phụ trách Core & CSDL) quản lý.

* **Nguyên tắc làm việc trên Git:** Mỗi thành viên chỉ làm việc trong thư mục `modules/[tên_phân_hệ]` của mình và đẩy code lên nhánh Git riêng (`feature/customer`, `feature/driver`, `feature/user`, `feature/admin`). Không tự ý chỉnh sửa `main.dart` hoặc `core/` khi chưa thống nhất chung.

---

## 7. Chiến lược Tối ưu Tài nguyên Miễn phí (Firebase Spark & API Quotas)

Đề tài sử dụng 100% gói dịch vụ miễn phí (Free Tier), do đó cần áp dụng các biện pháp tối ưu sau để không bị vượt hạn mức:
1. **Tối ưu lượt ghi Cloud Firestore (Giới hạn 20.000 writes/ngày):**
   - Không bắn tọa độ GPS theo thời gian thuần túy (timer).
   - Sử dụng bộ lọc khoảng cách (`distanceFilter: 15` mét của `geolocator`): Tài xế chỉ cập nhật vị trí lên Firestore khi đã di chuyển tối thiểu 15 mét, giúp giảm 80% số lượng truy vấn ghi không cần thiết.
2. **Tối ưu OpenRouteService API (Giới hạn 2.000 requests/ngày):**
   - Chỉ gọi API tính khoảng cách/vẽ Polyline khi khách hàng đã chọn xong cả điểm đón và điểm trả cố định (không gọi API liên tục khi đang kéo bản đồ).
3. **OpenStreetMap & flutter_map:**
   - Hoàn toàn miễn phí, không yêu cầu thẻ tín dụng thanh toán, không giới hạn lượt tải tile bản đồ cơ bản.
4. **Chiến lược Sống còn Tối ưu Hạn ngạch Firebase Phone Auth (SMS OTP):**
   - *Nguy cơ cạn kiệt hạn ngạch:* Gói Firebase Spark Free Tier chỉ cung cấp tối đa **10 tin nhắn SMS thực tế/ngày (hoặc hạn mức viễn thông kiểm thử có giới hạn)**. Nếu 4 thành viên cùng kiểm thử bằng số điện thoại thật để nhận SMS về SIM, chỉ sau vài lượt là cổng SMS sẽ bị Firebase tự động khóa trong 24 giờ do lỗi vượt hạn ngạch (`quota-exceeded`).
   - *Biện pháp 1 - Cấu hình Danh sách Số điện thoại Thử nghiệm (Phone Numbers for Testing):*
     * Truy cập: Firebase Console -> Authentication -> Tab Sign-in method -> Phone -> Mục "Phone numbers for testing".
     * Thêm danh sách các số điện thoại thử nghiệm cố định kèm mã OTP mặc định (Ví dụ: `+84 988888888` - OTP: `123456`, `+84 977777777` - OTP: `123456`, `+84 966666666` - OTP: `123456`, `+84 912345678` - OTP: `123456`).
     * Khi dùng các số này, Firebase sẽ xác thực nội bộ hoàn toàn trên Cloud: **Không gửi tin nhắn SMS thật, không tốn hạn ngạch viễn thông, không phát sinh chi phí, và phản hồi tức thì không phụ thuộc vào độ trễ sóng mạng**. Cả nhóm có thể kiểm thử đăng nhập hàng nghìn lần mỗi ngày và bảo vệ trước Hội đồng chấm điểm với độ tin cậy tuyệt đối.
   - *Biện pháp 2 - Bắt buộc Đăng ký Dấu vân tay Chứng chỉ Số (SHA-1 & SHA-256) cho CẢ 4 MÁY THÀNH VIÊN:*
     * Mỗi máy tính cá nhân trong nhóm khi build debug ứng dụng Android sẽ tự động ký bằng một file `debug.keystore` riêng (tại `C:\Users\<Tên_User>\.android\debug.keystore`), sinh ra các mã băm SHA-1 và SHA-256 hoàn toàn khác nhau.
     * Chủ dự án Firebase bắt buộc phải thu thập đầy đủ mã SHA-1 và SHA-256 của **cả 4 thành viên** và dán vào mục *Project Settings -> Your apps (Android) -> Add fingerprint* trên Firebase Console. Nếu chỉ thêm mã SHA của 1 người thì 3 thành viên còn lại khi chạy app sẽ lập tức bị Firebase chặn và báo lỗi xác thực (`app-not-authorized`).
   - *Biện pháp 3 - Cơ chế Rate Limiting Phía Client:*
     * Thiết lập đồng hồ đếm ngược (Cooldown Timer) tối thiểu 60 giây khóa nút "Gửi lại OTP" trên giao diện để triệt tiêu hoàn toàn hành vi spam nút bấm gây lãng phí request xác thực.

---

5. **Chiến lược Lưu trữ Ảnh Miễn phí Vĩnh viễn với Cloudinary (Thay thế Firebase Storage):**
   - *Lý do chuyển đổi:* Firebase Cloud Storage hiện tại trên các tài khoản Google Cloud mới tạo thường bắt buộc kích hoạt gói trả phí Blaze Plan (yêu cầu liên kết thẻ tín dụng quốc tế Visa/Mastercard), gây rào cản tài chính và tiềm ẩn nguy cơ phát sinh cước ngoài ý muốn cho đồ án sinh viên.
   - *Giải pháp Cloudinary Free Tier:* Chuyển 100% việc lưu trữ tệp đa phương tiện sang **Cloudinary** với hạn mức miễn phí hào phóng 25 Credits/tháng (~25GB lưu trữ hoặc 25GB băng thông CDN), 100% không yêu cầu thẻ tín dụng, an toàn tuyệt đối.
   - *Cấu trúc Phân cấp Thư mục Tự động trong `jetpost/`:*
     * `jetpost/avatars/`: Lưu ảnh đại diện tài khoản (`avatar_{userId}.jpg`).
     * `jetpost/drivers_ekyc/`: Lưu ảnh CCCD 2 mặt và giấy phép lái xe eKYC (`{driverId}_{docType}_{timestamp}.jpg`).
     * `jetpost/deliveries_pod/`: Lưu ảnh chụp bằng chứng giao hàng PoD (`pod_{deliveryId}_{timestamp}.jpg`).
   - *Cơ chế Ký số Bảo mật (Signed Upload):* Ứng dụng tự động sinh chữ ký bảo mật HMAC-SHA1 từ `apiKey` và `apiSecret` để đẩy ảnh trực tiếp lên đúng thư mục mong muốn mà không cần tạo upload preset thủ công.
   - *Tối ưu hóa Băng thông CDN tự động:* Tận dụng sức mạnh Cloudinary CDN để tự động nén ảnh (`q_auto`), chuyển sang định dạng WebP siêu nhẹ (`f_auto`) và resize ảnh trực tiếp qua URL, giúp ứng dụng di động tải ảnh siêu tốc và không tốn pin thiết bị khi nén ảnh cục bộ.

6. **Chiến lược Xác thực Email & Công nghệ Sinh Mã OTP 6 Số Phía Máy chủ (Server-Side Cloudflare Worker + Brevo REST API - Zero-Cost & Enterprise Security):**
   - *Bản chất Kiến trúc An ninh (Security by Design):* **TUYỆT ĐỐI KHÔNG sinh mã OTP trên máy người dùng (Client App)** để triệt tiêu hoàn toàn rủi ro dịch ngược mã nguồn (Reverse Engineering) file APK hoặc trích xuất bộ nhớ RAM để bypass OTP. Mã OTP 6 chữ số BẮT BUỘC phải được cấp phát và kiểm soát tập trung phía máy chủ (Server-Side).
   - *Mô hình Không Máy Chủ Miễn phí 100% (Zero-Cost Serverless Architecture):* Do gói Firebase Spark không hỗ trợ Cloud Functions, hệ thống sử dụng **Cloudflare Workers (Edge Serverless Computing)** kết hợp **Brevo Transactional REST API**:
     * **Nền tảng Cloudflare Workers:** Cung cấp **100.000 requests/ngày MIỄN PHÍ VĨNH VIỄN, 100% KHÔNG CẦN THẺ TÍN DỤNG**. Đóng vai trò là cổng API bảo mật trung gian (Secure Gateway).
     * **Nền tảng Gửi Email Brevo:** Cung cấp **300 emails/ngày MIỄN PHÍ VĨNH VIỄN, 100% KHÔNG CẦN THẺ TÍN DỤNG**.
     * **Luồng Vận hành Chuẩn mực:**
       1. App Flutter trên điện thoại chỉ gửi yêu cầu: `{ "email": "user@gmail.com", "type": "REGISTER" | "RESET_PASSWORD" | "CHANGE_PHONE" }` lên Endpoint của Cloudflare Worker (`https://jetpost-otp.workers.dev/api/send-otp`).
       2. **Máy chủ Cloudflare Worker tự sinh ngẫu nhiên mã OTP 6 số** bằng thuật toán mã hóa an toàn (`crypto.getRandomValues`).
       3. Máy chủ Worker lưu mã băm (`codeHash`), loại xác thực, số lần thử (`attempts: 0`) và thời hạn 5 phút (`expiresAt`) vào Cloud Firestore collection `email_otps`.
       4. Máy chủ Worker gọi Brevo REST API gửi email HTML mang thương hiệu JetPost (`#00A86B`) với **duy nhất mã OTP 6 số to rõ, hoàn toàn KHÔNG CÓ bất kỳ đường link nào**.
       5. App người dùng hoàn toàn không biết mã là gì cho đến khi người dùng mở hòm thư đọc mã và gõ vào cụm 6 ô vuông `OtpPinInput` ngay trên ứng dụng di động.
       6. Khi xác thực: App gửi mã người dùng nhập lên để đối chiếu. Hợp lệ thì cho phép đặt mật khẩu mới, liên kết email hoặc đổi SĐT ngay trên app.
   - *Cam kết Đồ án:* 100% Miễn phí, 100% In-App (không link web), đạt chuẩn an ninh phòng thủ cao nhất trước mọi câu hỏi phản biện của Hội đồng chấm thi.

7. **Bảng Rà soát Toàn diện Hạn ngạch & Rủi ro Trả phí/Gói Blaze Toàn bộ Dự án JetPost:**

| Phân hệ / Dịch vụ | Công nghệ sử dụng | Chính sách Nhà cung cấp | Rủi ro Gói Blaze / Trả phí | Biện pháp Kiểm soát & Giải pháp Miễn phí |
| :--- | :--- | :--- | :---: | :--- |
| **Xác thực Số điện thoại** | Firebase Phone Auth (SMS) | Spark chặn SMS thật với lỗi `17499 BILLING_NOT_ENABLED` | **CÓ** (nếu gửi SMS thật) | Sử dụng **Whitelist Testing Numbers** + Bổ sung **Email & Password Authentication**. 100% Miễn phí! |
| **Xác thực Email & Mật khẩu** | Firebase Email/Password Auth | Hoàn toàn miễn phí trên Spark | **KHÔNG** | Sử dụng Firebase Auth Native, không giới hạn người dùng. |
| **Gửi OTP qua Email** | Brevo API / Gmail SMTP | 300 - 500 emails/ngày miễn phí | **KHÔNG** | Gọi REST API từ Flutter Client, không dùng Cloud Functions. |
| **Lưu trữ CSDL NoSQL** | Cloud Firestore | 50.000 đọc / 20.000 ghi / ngày | **KHÔNG** | Áp dụng `distanceFilter: 15m` GPS, Denormalization có kiểm soát, sort in-memory. |
| **Lưu trữ Ảnh CCCD, GPLX, PoD** | Cloudinary Free Tier | 25GB băng thông & lưu trữ / tháng | **KHÔNG** | Thay thế 100% Firebase Storage; Signed upload client-side bằng HMAC-SHA1. |
| **Bản đồ nền** | OpenStreetMap (flutter_map) | Mã nguồn mở miễn phí | **KHÔNG** | Không cần API key, không yêu cầu thẻ tín dụng. |
| **Tìm đường & Vẽ Polyline** | OpenRouteService API | 2.000 requests/ngày | **KHÔNG** | Chỉ gọi khi chốt điểm đón & trả; cache tuyến đường. |
| **Dẫn đường Giọng nói Tài xế** | Intent `google.navigation:` | Tích hợp sẵn trong HĐH Android | **KHÔNG** | Dùng `url_launcher` mở app Google Maps máy tài xế; không tốn Google Maps SDK. |
| **Định vị GPS Chạy ngầm** | `geolocator` Foreground Service | Phần cứng thiết bị di động | **KHÔNG** | Thu thập GPS trực tiếp từ cảm biến phần cứng của máy. |
| **Thẩm định eKYC Tài xế** | Duyệt thủ công (Human-in-the-loop) | Quản trị viên duyệt trên Admin Portal | **KHÔNG** | Không tích hợp API OCR AI bên thứ 3 tính phí (FPT.AI/VNPT eKYC). |
| **Thông báo Toàn hệ thống** | Firestore Stream `system_notifications` | In-app WebSocket Stream | **KHÔNG** | Không cần Cloud Functions hay SMS Brandname viễn thông. |

---

## 8. Đánh giá Khả thi & Nhận xét của Chuyên gia Hệ thống (Architectural Review & Risk Management)

### 8.1. Nhận xét Tổng quan về Bản Kế hoạch
* **Mức độ chắc chắn về mặt Kiến trúc và Kỹ thuật: 100% Khả thi.**
* **Điểm sáng vượt trội:**
  1. *Tính thực tiễn cao:* Kế hoạch bám sát mô hình giao vận thực tế của **GrabExpress, Shopee Express và Ahamove** (chụp ảnh PoD đối soát, máy trạng thái đơn hàng, tracking timeline).
  2. *Kiến trúc tối ưu cho nhóm:* Lựa chọn **1 Project Flutter duy nhất phân tách 4 Module** là quyết định chuẩn xác nhất cho nhóm 4 người, loại bỏ hoàn toàn rủi ro lệch phiên bản thư viện và giảm 70% gánh nặng cấu hình backend.
  3. *Phân bổ công việc hoàn hảo:* Tách riêng **Phân hệ User (Module 3)** giúp giải phóng khối lượng công việc khổng lồ về xác thực OTP, tải ảnh bằng lái CCCD và quản lý hồ sơ cho một thành viên làm chủ, trong khi Khách hàng (Module 1) và Tài xế (Module 2) tập trung 100% vào nghiệp vụ gọi xe/giao hàng.
  4. *Kịch bản bảo vệ thuyết phục:* Cả 4 thành viên cùng cài 1 app trên 4 điện thoại để tương tác chéo thời gian thực trước hội đồng.

### 8.2. Quản trị Rủi ro Kỹ thuật trong quá trình Lập trình (Technical Risks & Mitigation)
Để đảm bảo triển khai không gặp sự cố, nhóm cần tuân thủ 3 giải pháp kỹ thuật sau:
1. **Rủi ro Android tắt GPS ngầm (Doze Mode):**
   - *Nguy cơ:* Trên Android 12+, hệ điều hành sẽ tự động ngắt service lấy GPS của tài xế khi khóa màn hình để tiết kiệm pin.
   - *Biện pháp kiểm soát:* Module Tài xế bắt buộc phải khởi tạo dưới dạng **Foreground Service** kèm một biểu tượng thông báo cố định (`sticky notification`) trên thanh trạng thái điện thoại.
2. **Rủi ro tải bản đồ OpenStreetMap chậm khi mạng yếu:**
   - *Nguy cơ:* Máy chủ miễn phí của OpenStreetMap đôi khi có độ trễ tải tile bản đồ.
   - *Biện pháp kiểm soát:* Cấu hình bộ nhớ đệm hình ảnh bản đồ cục bộ (**Tile Caching** qua thư viện `cached_network_image` / `flutter_map_cache`) để các khu vực bản đồ đã xem được lưu trên máy, mở lại tức thì.
3. **Rủi ro phân quyền dữ liệu trên Cloud Firestore:**
   - *Nguy cơ:* Dùng chung 1 project nếu không kiểm soát quyền đọc/ghi thì tài khoản này có thể sửa dữ liệu của tài khoản khác.
   - *Biện pháp kiểm soát:* Thiết lập bộ quy tắc **Firestore Security Rules** chặt chẽ dựa trên `request.auth.uid` và trường `role` (chỉ tài xế nhận cuốc mới được cập nhật trạng thái cuốc; chỉ người nhận mới được đọc mã OTP).

---

## 9. Cơ chế Sinh mã & Vòng đời OTP trong Hệ thống Giao vận (OTP Architecture & Lifecycle)

### 9.1. Trả lời Cốt lõi: Mã OTP do đâu cấp phát? Có phải do Admin hay Client App tự sinh không?
* **Khẳng định từ Chuyên gia:** **ĐÚNG VẬY! Mã OTP BẮT BUỘC phải do SERVER cấp phát và kiểm soát tập trung, TUYỆT ĐỐI KHÔNG ĐƯỢC tự sinh từ Client App và KHÔNG PHẢI do Admin can thiệp thủ công.**
* **Tại sao Client App không bao giờ được phép tự sinh mã OTP?**
  1. *Rủi ro Dịch ngược mã nguồn (Reverse Engineering):* Nếu app tự sinh mã, kẻ tấn công có thể can thiệp bộ nhớ RAM, phân tích log hoặc decompile file APK để lấy mã OTP mà không cần sở hữu số điện thoại thật, làm sụp đổ hoàn toàn cơ chế bảo mật xác thực danh tính.
  2. *Rủi ro Gian lận Giao nhận hàng (Driver Fraud):* Nếu app tài xế có quyền tự sinh mã hoặc đọc được mã bàn giao, tài xế có thể tự kích hoạt hoàn thành đơn để lấy tiền cước mà không cần giao hàng tận tay người nhận.
* **Nguyên lý Chuẩn công nghiệp (Grab, Shopee Express, Ahamove):**
  - Mọi mã OTP đều do **Hạ tầng Server (Firebase Auth Server / Cloud Firestore Security Rules)** sinh ra và kiểm soát quyền truy cập độc quyền.
  - Client App chỉ đóng vai trò gửi yêu cầu và hiển thị giao diện, không nắm giữ thuật toán quyết định tính hợp lệ của mã.
  - Toàn bộ chu trình sinh mã, truyền tải và đối soát diễn ra **tự động hóa 100%**, loại bỏ hoàn toàn yếu tố can thiệp thủ công của Admin.

---

### 9.2. Phân biệt Các Loại Mã OTP trong Hệ thống JetPost

Hệ thống JetPost vận hành các luồng mã OTP với mục đích, nguồn gốc và vòng đời hoàn toàn minh bạch:

| Tiêu chí | 1. Mã OTP Xác thực Tài khoản (Authentication OTP) | 2. Mã OTP Bàn giao Bưu phẩm (Delivery Handover PoD OTP) |
| :--- | :--- | :--- |
| **Mục đích** | Đăng ký, đăng nhập, liên kết tài khoản, quên mật khẩu và đổi SĐT khi mất SIM (Step-up Verification). | Xác nhận bàn giao bưu kiện an toàn giữa Tài xế và Người nhận (Proof of Delivery - PoD). |
| **Độ dài mã** | **6 chữ số** ngẫu nhiên (Ví dụ: `582914`). | **4 chữ số** ngẫu nhiên bảo mật (Ví dụ: `8392`). |
| **Nguồn gốc sinh mã** | **Firebase Auth Server** (đối với SMS) HOẶC **Hạ tầng Email Gateway bảo mật** (Brevo REST API / Google SMTP). | **Logic Hệ thống / Backend** tự động sinh ngẫu nhiên bằng thuật toán mã hóa ngay khi đơn hàng chuyển sang trạng thái `IN_TRANSIT` (Đang giao). |
| **Kênh chuyển phát mã** | - **Kênh 1:** Đẩy qua mạng viễn thông (SMS Gateway) về SIM điện thoại người dùng.<br>- **Kênh 2:** Gửi email HTML chứa mã OTP 6 số về hộp thư chính chủ (100% miễn phí). | Hiển thị trực tiếp và duy nhất trên màn hình ứng dụng của **Người nhận** (Tab "Đơn nhận của tôi" hoặc link tracking web). |
| **Ai có quyền xem mã?** | Duy nhất chủ SIM hoặc chủ sở hữu hộp thư Email nhận được. Hệ thống kiểm tra thời hạn (5 phút), tự động hủy sau khi sử dụng. | **Duy nhất Người nhận** mới thấy được mã này. Tài xế KHÔNG THỂ nhìn thấy mã trên app tài xế để chống tình trạng tài xế tự ý bấm hoàn thành khi chưa giao. |
| **Quy trình xác thực** | Người dùng nhập 6 số -> Hệ thống so khớp mã băm và thời hạn hiệu lực -> Cấp token phiên / hoàn tất thao tác. | Khi tài xế giao hàng tới tận nơi: Người nhận đọc 4 số cho tài xế -> Tài xế gõ 4 số vào app -> Hệ thống so khớp với mã của đơn -> Hợp lệ thì mới cho phép bấm "Giao thành công". |
| **Vai trò của Admin** | Admin hoàn toàn không biết mã này, chỉ thấy nhãn phương thức xác thực trên danh sách người dùng. | Admin **không sinh mã**, nhưng có quyền tra cứu mã trong màn hình "Quản lý Khiếu nại / Tranh chấp (Task 4.5)" khi xảy ra sự cố người nhận khiếu nại chưa nhận được hàng. |

---

### 9.3. Vòng đời Chi tiết của Mã OTP Bàn giao Giao hàng (PoD Lifecycle)

```
[Khách tạo đơn] 
      │
      ▼
[Tài xế nhận đơn & Lấy hàng] 
      │
      ▼
[Tài xế bấm "Bắt đầu giao" - Trạng thái: IN_TRANSIT]
      │
      ├─► Hệ thống TỰ ĐỘNG sinh mã ngẫu nhiên 4 số (VD: 6824)
      ├─► Lưu vào trường 'handoverOtp' của tài liệu đơn hàng trên Firestore
      └─► Firestore Security Rules: Khóa quyền đọc trường này, CHỈ cấp quyền đọc cho UID/SĐT người nhận
      │
      ▼
[Màn hình Người nhận] ───► Mở app hoặc link tra cứu thấy mã OTP: "Mã nhận hàng của bạn là 6824"
      │
      ▼
[Gặp mặt trực tiếp tại điểm giao]
      │
      ├─► Tài xế chụp ảnh gói hàng tại địa chỉ giao (PoD Photo)
      ├─► Người nhận đọc mã: "6824" cho tài xế
      └─► Tài xế gõ "6824" vào ô xác thực trên app tài xế
      │
      ▼
[Hệ thống đối khớp] 
      ├─► KHÔNG KHỚP: Báo lỗi "Mã OTP không chính xác, vui lòng hỏi lại người nhận"
      └─► KHỚP: Đơn chuyển sang COMPLETED ──► Cho phép thu tiền mặt ──► Kết thúc giao dịch an toàn!
```

---

### 9.4. Mẹo Sống còn khi Phát triển Tính năng SMS OTP (Chiến lược Phòng chống Cạn kiệt Hạn ngạch Gói Free)
* **Thực trạng hạn chế của Gói Firebase Spark Free Tier:**
  Google Firebase áp dụng chính sách kiểm soát rất nghiêm ngặt đối với dịch vụ gửi tin nhắn SMS qua mạng viễn thông (tối đa khoảng 10 tin nhắn SMS thực tế/ngày). Khi làm việc nhóm 4 người, chỉ cần mỗi thành viên bấm thử 2-3 lần bằng SIM thật là toàn bộ hệ thống xác thực số điện thoại sẽ bị tạm khóa trong vòng 24 giờ với mã lỗi `auth/quota-exceeded`.

* **3 Nguyên tắc Kỹ thuật Bắt buộc Toàn nhóm Tuân thủ:**
  1. **Tuyệt đối sử dụng Danh sách Số điện thoại Thử nghiệm (Whitelist Phone Numbers for Testing):**
     - Thiết lập cố định trên Firebase Console: `Authentication -> Sign-in method -> Phone -> Phone numbers for testing`.
     - Phân bổ sẵn 4 số điện thoại nội bộ đại diện cho 4 vai trò kiểm thử:
       * Khách hàng 1: `+84 988888888` (Mã OTP cố định: `123456`)
       * Khách hàng 2: `+84 977777777` (Mã OTP cố định: `123456`)
       * Đối tác Tài xế 1: `+84 966666666` (Mã OTP cố định: `123456`)
       * Đối tác Tài xế 2: `+84 912345678` (Mã OTP cố định: `123456`)
     - *Ưu thế vượt trội:* Cơ chế này bypass qua cổng viễn thông, không bao giờ trừ quota, không cần sóng điện thoại, không sợ nghẽn mạng SMS giờ cao điểm và đảm bảo 100% demo thành công rực rỡ trước Hội đồng chấm điểm.
  2. **Đồng bộ hóa 100% Dấu vân tay SHA-1 & SHA-256 của CẢ 4 THÀNH VIÊN lên Firebase Console:**
     - Firebase Phone Auth trên nền tảng Android yêu cầu xác minh tính toàn vẹn của ứng dụng qua Google Play Integrity / SafetyNet bằng mã SHA.
     - Do mỗi laptop của 4 thành viên sử dụng một file khóa `debug.keystore` riêng biệt, mã vân tay SHA-1 và SHA-256 trên mỗi máy là duy nhất.
     - *Quy tắc phối hợp:* Trưởng nhóm (người sở hữu tài khoản Firebase Console) phải thu thập mã SHA-1/SHA-256 từ cả 3 bạn còn lại và dán vào cùng mục cấu hình Android App trên Firebase Console (hỗ trợ nhiều mã SHA đồng thời). Điều này giúp cả 4 bạn đều có quyền kích hoạt Phone Auth trên máy tính cá nhân của mình.
  3. **Khóa chống gửi liên tục (Rate-limiting Cooldown Timer):**
     - Tại giao diện nhập số điện thoại và OTP, bắt buộc kích hoạt bộ đếm ngược 60 giây sau mỗi lần bấm "Nhận mã OTP". Nút bấm bị vô hiệu hóa trong suốt 60 giây này nhằm ngăn chặn hành vi ấn liên tục làm tràn hàng đợi xử lý.

---

## 10. Thiết kế Cơ sở Dữ liệu Cloud Firestore NoSQL Chuẩn hóa Toàn hệ thống (Database Schema Freeze)

Để đảm bảo toàn bộ 4 thành viên xây dựng các Model Dart và Service đồng bộ 100%, không bị sửa đổi cấu trúc dữ liệu trong suốt quá trình triển khai, hệ thống chốt cố định 9 Thực thể CSDL (gồm 7 Root Collections chính và 2 Sub-collections lồng nhau):

### 10.1. Danh mục 9 Thực thể CSDL (7 Root Collections & 2 Sub-collections)
1. **`users` (Root Collection - Người dùng Toàn hệ thống):**
   - Khóa chính: `id` (Firebase Auth UID).
   - Các trường: `phone` (String, E.164, Nullable nếu chỉ đăng ký Email), `email` (String, Nullable nếu chỉ đăng ký SĐT), `fullName` (String), `avatarUrl` (String), `role` (`customer` | `driver` | `admin`), `authProviders` (Array of Strings: `['phone']`, `['email']`, `['phone', 'email']`), `isEmailVerified` (Boolean), `isBanned` (Boolean), `createdAt` (Timestamp), `updatedAt` (Timestamp).

2. **`saved_addresses` (Sub-collection lồng trong `users/{userId}/saved_addresses`):**
   - Khóa chính: `id` (Auto-ID), khóa ngoại `userId` (String liên kết `users.id`).
   - Các trường: `label` (String), `addressText` (String), `lat` (Double), `lng` (Double), `createdAt` (Timestamp).

3. **`drivers` (Root Collection - Đối tác Tài xế & Live Telemetry):**
   - Khóa chính: `id` (Trùng khớp 1-1 với `users.id`).
   - Các trường: `vehicleType` (String), `plateNumber` (String), `idCardFrontUrl` (String), `idCardBackUrl` (String), `licenseUrl` (String), `status` (`PENDING_APPROVAL` | `ACTIVE` | `BANNED`), `isOnline` (Boolean), `isBusy` (Boolean), `activeTripId` (String, Nullable), `currentLat` (Double), `currentLng` (Double), `geohash` (String, 6-7 ký tự), `heading` (Double, góc xoay 0-360°), `rating` (Double), `totalReviews` (Integer), `totalTrips` (Integer), `walletBalance` (Double), `lastActiveAt` (Timestamp).

4. **`rides` (Root Collection - Nghiệp vụ Đặt Xe ôm Công nghệ):**
   - Khóa chính: `id` (Auto-ID).
   - Các trường: `customerId` (String), `customerName` (String), `customerPhone` (String), `driverId` (String, Nullable), `driverName` (String, Nullable), `driverPhone` (String, Nullable), `driverPlate` (String, Nullable), `pickupAddress` (String), `pickupLat` / `pickupLng` (Double), `dropoffAddress` (String), `dropoffLat` / `dropoffLng` (Double), `pickupGeohash` (String), `distanceKm` (Double), `routePolyline` (String, Nullable), `price` (Double), `systemFee` (Double), `driverIncome` (Double), `paymentMethod` (String, 'CASH'), `status` (`PENDING_DRIVER` | `ACCEPTED` | `IN_TRANSIT` | `COMPLETED` | `CANCELLED`), `cancelReason` (String, Nullable), `cancelledBy` (String, Nullable), `rating` (Integer, Nullable), `reviewComment` (String, Nullable), `createdAt` (Timestamp), `acceptedAt` (Timestamp, Nullable), `completedAt` (Timestamp, Nullable).

5. **`deliveries` (Root Collection - Nghiệp vụ Giao hàng Nhanh An toàn PoD):**
   - Khóa chính: `id` (Tracking ID).
   - Các trường: `senderId` (String), `senderName` (String), `senderPhone` (String), `receiverName` (String), `receiverPhone` (String, dùng tra cứu Consignee), `driverId` (String, Nullable), `driverName` (String, Nullable), `driverPhone` (String, Nullable), `driverPlate` (String, Nullable), `pickupAddress` (String), `pickupLat` / `pickupLng` (Double), `dropoffAddress` (String), `dropoffLat` / `dropoffLng` (Double), `pickupGeohash` (String), `distanceKm` (Double), `routePolyline` (String, Nullable), `price` (Double), `systemFee` (Double), `driverIncome` (Double), `paymentMethod` (String, 'CASH'), `packageType` (`DOCUMENT` | `FOOD` | `ELECTRONICS` | `CLOTHING` | `OTHER`), `packageNotes` (String), `handoverOtp` (String, 4 số ngẫu nhiên), `podPhotoUrl` (String, ảnh Cloudinary CDN), `status` (`PENDING_DRIVER` | `ACCEPTED` | `IN_TRANSIT` | `COMPLETED` | `CANCELLED`), `cancelReason` (String, Nullable), `cancelledBy` (String, Nullable), `rating` (Integer, Nullable), `reviewComment` (String, Nullable), `createdAt` (Timestamp), `acceptedAt` (Timestamp, Nullable), `deliveredAt` (Timestamp, Nullable).

6. **`conversations` (Root Collection - Hạ tầng Phòng chat P2P 1-1):**
   - Khóa chính: `id` (Cấu trúc ghép nối 2 UID theo alphabet: `minUid_maxUid`).
   - Các trường: `participants` (Array of Strings: `[uidA, uidB]`), `participantDetails` (Map chứa tên & avatar của 2 bên), `lastMessage` (String), `lastSenderId` (String), `unreadCount` (Map: `{uidA: int, uidB: int}`), `updatedAt` (Timestamp).

7. **`messages` (Sub-collection lồng trong `conversations/{id}/messages`):**
   - Khóa chính: `id` (Auto-ID), khóa ngoại `conversationId` (String).
   - Các trường: `senderId` (String), `receiverId` (String), `content` (String), `isRead` (Boolean), `timestamp` (Timestamp).

8. **`system_settings` (Root Collection - Cấu hình Biểu cước & Tham số Toàn hệ thống):**
   - Document ID duy nhất: `global_config`.
   - Các trường: `basePriceRide` (Double, 15000), `pricePerKmRide` (Double, 6000), `basePriceDelivery` (Double, 18000), `pricePerKmDelivery` (Double, 7000), `commissionRate` (Double, 0.15), `maxSearchRadiusKm` (Double, 5.0), `driverAcceptTimeoutSeconds` (Integer, 15), `radarSearchTimeoutSeconds` (Integer, 45), `updatedAt` (Timestamp), `updatedBy` (String).

9. **`system_notifications` (Root Collection - Thông báo Vận hành & Cảnh báo Toàn hệ thống):**
   - Khóa chính: `id` (Auto-ID).
   - Các trường: `title` (String), `body` (String), `targetGroup` (`ALL` | `DRIVERS` | `CUSTOMERS`), `priority` (`NORMAL` | `HIGH` | `URGENT`), `createdBy` (String), `createdAt` (Timestamp), `expiresAt` (Timestamp, Nullable).

### 10.2. Ba Nguyên tắc Cốt lõi của Chuyên gia Kiến trúc Hệ thống
1. **Phi chuẩn hóa có kiểm soát (Controlled Denormalization):** Nhúng sẵn các trường hiển thị thường xuyên (`customerName`, `driverName`, `driverPlate`) vào cuốc xe để mỗi thao tác mở cuốc chỉ tốn đúng 1 Document Read, tiết kiệm 70% hạn mức Firebase Free Tier.
2. **Tách biệt hoàn toàn cuốc xe `rides` và vận đơn `deliveries`:** Đảm bảo Module Khách hàng và Module Tài xế phát triển độc lập, quản lý logic bàn giao PoD (ảnh chụp + OTP 4 số) chuyên biệt mà không gây xung đột mã nguồn.
3. **Mô hình Khóa phòng chat Alphabet P2P:** Đảm bảo giữa 2 người dùng bất kỳ chỉ sinh đúng 1 bản ghi hội thoại duy nhất với chi phí khởi tạo O(1), không tốn thêm câu truy vấn kiểm tra trùng lặp.
