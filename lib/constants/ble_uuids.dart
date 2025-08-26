import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleUuids {
  // If your ESP32 exposes known service/characteristic UUIDs, set them here.
  // Leave as null to auto-discover first writable characteristic.
  static const Guid? preferredService = null; // e.g., Guid("0000ffe0-0000-1000-8000-00805f9b34fb")
  static const Guid? preferredWriteCharacteristic = null; // e.g., Guid("0000ffe1-0000-1000-8000-00805f9b34fb")
}


