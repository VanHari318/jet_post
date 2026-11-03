import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/network/openroute_client.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/geo_calculator.dart';
import '../../../models/saved_address_model.dart';
import '../../../models/user_model.dart';
import '../../user/services/user_service.dart';
import '../services/customer_service.dart';
import '../widgets/quick_address_chips.dart';
import 'live_tracking_screen.dart';

/// Màn hình Đặt Xe Ôm JetBike (Task 1.1)
/// Bản đồ OSM, Geocoding Nominatim, Tuyến đường Polyline OpenRouteService,
/// Tính giá cước Upfront cố định & Radar quét tài xế lân cận đếm ngược 45s.
class RideBookingScreen extends StatefulWidget {
  final LatLng? initialPickup;
  final String? initialPickupAddress;
  final LatLng? initialDropoff;
  final String? initialDropoffAddress;

  const RideBookingScreen({
    super.key,
    this.initialPickup,
    this.initialPickupAddress,
    this.initialDropoff,
    this.initialDropoffAddress,
  });

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _dropoffSearchController = TextEditingController();
  final FocusNode _dropoffFocusNode = FocusNode();

  UserModel? _currentUser;
  LatLng _pickupLatLng = const LatLng(21.0285, 105.8542); // Mặc định Hà Nội
  String _pickupAddress = 'Đang xác định vị trí...';
  LatLng? _dropoffLatLng;
  String? _dropoffAddress;

  List<LatLng> _routePolyline = [];
  double _distanceKm = 0.0;
  double _durationMinutes = 0.0;
  double _estimatedPrice = 0.0;

  bool _isLoadingLocation = true;
  bool _isCalculatingRoute = false;
  bool _isSearchingPlace = false;
  bool _showSuggestions = false;
  int _mapReloadToken = 0;
  Timer? _searchDebounceTimer;
  List<PlaceResult> _placeSearchResults = [];

  // Trạng thái Radar quét tài xế (45 giây)
  bool _isRadarScanning = false;
  String? _activeRideId;
  int _countdownSeconds = 45;
  Timer? _countdownTimer;
  StreamSubscription? _rideSubscription;
  late AnimationController _radarPulseController;

  @override
  void initState() {
    super.initState();
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

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

    _loadCurrentUserAndLocation();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dropoffFocusNode.dispose();
    _countdownTimer?.cancel();
    _rideSubscription?.cancel();
    _radarPulseController.dispose();
    _dropoffSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndLocation() async {
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await UserService.instance.getUserProfile(uid);
    }

    if (widget.initialPickup != null) {
      _pickupLatLng = widget.initialPickup!;
      _pickupAddress = widget.initialPickupAddress ?? 'Điểm đón đã chọn';
      setState(() => _isLoadingLocation = false);
    } else {
      await _getCurrentLocation();
    }

    if (widget.initialDropoff != null) {
      _dropoffLatLng = widget.initialDropoff!;
      _dropoffAddress = widget.initialDropoffAddress ?? 'Điểm đến đã chọn';
      _calculateRoute();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _pickupLatLng = LatLng(pos.latitude, pos.longitude);
        _pickupAddress = 'Vị trí hiện tại của bạn';
        _isLoadingLocation = false;
      });

      _mapController.move(_pickupLatLng, 15.5);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickupAddress = 'Đại học Thủy Lợi, 175 Tây Sơn, Đống Đa';
        _pickupLatLng = const LatLng(21.0074, 105.8248);
        _isLoadingLocation = false;
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

      final price = await CustomerService.instance
          .calculateRidePrice(result.distanceKm);

      if (!mounted) return;

      setState(() {
        _routePolyline = result.polylinePoints;
        _distanceKm = result.distanceKm;
        _durationMinutes = result.durationMinutes;
        _estimatedPrice = price;
        _isCalculatingRoute = false;
      });

      // Tự động thu phóng bản đồ để thấy trọn vẹn cả 2 điểm
      _fitMapBounds();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCalculatingRoute = false);
      AppDialogs.showError(context,
          title: 'Lỗi Tuyến Đường', message: 'Không thể tính toán lộ trình: $e');
    }
  }

  void _fitMapBounds() {
    if (_dropoffLatLng == null) return;
    final distMeters = GeoCalculator.distanceInMeters(
      _pickupLatLng.latitude,
      _pickupLatLng.longitude,
      _dropoffLatLng!.latitude,
      _dropoffLatLng!.longitude,
    );

    // Nếu khoảng cách quá gần, không thu phóng cực đại làm mất tile bản đồ
    if (distMeters < 100) {
      _mapController.move(_pickupLatLng, 15.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints([_pickupLatLng, _dropoffLatLng!]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          left: 50,
          right: 50,
          top: 160,
          bottom: 250,
        ),
        maxZoom: 16.5,
      ),
    );
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

  Future<void> _onMapTap(LatLng point) async {
    if (_isRadarScanning) return;

    final distMeters = GeoCalculator.distanceInMeters(
      _pickupLatLng.latitude,
      _pickupLatLng.longitude,
      point.latitude,
      point.longitude,
    );

    if (distMeters < 50) {
      AppDialogs.showWarning(
        context,
        title: 'Điểm Đến Trùng Điểm Đón',
        message:
            'Vị trí bạn vừa chạm trùng với điểm đón hiện tại (${distMeters.toStringAsFixed(0)}m). Vui lòng chạm vào một vị trí khác trên bản đồ!',
      );
      return;
    }

    setState(() {
      _dropoffLatLng = point;
      _dropoffAddress = 'Đang tra cứu tên địa chỉ...';
      _dropoffSearchController.text = 'Đang tra cứu tên địa chỉ...';
      _showSuggestions = false;
      _placeSearchResults = [];
    });

    final reverseName = await OpenRouteClient.reverseGeocode(
        point.latitude, point.longitude);
    if (!mounted) return;

    final resolved = reverseName ??
        'Điểm ghim (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
    setState(() {
      _dropoffAddress = resolved;
      _dropoffSearchController.text = resolved;
    });

    _calculateRoute();
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
        title: 'Điểm Đến Trùng Điểm Đón',
        message:
            'Bạn đang chọn điểm đến trùng với vị trí đón hiện tại (${distMeters.toStringAsFixed(0)}m). Vui lòng chọn địa điểm khác!',
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
        title: 'Điểm Đến Trùng Điểm Đón',
        message:
            'Địa chỉ đã lưu này trùng với vị trí đón hiện tại của bạn. Vui lòng chọn một điểm đến khác!',
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

  // -------------------------------------------------------------
  // ĐẶT XE VÀ RADAR QUÉT TÀI XẾ 45S (TASK 1.1 & 1.6)
  // -------------------------------------------------------------

  Future<void> _handleBookRide() async {
    if (_dropoffLatLng == null) {
      AppDialogs.showError(context,
          title: 'Chưa Chọn Điểm Đến',
          message: 'Vui lòng chọn địa chỉ điểm đến trước khi đặt xe.');
      return;
    }

    final user = _currentUser;
    if (user == null) {
      AppDialogs.showError(context,
          title: 'Chưa Đăng Nhập',
          message: 'Vui lòng đăng nhập để thực hiện đặt chuyến đi.');
      return;
    }

    try {
      final rideId = await CustomerService.instance.createRideBooking(
        customerId: user.id,
        customerName: user.fullName,
        customerPhone: user.phone,
        pickupAddress: _pickupAddress,
        pickupLat: _pickupLatLng.latitude,
        pickupLng: _pickupLatLng.longitude,
        dropoffAddress: _dropoffAddress!,
        dropoffLat: _dropoffLatLng!.latitude,
        dropoffLng: _dropoffLatLng!.longitude,
        distanceKm: _distanceKm,
        price: _estimatedPrice,
      );

      setState(() {
        _activeRideId = rideId;
        _isRadarScanning = true;
        _countdownSeconds = 45;
      });

      _startRadarCountdown();
      _listenToRideStatus(rideId);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(context,
          title: 'Lỗi Đặt Xe', message: 'Không thể tạo cuốc xe: $e');
    }
  }

  void _startRadarCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          timer.cancel();
          _handleRadarTimeout();
        }
      });
    });
  }

  void _listenToRideStatus(String rideId) {
    _rideSubscription?.cancel();
    _rideSubscription =
        CustomerService.instance.streamRide(rideId).listen((ride) {
      if (!mounted || ride == null) return;

      // Tài xế đã bấm nhận cuốc!
      if (ride.status == RideStatus.accepted ||
          ride.status == RideStatus.arrivedPickup ||
          ride.status == RideStatus.inProgress) {
        _countdownTimer?.cancel();
        _rideSubscription?.cancel();

        setState(() => _isRadarScanning = false);

        AppLogger.userAction('RideBookingScreen', 'Tài xế đã nhận cuốc', {
          'rideId': ride.id,
          'driverName': ride.driverName,
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackingScreen.ride(rideId: ride.id),
          ),
        );
      }
    });
  }

  Future<void> _handleRadarTimeout() async {
    if (_activeRideId == null) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.schedule, color: AppColors.warning, size: 24),
            SizedBox(width: 8),
            Text('Chưa Có Tài Xế Nhận',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Hiện tại các tài xế quanh khu vực đều đang bận hoặc cách xa bạn.\nBạn có muốn tiếp tục tìm kiếm lại không?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Hủy yêu cầu',
                style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tìm kiếm lại (45s)'),
          ),
        ],
      ),
    );

    if (result == 'retry') {
      setState(() => _countdownSeconds = 45);
      _startRadarCountdown();
    } else {
      await _cancelActiveRide('Hết thời gian quét 45s không có tài xế', 'system');
    }
  }

  Future<void> _cancelActiveRide(String reason, String cancelledBy) async {
    _countdownTimer?.cancel();
    _rideSubscription?.cancel();

    if (_activeRideId != null) {
      await CustomerService.instance.cancelRide(
        rideId: _activeRideId!,
        reason: reason,
        cancelledBy: cancelledBy,
      );
    }

    if (!mounted) return;
    setState(() {
      _isRadarScanning = false;
      _activeRideId = null;
    });

    AppDialogs.showSuccess(
      context,
      title: 'Đã Hủy Yêu Cầu',
      message: 'Yêu cầu đặt xe của bạn đã được đóng an toàn.',
    );
  }

  Future<void> _showCancelConfirmation() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy Đặt Chuyến Đi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn có chắc chắn muốn hủy tìm kiếm tài xế?'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do hủy (không bắt buộc)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : 'Khách đổi ý hủy tìm xe';
      await _cancelActiveRide(reason, 'customer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. BẢN ĐỒ OPENSTREETMAP NỀN
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickupLatLng,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                key: ValueKey(_mapReloadToken),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.jet_post',
                maxZoom: 18,
              ),
              // Đường Polyline lộ trình
              if (_routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline,
                      strokeWidth: 5.0,
                      color: AppColors.routePolyline,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              // Marker Điểm đón & Điểm trả
              MarkerLayer(
                markers: [
                  // Marker điểm đón (xanh)
                  Marker(
                    point: _pickupLatLng,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                  // Marker điểm trả (đỏ cam)
                  if (_dropoffLatLng != null)
                    Marker(
                      point: _dropoffLatLng!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.secondary,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. KHUNG TÌM KIẾM & CHỌN ĐỊA ĐIỂM Ở TRÊN
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thanh Back & Tiêu đề
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            isDark ? AppColors.surfaceDark : Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: isDark ? Colors.white : Colors.black87,
                          onPressed: () {
                            if (_isRadarScanning) {
                              _showCancelConfirmation();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.electric_moped_rounded,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Đặt Xe Ôm JetBike',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Khối nhập Điểm Đón & Điểm Đến
                  if (!_isRadarScanning)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 50 : 25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Điểm đón
                          Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: AppColors.primary, size: 12),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _pickupAddress,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.my_location,
                                    color: AppColors.primary, size: 18),
                                tooltip: 'Cập nhật lại GPS',
                                onPressed: _getCurrentLocation,
                              ),
                            ],
                          ),
                          const Divider(height: 10),
                          // Điểm đến (Ô tìm kiếm)
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.secondary, size: 14),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _dropoffSearchController,
                                  focusNode: _dropoffFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Nhập địa chỉ đến của bạn...',
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
                              ),
                              if (_isSearchingPlace)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              else if (_dropoffSearchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _dropoffSearchController.clear();
                                    setState(() {
                                      _dropoffLatLng = null;
                                      _dropoffAddress = null;
                                      _routePolyline = [];
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

                  // Thanh chọn nhanh địa chỉ đã lưu
                  if (!_isRadarScanning && !_showSuggestions) ...[
                    const SizedBox(height: 8),
                    QuickAddressChips(
                      userId: _currentUser?.id ?? '',
                      onAddressSelected: _onSelectSavedAddress,
                    ),
                  ],

                  // Danh sách gợi ý tìm kiếm địa điểm (Google Maps Autocomplete Style)
                  if (!_isRadarScanning &&
                      _showSuggestions &&
                      (_placeSearchResults.isNotEmpty ||
                          _isSearchingPlace ||
                          _dropoffSearchController.text.trim().isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
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
                          // Header gợi ý
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 14, right: 8, top: 10, bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _dropoffSearchController.text.trim().isEmpty
                                      ? Icons.stars_rounded
                                      : Icons.search_rounded,
                                  color: AppColors.primary,
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
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      setState(() => _showSuggestions = false),
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

                          // Trạng thái Đang tìm kiếm (Loading)
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
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Đang tìm kiếm quanh vị trí của bạn...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // Trạng thái Không tìm thấy kết quả
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
                                    'Mẹo: Bạn có thể chạm tay trực tiếp vào bất kỳ vị trí nào trên bản đồ để ghim điểm đến!',
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
                          // Trạng thái Có kết quả gợi ý
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
                                                : AppColors.primary
                                                    .withAlpha(18),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${distKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
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
                ],
              ),
            ),
          ),

          // 3. RADAR SCANNING OVERLAY (KHI ĐANG QUÉT TÀI XẾ 45S)
          if (_isRadarScanning)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(160),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Vòng tròn xung kích Radar
                      AnimatedBuilder(
                        animation: _radarPulseController,
                        builder: (context, child) {
                          return Container(
                            width: 140 + (_radarPulseController.value * 50),
                            height: 140 + (_radarPulseController.value * 50),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withAlpha(
                                ((1.0 - _radarPulseController.value) * 120)
                                    .toInt(),
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.two_wheeler,
                                        color: Colors.white, size: 36),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_countdownSeconds s',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Đang Kết Nối Tài Xế Gần Nhất...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hệ thống đang phát cuốc xe tới các tài xế quanh ${_distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Nút Hủy cuốc trong lúc chờ
                      OutlinedButton.icon(
                        onPressed: _showCancelConfirmation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Hủy Tìm Xe'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. BOTTOM SHEET XÁC NHẬN GIÁ & ĐẶT XE (KHI ĐÃ CHỌN ĐIỂM ĐẾN)
          if (!_isRadarScanning && _dropoffLatLng != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 18,
                  bottom: bottomPadding + 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thanh gạt drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Thông số cước & Lộ trình
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.two_wheeler,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'JetBike Tiêu Chuẩn',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_distanceKm km • Khoảng ${_durationMinutes.toStringAsFixed(0)} phút',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Giá tiền Upfront
                        _isCalculatingRoute
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                CurrencyFormatter.format(_estimatedPrice),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Phương thức thanh toán Tiền mặt (CASH)
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Phương thức thanh toán:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Tiền mặt (CASH)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nút Đặt Xe Ngay
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCalculatingRoute ? null : _handleBookRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ĐẶT XE JETBIKE NGAY',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

