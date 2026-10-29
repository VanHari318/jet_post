import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverOrderPreferencesValue {
  final bool autoAcceptRides;
  final double rideMaxDistanceKm;
  final bool autoAcceptDeliveries;
  final double deliveryMaxDistanceKm;
  final double deliveryCodLimit;

  const DriverOrderPreferencesValue({
    this.autoAcceptRides = false,
    this.rideMaxDistanceKm = 5,
    this.autoAcceptDeliveries = false,
    this.deliveryMaxDistanceKm = 5,
    this.deliveryCodLimit = 0,
  });

  DriverOrderPreferencesValue copyWith({
    bool? autoAcceptRides,
    double? rideMaxDistanceKm,
    bool? autoAcceptDeliveries,
    double? deliveryMaxDistanceKm,
    double? deliveryCodLimit,
  }) {
    return DriverOrderPreferencesValue(
      autoAcceptRides: autoAcceptRides ?? this.autoAcceptRides,
      rideMaxDistanceKm: rideMaxDistanceKm ?? this.rideMaxDistanceKm,
      autoAcceptDeliveries: autoAcceptDeliveries ?? this.autoAcceptDeliveries,
      deliveryMaxDistanceKm:
          deliveryMaxDistanceKm ?? this.deliveryMaxDistanceKm,
      deliveryCodLimit: deliveryCodLimit ?? this.deliveryCodLimit,
    );
  }
}

class DriverOrderPreferences {
  DriverOrderPreferences._();

  static final DriverOrderPreferences instance = DriverOrderPreferences._();

  static const _rideAutoKey = 'driver_auto_accept_rides';
  static const _rideDistanceKey = 'driver_ride_max_distance_km';
  static const _deliveryAutoKey = 'driver_auto_accept_deliveries';
  static const _deliveryDistanceKey = 'driver_delivery_max_distance_km';
  static const _codLimitKey = 'driver_delivery_cod_limit';

  final ValueNotifier<DriverOrderPreferencesValue> value = ValueNotifier(
    const DriverOrderPreferencesValue(),
  );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value.value = DriverOrderPreferencesValue(
      autoAcceptRides: prefs.getBool(_rideAutoKey) ?? false,
      rideMaxDistanceKm: prefs.getDouble(_rideDistanceKey) ?? 5,
      autoAcceptDeliveries: prefs.getBool(_deliveryAutoKey) ?? false,
      deliveryMaxDistanceKm: prefs.getDouble(_deliveryDistanceKey) ?? 5,
      deliveryCodLimit: prefs.getDouble(_codLimitKey) ?? 0,
    );
  }

  Future<void> update(DriverOrderPreferencesValue updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rideAutoKey, updated.autoAcceptRides);
    await prefs.setDouble(_rideDistanceKey, updated.rideMaxDistanceKm);
    await prefs.setBool(_deliveryAutoKey, updated.autoAcceptDeliveries);
    await prefs.setDouble(_deliveryDistanceKey, updated.deliveryMaxDistanceKm);
    await prefs.setDouble(_codLimitKey, updated.deliveryCodLimit);
    value.value = updated;
  }
}
