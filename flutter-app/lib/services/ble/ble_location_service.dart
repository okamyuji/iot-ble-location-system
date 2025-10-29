import 'dart:async';
import 'dart:convert';

import '../../models/location_data.dart';
import 'ble_adapter.dart';

/// BLEから位置情報のJSON通知を受け取り解析するサービス
class BleLocationService {
  BleLocationService({BleAdapter? adapter})
      : _adapter = adapter ?? FlutterBleAdapter() {
    _scanSubscription = _adapter.scanResults.listen((devices) {
      for (final device in devices) {
        _latestRssi[device.deviceId] = device.rssi;
      }
    });
  }

  final BleAdapter _adapter;
  final Map<String, int?> _latestRssi = {};

  StreamSubscription<List<BleDeviceSummary>>? _scanSubscription;

  Stream<List<BleDeviceSummary>> get scanResults => _adapter.scanResults;

  Future<void> startScan() => _adapter.startScan();

  Future<void> stopScan() => _adapter.stopScan();

  Future<void> connect(String deviceId) async {
    await _adapter.connect(deviceId);
    await _adapter.enableNotification(deviceId);
  }

  Future<void> disconnect(String deviceId) => _adapter.disconnect(deviceId);

  /// 指定デバイスから通知される位置情報をストリームで取得
  Stream<LocationData> listenLocationUpdates(String deviceId) async* {
    final fallbackRssi = _latestRssi[deviceId];

    final rssi = await _adapter.readRssi(deviceId) ?? fallbackRssi;

    await for (final value in _adapter.onValueChanged(deviceId)) {
      if (value.isEmpty) {
        continue;
      }
      final payload = utf8.decode(value);
      final location =
          LocationData.tryParseBlePayload(payload, fallbackRssi: rssi);
      if (location != null) {
        _latestRssi[deviceId] = location.rssi ?? rssi;
        yield location;
      }
    }
  }

  Future<int?> latestRssi(String deviceId) async {
    final current = _latestRssi[deviceId];
    final rssi = await _adapter.readRssi(deviceId);
    if (rssi != null) {
      _latestRssi[deviceId] = rssi;
      return rssi;
    }
    return current;
  }

  Future<void> dispose() async {
    await _scanSubscription?.cancel();
    await _adapter.dispose();
  }
}
