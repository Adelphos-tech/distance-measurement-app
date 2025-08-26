import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_uuids.dart';

class BleService {
  BleService();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;

  // Replace with actual service/characteristic UUIDs if the ESP exposes GATT services
  // For now we will discover all services and pick the first writable characteristic
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    // If already connected, skip connect call
    final BluetoothConnectionState current = await device.connectionState.first;
    if (current != BluetoothConnectionState.connected) {
      try {
        await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      } catch (e) {
        // If already connected by the OS, continue
        if (kDebugMode) {
          print('connect error: $e');
        }
      }
      // Wait for connected state
      try {
        await device.connectionState.firstWhere(
          (BluetoothConnectionState s) => s == BluetoothConnectionState.connected,
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        if (kDebugMode) {
          print('connection state wait failed: $e');
        }
      }
    }

    try {
      await device.discoverServices();
    } catch (_) {}
    await _findWritableCharacteristic(device);
    // Request larger MTU on Android for stability when writing commands
    try {
      await device.requestMtu(247);
    } catch (_) {}
  }

  Future<void> _findWritableCharacteristic(BluetoothDevice device) async {
    final List<BluetoothService> services = await device.discoverServices();
    // Prefer configured service/characteristic when provided
    if (BleUuids.preferredService != null || BleUuids.preferredWriteCharacteristic != null) {
      for (final BluetoothService s in services) {
        if (BleUuids.preferredService != null && s.uuid != BleUuids.preferredService) continue;
        for (final BluetoothCharacteristic c in s.characteristics) {
          if (BleUuids.preferredWriteCharacteristic != null && c.uuid != BleUuids.preferredWriteCharacteristic) continue;
          final bool canWrite = c.properties.write || c.properties.writeWithoutResponse;
          if (canWrite) {
            _writeCharacteristic = c;
            return;
          }
        }
      }
    }
    for (final BluetoothService service in services) {
      for (final BluetoothCharacteristic c in service.characteristics) {
        final bool canWrite = c.properties.write || c.properties.writeWithoutResponse;
        if (canWrite) {
          _writeCharacteristic = c;
          return;
        }
      }
    }
    if (kDebugMode) {
      print('No writable characteristic found');
    }
  }

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } finally {
      _device = null;
      _writeCharacteristic = null;
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


