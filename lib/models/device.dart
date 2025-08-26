import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DiscoveredDevice {
  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });

  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;
}


