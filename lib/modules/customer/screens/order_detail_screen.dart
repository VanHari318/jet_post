import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/delivery_model.dart';
import '../../../models/ride_model.dart';
import '../widgets/trip_rating_dialog.dart';
import 'delivery_booking_screen.dart';
import 'ride_booking_screen.dart';

/// Màn hình Chi Tiết Đơn Hàng & Cuốc Xe (Task 1.5 & 1.8)
/// Xem lại lộ trình, chi phí, ảnh bằng chứng giao hàng (PoD),
/// đánh giá bù tài xế và tính năng Đặt lại (Re-order) 1 chạm.
class OrderDetailScreen extends StatefulWidget {
  final RideModel? ride;
  final DeliveryModel? delivery;

  const OrderDetailScreen.ride({super.key, required RideModel this.ride})
      : delivery = null;

  const OrderDetailScreen.delivery(
      {super.key, required DeliveryModel this.delivery})
      : ride = null;

  bool get isDelivery => delivery != null;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final MapController _mapController = MapController();

  String get tripId => widget.isDelivery ? widget.delivery!.id : widget.ride!.id;
  String get pickupAddress =>
      widget.isDelivery ? widget.delivery!.pickupAddress : widget.ride!.pickupAddress;
  double get pickupLat =>
      widget.isDelivery ? widget.delivery!.pickupLat : widget.ride!.pickupLat;
  double get pickupLng =>
      widget.isDelivery ? widget.delivery!.pickupLng : widget.ride!.pickupLng;

  String get dropoffAddress =>
      widget.isDelivery ? widget.delivery!.dropoffAddress : widget.ride!.dropoffAddress;
  double get dropoffLat =>
      widget.isDelivery ? widget.delivery!.dropoffLat : widget.ride!.dropoffLat;
  double get dropoffLng =>
      widget.isDelivery ? widget.delivery!.dropoffLng : widget.ride!.dropoffLng;

  double get distanceKm =>
      widget.isDelivery ? widget.delivery!.distanceKm : widget.ride!.distanceKm;
  double get price => widget.isDelivery ? widget.delivery!.price : widget.ride!.price;
  String? get driverName =>
      widget.isDelivery ? widget.delivery!.driverName : widget.ride!.driverName;
  String? get driverPlate =>
      widget.isDelivery ? widget.delivery!.driverPlate : widget.ride!.driverPlate;
  String? get driverId =>
      widget.isDelivery ? widget.delivery!.driverId : widget.ride!.driverId;

  int? get rating => widget.isDelivery ? widget.delivery!.rating : widget.ride!.rating;
  String? get reviewComment =>
      widget.isDelivery ? widget.delivery!.reviewComment : widget.ride!.reviewComment;
  String? get podPhotoUrl => widget.delivery?.podPhotoUrl;

  bool get isCompleted {
    if (widget.isDelivery) {
      return widget.delivery!.status == DeliveryStatus.completed;
    }
    return widget.ride!.status == RideStatus.completed;
  }

  void _showEnlargedPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                CloudinaryService.instance.getOptimizedUrl(url, width: 800),
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder() {
    final pickup = LatLng(pickupLat, pickupLng);
    final dropoff = LatLng(dropoffLat, dropoffLng);

    if (widget.isDelivery) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryBookingScreen(
            initialPickup: pickup,
            initialPickupAddress: pickupAddress,
            initialDropoff: dropoff,
            initialDropoffAddress: dropoffAddress,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideBookingScreen(
            initialPickup: pickup,
            initialPickupAddress: pickupAddress,
            initialDropoff: dropoff,
            initialDropoffAddress: dropoffAddress,
          ),
        ),
      );
    }
  }

  void _handleRateNow() {
    TripRatingDialog.show(
      context,
      tripId: tripId,
      driverId: driverId,
      driverName: driverName ?? 'Tài xế JetPost',
      price: price,
      isDelivery: widget.isDelivery,
      podPhotoUrl: podPhotoUrl,
      onDismissed: () {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final pickupPoint = LatLng(pickupLat, pickupLng);
    final dropoffPoint = LatLng(dropoffLat, dropoffLng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDelivery
            ? 'Chi Tiết Đơn Giao Hàng'
            : 'Chi Tiết Cuốc Xe Ôm'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomPadding + 90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. BẢN ĐỒ THU NHỎ TÁI HIỆN LỘ TRÌNH
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: pickupPoint,
                    initialZoom: 13.0,
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
                          point: pickupPoint,
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.person_pin_circle,
                              color: AppColors.primary, size: 32),
                        ),
                        Marker(
                          point: dropoffPoint,
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on,
                              color: AppColors.secondary, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. THÔNG TIN LỘ TRÌNH & CƯỚC PHÍ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng cước (Tiền mặt):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Điểm đón -> Điểm trả
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle,
                              color: AppColors.primary, size: 10),
                          Container(
                            width: 2,
                            height: 26,
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                          ),
                          const Icon(Icons.location_on,
                              color: AppColors.secondary, size: 12),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickupAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              dropoffAddress,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. THÔNG TIN TÀI XẾ
            if (driverName != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driverPlate ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. BẰNG CHỨNG GIAO HÀNG POD PHOTO (NẾU CÓ)
            if (podPhotoUrl != null && podPhotoUrl!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: AppColors.secondary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Ảnh chụp bằng chứng giao hàng (PoD):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showEnlargedPhoto(context, podPhotoUrl!),
                      borderRadius: BorderRadius.circular(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Image.network(
                              CloudinaryService.instance.getOptimizedUrl(
                                podPhotoUrl!,
                                width: 400,
                                height: 200,
                              ),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.zoom_in,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Phóng to',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 5. KHUNG ĐÁNH GIÁ SAO
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đánh giá chất lượng:',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (rating != null)
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              return Icon(
                                i < rating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(
                              '$rating sao',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        )
                      else
                        const Text('Chưa đánh giá',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      if (reviewComment != null && reviewComment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reviewComment!,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (rating == null && isCompleted)
                    ElevatedButton(
                      onPressed: _handleRateNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Đánh giá ngay',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 6. NÚT ĐẶT LẠI CHUYẾN NÀY (TASK 1.8 - RE-ORDER)
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomPadding + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _handleReorder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.repeat_rounded, size: 20),
            label: const Text(
              'ĐẶT LẠI CHUYẾN NÀY',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

