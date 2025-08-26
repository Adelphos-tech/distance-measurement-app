import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleUuids {
  // If your ESP32 exposes known service/characteristic UUIDs, set them here.
  // Leave as null to auto-discover first writable characteristic.
  static const Guid? preferredService = null; // e.g., Guid("0000ffe0-0000-1000-8000-00805f9b34fb")
  static const Guid? preferredWriteCharacteristic = null; // e.g., Guid("0000ffe1-0000-1000-8000-00805f9b34fb")
  static const Guid? preferredNotifyCharacteristic = null; // e.g., Guid("0000ffe2-0000-1000-8000-00805f9b34fb")

  // Optional friendly filter: if set, only show devices whose name starts with this prefix
  static const String? namePrefix = null; // e.g., "ESP32-DIST"
}


