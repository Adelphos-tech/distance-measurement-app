import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_uuids.dart';

class BleService {
  BleService();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  // Replace with actual service/characteristic UUIDs if the ESP exposes GATT services
  // For now we will discover all services and pick the first writable characteristic
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    // If already connected, skip connect call
    final BluetoothConnectionState current = await device.connectionState.first;
    if (current != BluetoothConnectionState.connected) {
      // Attempt connect with a couple of retries
      int attempts = 0;
      while (attempts < 2) {
        attempts += 1;
        try {
          await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
        } catch (e) {
          if (kDebugMode) {
            print('connect attempt $attempts error: $e');
          }
        }
        // Wait for connected state
        try {
          await device.connectionState
              .firstWhere((BluetoothConnectionState s) => s == BluetoothConnectionState.connected)
              .timeout(const Duration(seconds: 15));
          break; // connected
        } catch (e) {
          if (kDebugMode) {
            print('wait connected attempt $attempts failed: $e');
          }
        }
      }
    }

    // Confirm connected before discovering services
    final BluetoothConnectionState st = await device.connectionState.first;
    if (st != BluetoothConnectionState.connected) {
      throw Exception('Not connected');
    }
    await _findWritableCharacteristic(device);
    // Request larger MTU on Android for stability when writing commands
    try {
      await device.requestMtu(247);
    } catch (_) {}
  }

  Future<void> _findWritableCharacteristic(BluetoothDevice device) async {
    final List<BluetoothService> services = await device.discoverServices();
    // Prefer configured service/characteristic when provided
    if (BleUuids.preferredService != null || BleUuids.preferredWriteCharacteristic != null || BleUuids.preferredNotifyCharacteristic != null) {
      for (final BluetoothService s in services) {
        if (BleUuids.preferredService != null && s.uuid != BleUuids.preferredService) continue;
        for (final BluetoothCharacteristic c in s.characteristics) {
          final bool isPreferredWrite = BleUuids.preferredWriteCharacteristic != null && c.uuid == BleUuids.preferredWriteCharacteristic;
          final bool isPreferredNotify = BleUuids.preferredNotifyCharacteristic != null && c.uuid == BleUuids.preferredNotifyCharacteristic;
          if (isPreferredWrite && (c.properties.write || c.properties.writeWithoutResponse)) {
            _writeCharacteristic = c;
          }
          if (isPreferredNotify && c.properties.notify) {
            _notifyCharacteristic = c;
          }
        }
        if (_writeCharacteristic != null && (BleUuids.preferredNotifyCharacteristic == null || _notifyCharacteristic != null)) return;
      }
    }
    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic c in service.characteristics) {
        if (_writeCharacteristic == null && (c.properties.write || c.properties.writeWithoutResponse)) {
          _writeCharacteristic = c;
        }
        if (_notifyCharacteristic == null && c.properties.notify) {
          _notifyCharacteristic = c;
        }
      }
      if (_writeCharacteristic != null && _notifyCharacteristic != null) break;
    }
    if (kDebugMode) {
      print('No writable characteristic found');
    }
  }

  StreamSubscription<List<int>>? _notifySub;
  void subscribeNotifications(void Function(List<int> data) onData) {
    final BluetoothCharacteristic? c = _notifyCharacteristic;
    if (c == null) return;
    _notifySub?.cancel();
    c.setNotifyValue(true);
    _notifySub = c.onValueReceived.listen(onData, onError: (_) {});
  }

  Future<void> disconnect() async {
    try {
      await _notifySub?.cancel();
      await _device?.disconnect();
    } finally {
      _device = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
    }
  }

  Future<void> sendCommand(Uint8List data) async {
    if (_writeCharacteristic == null) {
      // try to rediscover
      if (_device != null) {
        await _findWritableCharacteristic(_device!);
      }
    }
    final BluetoothCharacteristic? characteristic = _writeCharacteristic;
    if (characteristic == null) return;
    try {
      await characteristic.write(data, withoutResponse: characteristic.properties.writeWithoutResponse);
    } catch (e) {
      if (kDebugMode) {
        print('Write failed: $e');
      }
    }
  }

  Timer? _rssiTimer;
  void startRssiPolling(BluetoothDevice device, void Function(int rssi) onRssi) {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final int rssi = await device.readRssi();
        onRssi(rssi);
      } catch (_) {}
    });
  }

  void stopRssiPolling() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
  }
}


