import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/openroute_client.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/geo_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../../models/saved_address_model.dart';
import '../../../models/user_model.dart';
import '../../user/services/user_service.dart';
import '../services/customer_service.dart';
import '../widgets/quick_address_chips.dart';
import 'live_tracking_screen.dart';

/// Màn hình Tạo Đơn Giao Hàng JetExpress (Task 1.2)
/// Hỗ trợ phân loại bưu kiện, tính cước Upfront + phụ phí,
/// tự động sinh Mã OTP 4 số bàn giao an toàn & chia sẻ hành trình qua SMS/Zalo.
class DeliveryBookingScreen extends StatefulWidget {
  final LatLng? initialPickup;
  final String? initialPickupAddress;
  final LatLng? initialDropoff;
  final String? initialDropoffAddress;

  const DeliveryBookingScreen({
    super.key,
    this.initialPickup,
    this.initialPickupAddress,
    this.initialDropoff,
    this.initialDropoffAddress,
  });

  @override
  State<DeliveryBookingScreen> createState() => _DeliveryBookingScreenState();
}

class _DeliveryBookingScreenState extends State<DeliveryBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverPhoneController = TextEditingController();
  final TextEditingController _packageNoteController = TextEditingController();
  final TextEditingController _dropoffSearchController = TextEditingController();
  final FocusNode _dropoffFocusNode = FocusNode();

  UserModel? _currentUser;
  LatLng _pickupLatLng = const LatLng(21.0285, 105.8542);
  String _pickupAddress = 'Đang xác định vị trí...';
  LatLng? _dropoffLatLng;
  String? _dropoffAddress;

  String _selectedPackageType = 'Tài liệu';
  double _packageSurcharge = 0.0;
  final Map<String, double> _packageTypes = {
    'Tài liệu': 0.0,
    'Đồ ăn / Thức uống': 0.0,
    'Hàng nặng (>5kg)': 10000.0,
    'Hàng cồng kềnh': 15000.0,
  };

  double _distanceKm = 0.0;
  double _durationMinutes = 0.0;
  double _estimatedPrice = 0.0;
  bool _isCalculatingRoute = false;
  bool _isSubmitting = false;

  bool _isSearchingPlace = false;
  bool _showSuggestions = false;
  Timer? _searchDebounceTimer;
  List<PlaceResult> _placeSearchResults = [];

  @override
  void initState() {
    super.initState();
    _dropoffFocusNode.addListener(() {
      if (_dropoffFocusNode.hasFocus) {
        if (_dropoffSearchController.text.trim().isEmpty) {
          setState(() {
            _placeSearchResults = OpenRouteClient.popularPlaces;
            _showSuggestions = true;
          });
        } else {
          setState(() => _showSuggestions = true);
        }
      }
    });

    _loadUserAndLocation();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dropoffFocusNode.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _packageNoteController.dispose();
    _dropoffSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndLocation() async {
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await UserService.instance.getUserProfile(uid);
      setState(() {});
    }

    if (widget.initialPickup != null) {
      _pickupLatLng = widget.initialPickup!;
      _pickupAddress = widget.initialPickupAddress ?? 'Điểm lấy hàng đã chọn';
      setState(() {});
    } else {
      await _getCurrentLocation();
    }

    if (widget.initialDropoff != null) {
      _dropoffLatLng = widget.initialDropoff!;
      _dropoffAddress = widget.initialDropoffAddress ?? 'Điểm giao hàng';
      _dropoffSearchController.text = _dropoffAddress!;
      _calculateRoute();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _pickupLatLng = LatLng(pos.latitude, pos.longitude);
        _pickupAddress = 'Vị trí hiện tại của bạn';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickupAddress = 'Đại học Thủy Lợi, 175 Tây Sơn, Đống Đa';
        _pickupLatLng = const LatLng(21.0074, 105.8248);
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_dropoffLatLng == null) return;

    setState(() => _isCalculatingRoute = true);

    try {
      final result = await OpenRouteClient.getDirections(
        _pickupLatLng,
        _dropoffLatLng!,
      );

      final price = await CustomerService.instance.calculateDeliveryPrice(
        result.distanceKm,
        packageSurcharge: _packageSurcharge,
      );

      if (!mounted) return;

      setState(() {
        _distanceKm = result.distanceKm;
        _durationMinutes = result.durationMinutes;
        _estimatedPrice = price;
        _isCalculatingRoute = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculatingRoute = false);
      AppDialogs.showError(context,
          title: 'Lỗi Tính Tuyến Đường', message: '$e');
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _placeSearchResults = OpenRouteClient.popularPlaces;
        _showSuggestions = true;
        _isSearchingPlace = false;
      });
      return;
    }

    setState(() {
      _isSearchingPlace = true;
      _showSuggestions = true;
    });

    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await OpenRouteClient.searchPlaces(
        trimmed,
        userLat: _pickupLatLng.latitude,
        userLng: _pickupLatLng.longitude,
      );
      if (!mounted) return;
      setState(() {
        _placeSearchResults = results;
        _isSearchingPlace = false;
      });
    });
  }

  void _selectDropoffPlace(PlaceResult place) {
    final distMeters = GeoCalculator.distanceInMeters(
      _pickupLatLng.latitude,
      _pickupLatLng.longitude,
      place.latitude,
      place.longitude,
    );

    if (distMeters < 50) {
      AppDialogs.showWarning(
        context,
        title: 'Điểm Giao Trùng Điểm Lấy',
        message:
            'Bạn đang chọn điểm giao hàng trùng với vị trí lấy hàng hiện tại (${distMeters.toStringAsFixed(0)}m). Vui lòng chọn địa chỉ giao khác!',
      );
      return;
    }

    setState(() {
      _dropoffLatLng = LatLng(place.latitude, place.longitude);
      _dropoffAddress = place.title.isNotEmpty
          ? '${place.title} - ${place.subtitle}'
          : place.displayName;
      _dropoffSearchController.text = _dropoffAddress!;
      _showSuggestions = false;
      _placeSearchResults = [];
    });
    _dropoffFocusNode.unfocus();
    _calculateRoute();
  }

  void _onSelectSavedAddress(SavedAddressModel addr) {
    final distMeters = GeoCalculator.distanceInMeters(
      _pickupLatLng.latitude,
      _pickupLatLng.longitude,
      addr.lat,
      addr.lng,
    );

    if (distMeters < 50) {
      AppDialogs.showWarning(
        context,
        title: 'Điểm Giao Trùng Điểm Lấy',
        message:
            'Địa chỉ đã lưu này trùng với vị trí lấy hàng hiện tại của bạn. Vui lòng chọn địa chỉ khác!',
      );
      return;
    }

    setState(() {
      _dropoffLatLng = LatLng(addr.lat, addr.lng);
      _dropoffAddress = addr.addressText;
      _dropoffSearchController.text = addr.addressText;
      _showSuggestions = false;
      _placeSearchResults = [];
    });
    _dropoffFocusNode.unfocus();
    _calculateRoute();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'school':
        return Icons.school_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'mall':
        return Icons.shopping_bag_rounded;
      case 'transit':
        return Icons.directions_bus_rounded;
      case 'airport':
        return Icons.flight_takeoff_rounded;
      case 'attraction':
        return Icons.landscape_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'school':
        return Colors.orange;
      case 'hospital':
        return Colors.red;
      case 'mall':
        return Colors.purple;
      case 'transit':
        return Colors.blue;
      case 'airport':
        return Colors.indigo;
      case 'attraction':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _handleCreateDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dropoffLatLng == null) {
      AppDialogs.showError(context,
          title: 'Chưa Chọn Địa Chỉ Giao',
          message: 'Vui lòng chọn địa chỉ giao hàng cho người nhận.');
      return;
    }

    final user = _currentUser;
    if (user == null) {
      AppDialogs.showError(context,
          title: 'Chưa Đăng Nhập', message: 'Vui lòng đăng nhập để gửi hàng.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final rawReceiverPhone = _receiverPhoneController.text.trim();
      final formattedReceiverPhone =
          UserService.instance.formatToE164(rawReceiverPhone);

      final deliveryId = await CustomerService.instance.createDeliveryBooking(
        senderId: user.id,
        senderName: user.fullName,
        senderPhone: user.phone,
        receiverName: _receiverNameController.text.trim(),
        receiverPhone: formattedReceiverPhone,
        packageType: _selectedPackageType,
        packageNote: _packageNoteController.text.trim().isNotEmpty
            ? _packageNoteController.text.trim()
            : null,
        pickupAddress: _pickupAddress,
        pickupLat: _pickupLatLng.latitude,
        pickupLng: _pickupLatLng.longitude,
        dropoffAddress: _dropoffAddress!,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        distanceKm: _distanceKm,
        price: _estimatedPrice,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Hiển thị dialog xác nhận thành công và sinh link chia sẻ hành trình
      _showDeliverySuccessDialog(deliveryId, formattedReceiverPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppDialogs.showError(context,
          title: 'Lỗi Tạo Đơn Hàng', message: '$e');
    }
  }

  void _showDeliverySuccessDialog(String deliveryId, String receiverPhone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.secondary, size: 28),
              SizedBox(width: 10),
              Text('Tạo Đơn Thành Công!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đơn giao hàng JetExpress đã được gửi lên hệ thống và đang quét tìm tài xế lân cận.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Mã vận đơn
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cardDark
                      : AppColors.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.secondary.withAlpha(80)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mã vận đơn:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      deliveryId.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Nút chia sẻ hành trình qua tin nhắn Zalo / SMS (Task 1.2 Luồng 4)
              OutlinedButton.icon(
                onPressed: () async {
                  final text =
                      'Xin chào! Tôi vừa gửi bưu phẩm qua JetPost cho bạn. Mã đơn hàng: ${deliveryId.substring(0, 8).toUpperCase()}. Bạn có thể theo dõi trên ứng dụng JetPost!';
                  final uri = Uri.parse('sms:$receiverPhone?body=${Uri.encodeComponent(text)}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.share,
                    size: 16, color: AppColors.secondary),
                label: const Text(
                  'Chia Sẻ Tin Nhắn Cho Người Nhận',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LiveTrackingScreen.delivery(deliveryId: deliveryId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Theo Dõi Hành Trình'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_rounded,
                color: AppColors.secondary, size: 22),
            SizedBox(width: 8),
            Text('Giao Hàng JetExpress'),
          ],
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: bottomPadding + 90,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KHỐI ĐỊA CHỈ LẤY & GIAO HÀNG
              _buildSectionTitle('1. Tuyến Đường Vận Chuyển', Icons.route_rounded),
              const SizedBox(height: 10),
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
                  children: [
                    // Điểm lấy hàng
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            color: AppColors.primary, size: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Điểm lấy hàng (Người gửi):',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                _pickupAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location,
                              color: AppColors.primary, size: 18),
                          onPressed: _getCurrentLocation,
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Điểm giao hàng (Ô tìm kiếm)
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.secondary, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Điểm giao hàng (Người nhận):',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              TextField(
                                controller: _dropoffSearchController,
                                focusNode: _dropoffFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Nhập địa chỉ nhận hàng...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: _onSearchQueryChanged,
                              ),
                            ],
                          ),
                        ),
                        if (_isSearchingPlace)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_dropoffSearchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _dropoffSearchController.clear();
                              setState(() {
                                _dropoffLatLng = null;
                                _dropoffAddress = null;
                                _distanceKm = 0.0;
                                _estimatedPrice = 0.0;
                                _showSuggestions = false;
                                _placeSearchResults = [];
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Gợi ý địa điểm tìm kiếm (Google Maps Style)
              if (_showSuggestions &&
                  (_placeSearchResults.isNotEmpty ||
                      _isSearchingPlace ||
                      _dropoffSearchController.text.trim().isNotEmpty)) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 80 : 35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 14, right: 8, top: 10, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              _dropoffSearchController.text.trim().isEmpty
                                  ? Icons.stars_rounded
                                  : Icons.search_rounded,
                              color: AppColors.secondary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dropoffSearchController.text.trim().isEmpty
                                  ? 'ĐỊA ĐIỂM GỢI Ý PHỔ BIẾN'
                                  : 'KẾT QUẢ TÌM KIẾM',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _showSuggestions = false),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Trạng thái Loading
                      if (_isSearchingPlace)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.secondary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Đang tìm kiếm địa chỉ quanh bạn...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      // Trạng thái Empty
                      else if (_placeSearchResults.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Column(
                            children: [
                              const Icon(Icons.location_off_outlined,
                                  color: Colors.grey, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                'Không tìm thấy "${_dropoffSearchController.text.trim()}"',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vui lòng gõ thêm tên đường, phường hoặc quận để tìm kiếm chính xác hơn.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _placeSearchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, i) {
                            final p = _placeSearchResults[i];
                            final distKm = GeoCalculator.distanceInKm(
                              _pickupLatLng.latitude,
                              _pickupLatLng.longitude,
                              p.latitude,
                              p.longitude,
                            );

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(p.category)
                                      .withAlpha(24),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getCategoryIcon(p.category),
                                  color: _getCategoryColor(p.category),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                p.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                p.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: distKm > 0.05
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.surfaceDark
                                            : AppColors.secondary
                                                .withAlpha(18),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${distKm.toStringAsFixed(1)} km',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () => _selectDropoffPlace(p),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_showSuggestions) ...[
                const SizedBox(height: 8),
                QuickAddressChips(
                  userId: _currentUser?.id ?? '',
                  onAddressSelected: _onSelectSavedAddress,
                ),
              ],

              const SizedBox(height: 20),

              // 2. THÔNG TIN NGƯỜI NHẬN
              _buildSectionTitle(
                  '2. Thông Tin Người Nhận', Icons.person_pin_rounded),
              const SizedBox(height: 10),
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
                  children: [
                    TextFormField(
                      controller: _receiverNameController,
                      decoration: InputDecoration(
                        labelText: 'Họ tên người nhận',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tên người nhận';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _receiverPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại người nhận',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      validator: AppValidators.validatePhone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. THÔNG TIN BƯU PHẨM & PHỤ PHÍ
              _buildSectionTitle(
                  '3. Thông Tin Bưu Phẩm', Icons.inventory_2_rounded),
              const SizedBox(height: 10),
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
                    const Text('Loại bưu kiện:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _packageTypes.entries.map((entry) {
                        final isSelected = _selectedPackageType == entry.key;
                        return ChoiceChip(
                          label: Text(
                            entry.value > 0
                                ? '${entry.key} (+${CurrencyFormatter.format(entry.value)})'
                                : entry.key,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.secondaryLight,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.secondary
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedPackageType = entry.key;
                              _packageSurcharge = entry.value;
                            });
                            _calculateRoute();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _packageNoteController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú cho tài xế (Không bắt buộc)',
                        hintText: 'VD: Hàng dễ vỡ, gọi điện trước khi giao...',
                        prefixIcon:
                            const Icon(Icons.edit_note_outlined, size: 22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // FOOTER THANH TOÁN & NÚT TẠO ĐƠN
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
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng cước hỏa tốc:',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    _isCalculatingRoute
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            CurrencyFormatter.format(_estimatedPrice),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                  ],
                ),
                if (_distanceKm > 0)
                  Text(
                    '$_distanceKm km • ${_durationMinutes.toStringAsFixed(0)} phút',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _isCalculatingRoute
                    ? null
                    : _handleCreateDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'TẠO ĐƠN GIAO HÀNG JETEXPRESS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

