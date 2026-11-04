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
import '../../../models/system_settings_model.dart';
import '../../../models/user_model.dart';
import '../../user/services/user_service.dart';
import '../services/customer_service.dart';
import '../widgets/quick_address_chips.dart';
import 'customer_activity_screen.dart';

/// Màn hình Tạo Đơn Giao Hàng JetExpress (Task 1.2)
/// Hỗ trợ:
/// - Khai báo chi tiết điểm lấy & giao (số nhà, phòng, tầng...)
/// - Khối lượng bưu kiện (kg) + phụ phí theo kg (Admin cấu hình)
/// - Phụ phí hàng dễ vỡ (+10k) & giao hỏa tốc (+20k) (Admin cấu hình)
/// - Tiền thu hộ COD (tối đa 3.000.000 đ) & phân định người trả cước
/// - Validate nghiêm ngặt (SĐT nhận != gửi, cự ly 100m - 40km, COD hợp lệ)
/// - Mô hình Bể đơn hàng (Waiting Pool): Khách tạo đơn và có thể tiếp tục tạo đơn khác
///   hoặc xem toàn bộ danh sách đơn đang chờ trong mục Hoạt động.
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
  final TextEditingController _pickupDetailController = TextEditingController();
  final TextEditingController _dropoffDetailController = TextEditingController();
  final TextEditingController _packageNoteController = TextEditingController();
  final TextEditingController _dropoffSearchController = TextEditingController();
  final TextEditingController _codController = TextEditingController();
  final FocusNode _dropoffFocusNode = FocusNode();

  UserModel? _currentUser;
  SystemSettingsModel? _settings;
  LatLng _pickupLatLng = const LatLng(21.0285, 105.8542);
  String _pickupAddress = 'Đang xác định vị trí...';
  LatLng? _dropoffLatLng;
  String? _dropoffAddress;

  String _selectedPackageType = 'Tài liệu';
  double _packageSurcharge = 0.0;
  final Map<String, double> _packageTypes = {
    'Tài liệu': 0.0,
    'Đồ ăn / Thức uống': 0.0,
    'Quần áo / Mỹ phẩm': 0.0,
    'Đồ điện tử / Công nghệ': 5000.0,
    'Hàng cồng kềnh': 15000.0,
  };

  // Cấu hình khối lượng & phụ phí
  double _weightKg = 1.0;
  bool _isFragile = false;
  bool _isExpress = false;
  String _payer = 'SENDER'; // SENDER | RECEIVER

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
    _pickupDetailController.dispose();
    _dropoffDetailController.dispose();
    _packageNoteController.dispose();
    _dropoffSearchController.dispose();
    _codController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndLocation() async {
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await UserService.instance.getUserProfile(uid);
      setState(() {});
    }

    try {
      _settings = await CustomerService.instance.getSystemSettings();
      setState(() {});
    } catch (_) {}

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
        weightKg: _weightKg,
        isFragile: _isFragile,
        isExpress: _isExpress,
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
            'Địa chỉ lưu sẵn này trùng với điểm lấy hàng (${distMeters.toStringAsFixed(0)}m). Vui lòng chọn địa chỉ khác!',
      );
      return;
    }

    setState(() {
      _dropoffLatLng = LatLng(addr.lat, addr.lng);
      _dropoffAddress = '${addr.label.toFirestore()} - ${addr.addressText}';
      _dropoffSearchController.text = _dropoffAddress!;
      _showSuggestions = false;
    });
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
          title: 'Chưa Chọn Điểm Giao Hàng',
          message: 'Vui lòng tìm kiếm hoặc chọn địa chỉ giao hàng cho người nhận.');
      return;
    }

    if (_distanceKm < 0.1) {
      AppDialogs.showWarning(context,
          title: 'Khoảng Cách Quá Gần',
          message: 'Khoảng cách giao hàng phải từ 100m trở lên. Vui lòng kiểm tra lại điểm lấy và giao!');
      return;
    }

    if (_distanceKm > 40.0) {
      AppDialogs.showWarning(context,
          title: 'Vượt Quá Giới Hạn Cự Ly',
          message:
              'JetPost hiện tại phục vụ giao hàng nội thành trong bán kính tối đa 40km. Cự ly chuyến này là ${_distanceKm.toStringAsFixed(1)}km.');
      return;
    }

    final user = _currentUser;
    if (user == null) {
      AppDialogs.showError(context,
          title: 'Chưa Đăng Nhập', message: 'Vui lòng đăng nhập để gửi hàng.');
      return;
    }

    final rawReceiverPhone = _receiverPhoneController.text.trim();
    final formattedReceiverPhone =
        UserService.instance.formatToE164(rawReceiverPhone);

    if (user.phone.isNotEmpty &&
        (formattedReceiverPhone == user.phone ||
            rawReceiverPhone == user.phone)) {
      AppDialogs.showWarning(
        context,
        title: 'SĐT Người Nhận Trùng Người Gửi',
        message:
            'Số điện thoại người nhận không thể trùng với số điện thoại của bạn (${user.phone}). Vui lòng nhập số điện thoại người nhận thực tế!',
      );
      return;
    }

    double codAmount = 0.0;
    final codText = _codController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (codText.isNotEmpty) {
      codAmount = double.tryParse(codText) ?? 0.0;
      if (codAmount > 3000000.0) {
        AppDialogs.showWarning(
          context,
          title: 'Vượt Hạn Mức COD',
          message:
              'Hạn mức thu hộ COD tối đa là 3.000.000 đ cho mỗi bưu phẩm. Vui lòng điều chỉnh lại số tiền thu hộ!',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
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
        pickupDetail: _pickupDetailController.text.trim().isNotEmpty
            ? _pickupDetailController.text.trim()
            : null,
        pickupLat: _pickupLatLng.latitude,
        pickupLng: _pickupLatLng.longitude,
        dropoffAddress: _dropoffAddress!,
        dropoffDetail: _dropoffDetailController.text.trim().isNotEmpty
            ? _dropoffDetailController.text.trim()
            : null,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        distanceKm: _distanceKm,
        weightKg: _weightKg,
        isFragile: _isFragile,
        isExpress: _isExpress,
        payer: _payer,
        price: _estimatedPrice,
        codAmount: codAmount,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showDeliverySuccessDialog(deliveryId, formattedReceiverPhone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppDialogs.showError(context,
          title: 'Lỗi Tạo Đơn Hàng', message: '$e');
    }
  }

  void _resetFormForNewOrder() {
    _receiverNameController.clear();
    _receiverPhoneController.clear();
    _dropoffDetailController.clear();
    _packageNoteController.clear();
    _dropoffSearchController.clear();
    _codController.clear();
    setState(() {
      _dropoffLatLng = null;
      _dropoffAddress = null;
      _distanceKm = 0.0;
      _durationMinutes = 0.0;
      _estimatedPrice = 0.0;
      _weightKg = 1.0;
      _isFragile = false;
      _isExpress = false;
      _payer = 'SENDER';
      _selectedPackageType = 'Tài liệu';
      _packageSurcharge = 0.0;
    });
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
              Expanded(
                child: Text('Đã Thêm Vào Danh Sách Chờ!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đơn giao hàng JetExpress đã được đưa vào Bể chờ nhận (Waiting Pool). Các tài xế lân cận đang quét và tiếp nhận đơn của bạn.',
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

              // Nút chia sẻ SMS cho người nhận
              OutlinedButton.icon(
                onPressed: () async {
                  final text =
                      'Xin chào! Tôi vừa gửi bưu phẩm qua JetPost cho bạn. Mã đơn hàng: ${deliveryId.substring(0, 8).toUpperCase()}. Bạn có thể theo dõi tiến trình trực tiếp trên ứng dụng JetPost!';
                  final uri = Uri.parse('sms:$receiverPhone?body=${Uri.encodeComponent(text)}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  side: const BorderSide(color: AppColors.secondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.share,
                    size: 16, color: AppColors.secondary),
                label: const Text(
                  'Chia Sẻ SMS Cho Người Nhận',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            // Nút 1: Tạo thêm đơn khác (cộng dồn danh sách chờ)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _resetFormForNewOrder();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đơn trước đã vào danh sách chờ. Mời bạn tiếp tục tạo đơn mới!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('Tạo Đơn Khác'),
            ),

            // Nút 2: Xem danh sách chờ trong tab Hoạt động
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerActivityScreen(showAppBar: true),
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
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('Xem Danh Sách'),
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
    final pricePerKg = _settings?.pricePerKgDelivery ?? 10000.0;
    final fragileFee = _settings?.fragileSurcharge ?? 10000.0;
    final expressFee = _settings?.expressSurcharge ?? 20000.0;

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
            bottom: bottomPadding + 140,
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
                    const SizedBox(height: 8),

                    // Chi tiết điểm lấy (Số nhà, tầng, phòng)
                    TextFormField(
                      controller: _pickupDetailController,
                      decoration: InputDecoration(
                        hintText: 'Chi tiết điểm lấy: Số nhà, tòa nhà, tầng, phòng...',
                        prefixIcon: const Icon(Icons.home_work_outlined, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),

                    const Divider(height: 20),

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

                    // Chi tiết điểm giao (Căn hộ, số phòng, chỉ dẫn)
                    if (_dropoffLatLng != null) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dropoffDetailController,
                        decoration: InputDecoration(
                          hintText: 'Chi tiết điểm giao: Tòa nhà, căn hộ, số tầng...',
                          prefixIcon: const Icon(Icons.apartment_rounded, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
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
                                    size: 18, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: _isSearchingPlace
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.secondary),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Đang tìm kiếm quanh bạn...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _placeSearchResults.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 24, horizontal: 16),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_off_rounded,
                                              size: 32,
                                              color: Colors.grey.withAlpha(160)),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Không tìm thấy địa điểm phù hợp',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Thử gõ tên đường, số nhà hoặc địa danh lớn hơn',
                                            style: TextStyle(
                                                fontSize: 11, color: Colors.grey),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _placeSearchResults.length,
                                    separatorBuilder: (_, _) =>
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
                        labelText: 'Họ tên người nhận *',
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
                        if (val.trim().length < 2) {
                          return 'Tên người nhận phải có ít nhất 2 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _receiverPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại người nhận *',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                        helperText: 'Dùng để tài xế liên hệ & gửi mã OTP nhận hàng',
                      ),
                      validator: (val) {
                        final phoneErr = AppValidators.validatePhone(val);
                        if (phoneErr != null) return phoneErr;
                        if (_currentUser != null &&
                            val != null &&
                            val.trim() == _currentUser!.phone) {
                          return 'SĐT người nhận không được trùng với SĐT người gửi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. THÔNG TIN BƯU PHẨM, KHỐI LƯỢNG & PHỤ PHÍ
              _buildSectionTitle(
                  '3. Thông Tin Bưu Phẩm & Cước Phí', Icons.inventory_2_rounded),
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
                    const SizedBox(height: 16),

                    // Khối lượng hàng hóa (kg)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Khối lượng bưu kiện:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              '+${CurrencyFormatter.format(pricePerKg)} / mỗi 1 kg',
                              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withAlpha(100)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: _weightKg > 0.5
                                    ? () {
                                        setState(() {
                                          _weightKg = (_weightKg - 0.5).clamp(0.5, 30.0);
                                        });
                                        _calculateRoute();
                                      }
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${_weightKg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: _weightKg < 30.0
                                    ? () {
                                        setState(() {
                                          _weightKg = (_weightKg + 0.5).clamp(0.5, 30.0);
                                        });
                                        _calculateRoute();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Tùy chọn Phụ phí Dễ Vỡ
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isFragile,
                      activeThumbColor: Colors.orange,
                      title: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Hàng dễ vỡ, xin nhẹ tay',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      subtitle: Text(
                        'Phụ phí bảo quản an toàn (+${CurrencyFormatter.format(fragileFee)})',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        setState(() => _isFragile = val);
                        _calculateRoute();
                      },
                    ),

                    // Tùy chọn Phụ phí Hỏa Tốc
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isExpress,
                      activeThumbColor: AppColors.secondary,
                      title: const Row(
                        children: [
                          Icon(Icons.bolt_rounded,
                              color: AppColors.secondary, size: 20),
                          SizedBox(width: 8),
                          Text('Giao hỏa tốc ưu tiên',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      subtitle: Text(
                        'Điều phối tài xế nhanh nhất, giao thẳng trong 1h (+${CurrencyFormatter.format(expressFee)})',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        setState(() => _isExpress = val);
                        _calculateRoute();
                      },
                    ),

                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _packageNoteController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú cho tài xế (Không bắt buộc)',
                        hintText: 'VD: Gọi trước khi đến 10 phút, hàng cồng kềnh...',
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

              const SizedBox(height: 20),

              // 4. THANH TOÁN & THU HỘ COD
              _buildSectionTitle(
                  '4. Thanh Toán & Thu Hộ COD', Icons.payments_rounded),
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
                    const Text('Người thanh toán cước phí:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'SENDER',
                          label: Text('Người gửi trả cước', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.person_outline, size: 16),
                        ),
                        ButtonSegment(
                          value: 'RECEIVER',
                          label: Text('Người nhận trả cước', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.person_pin_circle_outlined, size: 16),
                        ),
                      ],
                      selected: {_payer},
                      onSelectionChanged: (set) {
                        setState(() => _payer = set.first);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ô nhập tiền COD
                    TextFormField(
                      controller: _codController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Tiền thu hộ COD (VNĐ)',
                        hintText: '0 (để trống nếu không thu hộ)',
                        prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                        helperText: 'Tối đa 3.000.000 đ. Tài xế sẽ thu tiền mặt khi giao hàng',
                      ),
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
                    Text(
                      _isExpress ? 'Tổng cước Hỏa Tốc:' : 'Tổng cước Giao Hàng:',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                  ],
                ),
                if (_distanceKm > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_distanceKm.toStringAsFixed(1)} km • ${_durationMinutes.toStringAsFixed(0)} phút',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KL: ${_weightKg}kg ${_isFragile ? '• Dễ vỡ' : ''} ${_isExpress ? '• Hỏa tốc' : ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
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
                        'XÁC NHẬN TẠO ĐƠN GIAO HÀNG',
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
