import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/saved_address_model.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../user/services/user_service.dart';
import '../services/customer_service.dart';
import '../widgets/quick_address_chips.dart';
import '../widgets/service_selection_card.dart';
import 'consignee_tracking_screen.dart';
import 'customer_activity_screen.dart';
import 'delivery_booking_screen.dart';
import 'live_tracking_screen.dart';
import 'ride_booking_screen.dart';

/// Màn hình chính của Phân hệ Khách Hàng (Customer Home Screen)
/// Tích hợp BottomNavigationBar 3 tab: Trang chủ, Hoạt động & Đơn nhận.
/// Bản đồ OSM nền, thanh tìm kiếm nhanh, Quick Chips địa chỉ quen thuộc
/// và 2 dịch vụ cốt lõi: Xe ôm JetBike & Giao hàng JetExpress.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentTabIndex = 0;
  final MapController _mapController = MapController();

  UserModel? _currentUser;
  LatLng _currentLocation = const LatLng(21.0285, 105.8542);
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndLocation();
  }

  Future<void> _loadUserAndLocation() async {
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await UserService.instance.getUserProfile(uid);
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _isLoadingUser = false;
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  void _onQuickAddressTapped(SavedAddressModel addr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideBookingScreen(
          initialDropoff: LatLng(addr.lat, addr.lng),
          initialDropoffAddress: addr.addressText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.electric_moped_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              AppStrings.appName,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Thông báo',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          // Nút Hộp thư Chat P2P
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Tin nhắn P2P',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.messagesInbox);
            },
          ),
          // Nút Cài đặt ứng dụng
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.appSettings);
            },
          ),
          // Avatar khách hàng
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.userProfile,
                ).then((_) => _loadUserAndLocation());
              },
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primaryLight,
                backgroundImage:
                    _currentUser?.avatarUrl != null &&
                        _currentUser!.avatarUrl!.isNotEmpty
                    ? NetworkImage(
                        CloudinaryService.instance.getOptimizedUrl(
                          _currentUser!.avatarUrl!,
                          width: 80,
                          height: 80,
                        ),
                      )
                    : null,
                child:
                    _currentUser?.avatarUrl == null ||
                        _currentUser!.avatarUrl!.isEmpty
                    ? Text(
                        _currentUser != null &&
                                _currentUser!.fullName.isNotEmpty
                            ? _currentUser!.fullName[0].toUpperCase()
                            : 'K',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // TAB 0: TRANG CHỦ ĐẶT XE & GIAO HÀNG
          _buildHomeDashboard(isDark),

          // TAB 1: HOẠT ĐỘNG & LỊCH SỬ CHUYẾN ĐI
          const CustomerActivityScreen(showAppBar: false),

          // TAB 2: ĐƠN HÀNG GỬI CHO TÔI (CONSIGNEE TRACKING)
          const ConsigneeTrackingScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
          AppLogger.navigation('CustomerHome', 'Tab $index');
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark
            ? AppColors.textMutedDark
            : AppColors.textSecondaryLight,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Trang Chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Hoạt Động',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.markunread_mailbox_outlined),
            activeIcon: Icon(Icons.markunread_mailbox_rounded),
            label: 'Đơn Nhận',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard(bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final userName = _currentUser?.fullName ?? 'Bạn';

    return Stack(
      children: [
        // 1. BẢN ĐỒ OSM NỀN
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.jet_post',
              maxZoom: 18,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. KHỐI NỘI DUNG CUỘN Ở PHÍA TRƯỚC
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: bottomPadding + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Khung tìm kiếm & Lời chào khách hàng
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào, $userName! 👋',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Hôm nay bạn muốn đi đâu hoặc gửi hàng?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Thanh tìm kiếm nhanh điểm đến (Chạm vào mở RideBookingScreen)
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RideBookingScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Bạn muốn đi đâu hôm nay?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Action Chips: Nhà riêng / Cơ quan
                QuickAddressChips(
                  userId: _currentUser?.id ?? '',
                  onAddressSelected: _onQuickAddressTapped,
                ),
                const SizedBox(height: 16),

                // BANNER CUỐC XE ĐANG CHẠY (NẾU CÓ)
                if (_currentUser != null)
                  _buildOngoingTripBanner(_currentUser!.id, isDark),

                // DANH MỤC 2 DỊCH VỤ CỐT LÕI
                Row(
                  children: [
                    const Icon(
                      Icons.dashboard_customize_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DỊCH VỤ CỐT LÕI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 1. Thẻ Đặt xe ôm JetBike
                ServiceSelectionCard(
                  title: 'Xe Ôm JetBike',
                  subtitle:
                      'Di chuyển linh hoạt, né kẹt xe, giá cước cố định minh bạch',
                  icon: Icons.electric_moped_rounded,
                  primaryColor: AppColors.primary,
                  badgeText: 'Tiết kiệm & Siêu tốc',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RideBookingScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Thẻ Giao hàng JetExpress
                ServiceSelectionCard(
                  title: 'Giao Hàng JetExpress',
                  subtitle:
                      'Giao nhận bưu kiện, tài liệu, bảo mật an toàn qua Mã OTP 4 số',
                  icon: Icons.local_shipping_rounded,
                  primaryColor: AppColors.secondary,
                  badgeText: 'Hỏa tốc & Bảo mật OTP',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeliveryBookingScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Banner cuốc xe và đơn giao hàng đang hoạt động của khách hàng
  Widget _buildOngoingTripBanner(String customerId, bool isDark) {
    return StreamBuilder<List<RideModel>>(
      stream: CustomerService.instance.streamCustomerRides(customerId),
      builder: (context, rideSnap) {
        return StreamBuilder<List<DeliveryModel>>(
          stream: CustomerService.instance.streamCustomerDeliveries(customerId),
          builder: (context, deliverySnap) {
            final activeRides = (rideSnap.data ?? [])
                .where(
                  (r) =>
                      r.status == RideStatus.pendingDriver ||
                      r.status == RideStatus.accepted ||
                      r.status == RideStatus.arrivedPickup ||
                      r.status == RideStatus.inProgress,
                )
                .toList();

            final activeDeliveries = (deliverySnap.data ?? [])
                .where(
                  (d) =>
                      d.status == DeliveryStatus.pendingDriver ||
                      d.status == DeliveryStatus.accepted ||
                      d.status == DeliveryStatus.pickedUp ||
                      d.status == DeliveryStatus.inTransit,
                )
                .toList();

            if (activeRides.isEmpty && activeDeliveries.isEmpty) {
              return const SizedBox.shrink();
            }

            // Ưu tiên hiển thị cuốc xe ôm nếu có
            if (activeRides.isNotEmpty) {
              final ride = activeRides.first;
              final isSearching = ride.status == RideStatus.pendingDriver;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LiveTrackingScreen.ride(rideId: ride.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSearching
                              ? [
                                  const Color(0xFF007A4D),
                                  const Color(0xFF004D30),
                                ]
                              : [
                                  const Color(0xFF00A86B),
                                  const Color(0xFF007A4D),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              isSearching
                                  ? Icons.radar_rounded
                                  : Icons.two_wheeler_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSearching
                                      ? 'Xe ôm JetBike: Đang tìm tài xế...'
                                      : 'Cuốc xe ôm đang diễn ra!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSearching
                                      ? 'Đã vào hàng chờ • Chạm để theo dõi tiến trình'
                                      : 'Tài xế: ${ride.driverName ?? 'Đang kết nối...'} • Chạm để theo dõi',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // Hiển thị đơn giao hàng nếu có
            final delivery = activeDeliveries.first;
            final isSearching = delivery.status == DeliveryStatus.pendingDriver;
            final count = activeDeliveries.length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (count > 1) {
                      setState(() => _currentTabIndex = 1);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveTrackingScreen.delivery(
                            deliveryId: delivery.id,
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSearching
                            ? [const Color(0xFFC75B00), const Color(0xFF8F3F00)]
                            : [AppColors.secondary, const Color(0xFFC75B00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(
                            isSearching
                                ? Icons.hourglass_top_rounded
                                : Icons.local_shipping_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                count > 1
                                    ? 'Bạn có $count đơn giao hàng đang xử lý!'
                                    : (isSearching
                                          ? 'Giao hàng: Đang tìm tài xế (${delivery.id.substring(0, 8).toUpperCase()})'
                                          : 'Đơn giao hàng đang vận chuyển!'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                count > 1
                                    ? 'Chạm để xem danh sách chi tiết các đơn'
                                    : (isSearching
                                          ? 'Đang trong danh sách chờ • Chạm để theo dõi'
                                          : 'Tài xế: ${delivery.driverName ?? 'Đang giao...'} • Chạm để theo dõi'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
