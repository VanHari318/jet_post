import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../services/customer_service.dart';
import '../widgets/order_history_card.dart';
import '../widgets/trip_rating_dialog.dart';
import 'order_detail_screen.dart';
import '../../../routes/app_routes.dart';

/// Màn hình Trung Tâm Hoạt Động & Lịch Sử Cuốc Xe (Task 1.8)
/// Phân loại 2 tab trực quan: "Đang diễn ra" & "Lịch sử chuyến đi"
class CustomerActivityScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerActivityScreen({super.key, this.showAppBar = true});

  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

class _CustomerActivityScreenState extends State<CustomerActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final String _currentUserId = FirebaseService.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isRideActive(RideModel ride) {
    return ride.status == RideStatus.pendingDriver ||
        ride.status == RideStatus.accepted ||
        ride.status == RideStatus.arrivedPickup ||
        ride.status == RideStatus.inProgress;
  }

  bool _isDeliveryActive(DeliveryModel delivery) {
    return delivery.status == DeliveryStatus.pendingDriver ||
        delivery.status == DeliveryStatus.accepted ||
        delivery.status == DeliveryStatus.pickedUp ||
        delivery.status == DeliveryStatus.inTransit;
  }

  void _openRatingDialog(
    BuildContext context, {
    required String tripId,
    String? driverId,
    required String driverName,
    required double price,
    bool isDelivery = false,
    String? podPhotoUrl,
  }) {
    TripRatingDialog.show(
      context,
      tripId: tripId,
      driverId: driverId,
      driverName: driverName,
      price: price,
      isDelivery: isDelivery,
      podPhotoUrl: podPhotoUrl,
      onDismissed: () {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = Column(
      children: [
        // TabBar chọn Đang diễn ra vs Lịch sử
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Đang Diễn Ra'),
              Tab(text: 'Lịch Sử Chuyến Đi'),
            ],
          ),
        ),

        // Stream kết hợp cả Ride và Delivery
        Expanded(
          child: StreamBuilder<List<RideModel>>(
            stream: CustomerService.instance.streamCustomerRides(_currentUserId),
            builder: (context, rideSnapshot) {
              return StreamBuilder<List<DeliveryModel>>(
                stream: CustomerService.instance
                    .streamCustomerDeliveries(_currentUserId),
                builder: (context, deliverySnapshot) {
                  final rides = rideSnapshot.data ?? [];
                  final deliveries = deliverySnapshot.data ?? [];

                  final activeRides = rides.where(_isRideActive).toList();
                  final activeDeliveries =
                      deliveries.where(_isDeliveryActive).toList();

                  final pastRides =
                      rides.where((r) => !_isRideActive(r)).toList();
                  final pastDeliveries =
                      deliveries.where((d) => !_isDeliveryActive(d)).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: ĐANG DIỄN RA
                      _buildOrdersList(
                        context,
                        rides: activeRides,
                        deliveries: activeDeliveries,
                        emptyMessage: 'Hiện không có chuyến đi nào đang diễn ra',
                        isDark: isDark,
                      ),

                      // TAB 2: LỊCH SỬ CHUYẾN ĐI
                      _buildOrdersList(
                        context,
                        rides: pastRides,
                        deliveries: pastDeliveries,
                        emptyMessage: 'Bạn chưa có lịch sử chuyến đi nào',
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoạt Động Của Tôi'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _buildOrdersList(
    BuildContext context, {
    required List<RideModel> rides,
    required List<DeliveryModel> deliveries,
    required String emptyMessage,
    required bool isDark,
  }) {
    // Kết hợp và sắp xếp theo thời gian tạo mới nhất
    final List<dynamic> allOrders = [...rides, ...deliveries];
    allOrders.sort((a, b) {
      final DateTime timeA = a is RideModel ? a.createdAt : (a as DeliveryModel).createdAt;
      final DateTime timeB = b is RideModel ? b.createdAt : (b as DeliveryModel).createdAt;
      return timeB.compareTo(timeA);
    });

    if (allOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off_rounded,
                  size: 64, color: AppColors.primary.withAlpha(120)),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = allOrders[index];

        if (item is RideModel) {
          return OrderHistoryCard.ride(
            ride: item,
            onTap: () {
              if (_isRideActive(item)) {
                // Chuyến đang diễn ra - mở màn hình theo dõi thời gian thực
                Navigator.pushNamed(
                  context,
                  AppRoutes.liveTracking,
                  arguments: <String, dynamic>{'rideId': item.id},
                );
              } else {
                // Chúyern lịch sử - mở chi tiết đơn hàng
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen.ride(ride: item),
                  ),
                );
              }
            },
            onRateNow: item.status == RideStatus.completed && item.rating == null
                ? () => _openRatingDialog(
                      context,
                      tripId: item.id,
                      driverId: item.driverId,
                      driverName: item.driverName ?? 'Tài xế JetPost',
                      price: item.price,
                      isDelivery: false,
                    )
                : null,
          );
        } else {
          final delivery = item as DeliveryModel;
          return OrderHistoryCard.delivery(
            delivery: delivery,
            onTap: () {
              if (_isDeliveryActive(delivery)) {
                // Đơn đang diễn ra - mở màn hình theo dõi thời gian thực
                Navigator.pushNamed(
                  context,
                  AppRoutes.liveTracking,
                  arguments: <String, dynamic>{'deliveryId': delivery.id},
                );
              } else {
                // Đơn lịch sử - mở chi tiết đơn hàng
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailScreen.delivery(delivery: delivery),
                  ),
                );
              }
            },
            onRateNow: delivery.status == DeliveryStatus.completed &&
                    delivery.rating == null
                ? () => _openRatingDialog(
                      context,
                      tripId: delivery.id,
                      driverId: delivery.driverId,
                      driverName: delivery.driverName ?? 'Tài xế JetPost',
                      price: delivery.price,
                      isDelivery: true,
                      podPhotoUrl: delivery.podPhotoUrl,
                    )
                : null,
          );
        }
      },
    );
  }
}

