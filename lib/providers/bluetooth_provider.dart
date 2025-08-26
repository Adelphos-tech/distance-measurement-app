import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
// Uint8List available via flutter foundation export

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ble_service.dart';
import '../utils/distance.dart';
import '../models/device.dart';
import '../constants/commands.dart';
import '../constants/ble_uuids.dart';

class BluetoothProvider extends ChangeNotifier {
  BluetoothProvider() {
    // Observe adapter state and reflect in UI
    _adapterSub = FlutterBluePlus.adapterState.listen((BluetoothAdapterState s) {
      _adapterState = s;
      notifyListeners();
    });
  }

  final BleService _bleService = BleService();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Distance calculation parameters
  int _txPowerAtOneMeter = -59; // default calibration
  double _pathLossExponent = 2.0; // environment factor
  double _thresholdFeet = 8.0; // default user threshold in feet
  bool _useFeet = true; // true => feet, false => meters
  bool _audioFeedbackEnabled = true;
  double _audioVolume = 0.1; // 0.0 - 1.0
  bool _autoConnectEnabled = false;

  int get txPowerAtOneMeter => _txPowerAtOneMeter;
  double get pathLossExponent => _pathLossExponent;
  double get thresholdFeet => _thresholdFeet;
  bool get useFeet => _useFeet;
  bool get audioFeedbackEnabled => _audioFeedbackEnabled;
  double get audioVolume => _audioVolume;
  bool get autoConnectEnabled => _autoConnectEnabled;

  // Last ACK/status received from peripheral via notifications
  String? _lastAckStatus;
  String? get lastAckStatus => _lastAckStatus;

  void updateCalibration({int? txPower, double? pathLossExponent}) {
    if (txPower != null) _txPowerAtOneMeter = txPower;
    if (pathLossExponent != null) _pathLossExponent = pathLossExponent;
    notifyListeners();
  }

  void updateThresholdFeet(double value) {
    _thresholdFeet = value;
    notifyListeners();
  }

  void toggleUnit() {
    _useFeet = !_useFeet;
    notifyListeners();
  }

  void setAudioFeedback(bool value) {
    _audioFeedbackEnabled = value;
    notifyListeners();
  }

  void setAudioVolume(double value) {
    _audioVolume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setAutoConnect(bool value) {
    _autoConnectEnabled = value;
    notifyListeners();
  }

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<int>? _rssiSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothAdapterState get adapterState => _adapterState;

  int? _latestRssi;
  int? get latestRssi => _latestRssi;

  // RSSI smoothing (exponential moving average)
  double? _emaRssi;
  double _smoothingAlpha = 0.3; // 0..1, higher = more responsive
  // Hysteresis: percent of threshold for exit band (e.g., 10%)
  double _hysteresisFraction = 0.1;
  // Rate limit for command sends
  DateTime _lastCommandSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _minCommandInterval = const Duration(milliseconds: 800);
  String? _namePrefix; // optional runtime filter

  // Expose tuning APIs
  void setSmoothingAlpha(double alpha) {
    // constrain [0.0, 1.0]
    final double a = alpha.clamp(0.0, 1.0);
    // reinitialize smoothing to avoid long tail if alpha changes drastically
    _emaRssi = null;
    _smoothingAlpha = a;
    notifyListeners();
  }

  void setHysteresisFraction(double fraction) {
    _hysteresisFraction = fraction.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setMinCommandInterval(Duration d) {
    _minCommandInterval = d;
    notifyListeners();
  }

  void setNamePrefixFilter(String? prefix) {
    _namePrefix = (prefix == null || prefix.isEmpty) ? null : prefix;
    notifyListeners();
  }

  double? get latestDistanceMeters => _emaRssi == null
      ? null
      : DistanceUtils.estimateDistanceMeters(
          txPower: _txPowerAtOneMeter,
          rssi: _emaRssi!.round(),
          pathLossExponent: _pathLossExponent,
        );

  double? get latestDistanceFeet => latestDistanceMeters == null
      ? null
      : DistanceUtils.metersToFeet(latestDistanceMeters!);

  String get formattedDistance {
    final double? meters = latestDistanceMeters;
    if (meters == null) return '0.0';
    if (_useFeet) {
      return DistanceUtils.metersToFeet(meters).toStringAsFixed(1);
    }
    return meters.toStringAsFixed(1);
  }

  bool _lastInRange = true;

  // Getters for settings UI
  double get smoothingAlpha => _smoothingAlpha;
  double get hysteresisFraction => _hysteresisFraction;
  Duration get minCommandInterval => _minCommandInterval;
  String? get namePrefixFilter => _namePrefix;

  Future<bool> ensurePermissions() async {
    if (Platform.isIOS) {
      // iOS handles CoreBluetooth permission implicitly via Info.plist usage keys
      return true;
    }
    final List<Permission> toRequest = <Permission>[];
    if (!Platform.isIOS) {
      toRequest.addAll(<Permission>[Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse]);
    }
    final Map<Permission, PermissionStatus> result = await toRequest.request();
    return result.values.every((PermissionStatus s) => s.isGranted);
  }

  Future<void> startScan({String? namePrefix}) async {
    final bool granted = await ensurePermissions();
    if (!granted) {
      _isScanning = false;
      notifyListeners();
      return;
    }
    // Ensure adapter is on
    final BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _isScanning = false;
      notifyListeners();
      return;
    }
    if (_isScanning) return;
    _devices.clear();
    _isScanning = true;
    notifyListeners();

    // Build filters if service UUID known
    final List<Guid> serviceFilters = <Guid>[];
    if (BleUuids.preferredService != null) {
      serviceFilters.add(BleUuids.preferredService!);
    }
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
      withServices: serviceFilters,
    );

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((List<ScanResult> results) {
      for (final ScanResult r in results) {
        final String? deviceName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        final String? effectivePrefix = namePrefix ?? _namePrefix ?? BleUuids.namePrefix;
        if (effectivePrefix != null && (deviceName == null || !deviceName.startsWith(effectivePrefix))) {
          continue;
        }
        final DiscoveredDevice device = DiscoveredDevice(
          id: r.device.remoteId.str,
          name: deviceName ?? 'Unknown',
          rssi: r.rssi,
          device: r.device,
        );
        final int existingIndex = _devices.indexWhere((d) => d.id == device.id);
        if (existingIndex >= 0) {
          _devices[existingIndex] = device;
        } else {
          _devices.add(device);
        }
      }
      notifyListeners();
    }, onError: (Object e) {
      if (kDebugMode) {
        print('Scan error: $e');
      }
    }, onDone: () async {
      _isScanning = false;
      notifyListeners();
      await FlutterBluePlus.stopScan();
    });
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connect(DiscoveredDevice device) async {
    await stopScan();
    _connectedDevice = device.device;
    await _bleService.connect(device.device);
    // subscribe to notifications for ACK/status
    _bleService.subscribeNotifications(_onNotifyData);
    _subscribeRssi(device.device);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _rssiSub?.cancel();
    await _bleService.disconnect();
    _connectedDevice = null;
    notifyListeners();
  }

  void _subscribeRssi(BluetoothDevice device) {
    _rssiSub?.cancel();
    _rssiSub = Stream<int>.periodic(const Duration(seconds: 2)).listen((_) {});
    _bleService.startRssiPolling(device, (int rssi) {
      _latestRssi = rssi;
      // EMA smoothing: ema = alpha * rssi + (1-alpha) * prev
      final double alpha = _smoothingAlpha;
      _emaRssi = _emaRssi == null ? rssi.toDouble() : (alpha * rssi + (1 - alpha) * _emaRssi!);
      _handleThreshold();
      notifyListeners();
    });
  }

  void _onNotifyData(List<int> data) {
    // Expected ACK format: 0x5E 0x80 <cmd> <status>
    if (data.isEmpty) return;
    if (data.length >= 4 && data[0] == Commands.security && data[1] == 0x80) {
      final int cmd = data[2];
      final int status = data[3];
      final bool ok = status == 0x00;
      _lastAckStatus = 'ACK for 0x${cmd.toRadixString(16).padLeft(2, '0')}: ' + (ok ? 'OK' : 'ERR 0x${status.toRadixString(16).padLeft(2, '0')}');
      notifyListeners();
    }
  }

  void _handleThreshold() {
    final double? distanceFeet = latestDistanceFeet;
    if (distanceFeet == null) return;

    // Hysteresis bands
    final double enterThreshold = _thresholdFeet; // go in-range when <= this
    final double exitThreshold = _thresholdFeet * (1 + _hysteresisFraction); // go out-of-range when > this

    bool inRange;
    if (_lastInRange) {
      inRange = distanceFeet <= exitThreshold;
    } else {
      inRange = distanceFeet <= enterThreshold;
    }

    if (inRange != _lastInRange && _connectedDevice != null) {
      // rate limit
      final DateTime now = DateTime.now();
      if (now.difference(_lastCommandSentAt) < _minCommandInterval) {
        _lastInRange = inRange; // update state but skip command
        return;
      }
      // Send appropriate command when crossing threshold
      final Uint8List command = inRange
          ? Uint8List.fromList(Commands.inRange)
          : Uint8List.fromList(Commands.crossedRange);
      _bleService.sendCommand(command);
      _lastCommandSentAt = now;
      // Optionally play feedback; platform integration for audio can be added later
    }
    _lastInRange = inRange;
  }

  Future<void> sendToggleLed(bool enable) async {
    final List<int> cmd = enable ? Commands.enableLed : Commands.disableLed;
    await _bleService.sendCommand(Uint8List.fromList(cmd));
  }

  Future<void> sendToggleVibrator(bool enable) async {
    final List<int> cmd = enable ? Commands.enableVibrator : Commands.disableVibrator;
    await _bleService.sendCommand(Uint8List.fromList(cmd));
  }

  Future<void> sendCustomName(String name) async {
    final List<int> prefix = Commands.setCustomNamePrefix;
    final List<int> ascii = utf8.encode(name.length > 11 ? name.substring(0, 11) : name);
    await _bleService.sendCommand(Uint8List.fromList(<int>[...prefix, ...ascii]));
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _rssiSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }
}


