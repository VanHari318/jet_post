import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/driver_model.dart';
import '../../../models/ride_model.dart';
import '../../../models/delivery_model.dart';

/// Màn hình quản lý Thu nhập & Lịch sử chuyến đi của Đối tác Tài xế
class DriverIncomeScreen extends StatefulWidget {
  const DriverIncomeScreen({super.key});

  @override
  State<DriverIncomeScreen> createState() => _DriverIncomeScreenState();
}

class _DriverIncomeScreenState extends State<DriverIncomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  DriverModel? _driver;
  bool _isLoadingDriver = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriverProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverProfile() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await _firestore.collection('drivers').doc(_uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _driver = DriverModel.fromFirestore(doc);
          _isLoadingDriver = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu Nhập & Hoạt Động'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          tabs: const [
            Tab(text: 'Xe Ôm'),
            Tab(text: 'Giao Hàng'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Thẻ tổng quan số dư ví thu nhập ──────────────────────────────
          _buildWalletCard(isDark),

          // ── Danh sách lịch sử hoàn thành chuyến đi ─────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCompletedRidesList(isDark),
                _buildCompletedDeliveriesList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ hiển thị số dư ví và tổng số chuyến
  Widget _buildWalletCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(90),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Số dư khả dụng',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _driver != null
                          ? '${_driver!.rating.toStringAsFixed(1)} ★'
                          : '5.0 ★',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isLoadingDriver
              ? const SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : Text(
                  CurrencyFormatter.format(_driver?.walletBalance ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Đã hoàn thành: ${_driver?.totalTrips ?? 0} chuyến',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                'Biển số: ${_driver?.plateNumber ?? "---"}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Danh sách cuốc xe ôm đã hoàn thành
  Widget _buildCompletedRidesList(bool isDark) {
    if (_uid.isEmpty) {
      return const Center(child: Text('Vui lòng đăng nhập để xem lịch sử'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _uid)
          .where('status', isEqualTo: RideStatus.completed.toFirestore())
          .orderBy('completedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không thể tải lịch sử chuyến đi',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bike_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight),
                const SizedBox(height: 12),
                Text(
                  'Chưa có cuốc xe ôm hoàn thành',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final ride = RideModel.fromFirestore(docs[index]);
            return _buildRideHistoryCard(ride, isDark);
          },
        );
      },
    );
  }

  Widget _buildRideHistoryCard(RideModel ride, bool isDark) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.motorcycle,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.customerName.isNotEmpty
                        ? ride.customerName
                        : 'Khách hàng',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '+${CurrencyFormatter.format(ride.price)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTripPointRow(
              icon: Icons.circle,
              color: AppColors.primary,
              text: ride.pickupAddress,
              isDark: isDark,
            ),
            const SizedBox(height: 4),
            _buildTripPointRow(
              icon: Icons.square,
              color: AppColors.secondary,
              text: ride.dropoffAddress,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ride.distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (ride.completedAt != null)
                  Text(
                    DateFormatter.formatDateTime(ride.completedAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Danh sách đơn giao hàng đã hoàn thành
  Widget _buildCompletedDeliveriesList(bool isDark) {
    if (_uid.isEmpty) {
      return const Center(child: Text('Vui lòng đăng nhập để xem lịch sử'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('deliveries')
          .where('driverId', isEqualTo: _uid)
          .where('status', isEqualTo: DeliveryStatus.completed.toFirestore())
          .orderBy('deliveredAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không thể tải lịch sử giao hàng',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight),
                const SizedBox(height: 12),
                Text(
                  'Chưa có đơn giao hàng hoàn thành',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final delivery = DeliveryModel.fromFirestore(docs[index]);
            return _buildDeliveryHistoryCard(delivery, isDark);
          },
        );
      },
    );
  }

  Widget _buildDeliveryHistoryCard(DeliveryModel delivery, bool isDark) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2,
                      color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đơn: ${delivery.packageType}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '+${CurrencyFormatter.format(delivery.price)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTripPointRow(
              icon: Icons.circle,
              color: AppColors.primary,
              text: delivery.pickupAddress,
              isDark: isDark,
            ),
            const SizedBox(height: 4),
            _buildTripPointRow(
              icon: Icons.square,
              color: AppColors.secondary,
              text: delivery.dropoffAddress,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${delivery.distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (delivery.deliveredAt != null)
                  Text(
                    DateFormatter.formatDateTime(delivery.deliveredAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripPointRow({
    required IconData icon,
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 8, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
