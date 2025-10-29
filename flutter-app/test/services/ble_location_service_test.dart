import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:iot_ble_flutter_app/services/ble/ble_adapter.dart';
import 'package:iot_ble_flutter_app/services/ble/ble_location_service.dart';

void main() {
  group('BleLocationService', () {
    test('正常系: 通知からLocationDataを生成する', () async {
      final adapter = _FakeBleAdapter();
      final service = BleLocationService(adapter: adapter);
      const deviceId = 'DEV001';

      await service.connect(deviceId);

      final future = service.listenLocationUpdates(deviceId).first;

      await Future<void>.delayed(Duration.zero);

      adapter.emitNotification(deviceId, {
        'deviceId': deviceId,
        'lat': 35.0,
        'lon': 139.0,
        'timestamp': '2025-01-01T12:00:00Z',
      });

      final result = await future;
      expect(result.deviceId, deviceId);
      expect(result.latitude, 35.0);
      expect(result.longitude, 139.0);
    });

    test('異常系: 無効なJSONはスキップされる', () async {
      final adapter = _FakeBleAdapter();
      final service = BleLocationService(adapter: adapter);
      const deviceId = 'DEV001';

      await service.connect(deviceId);

      final future = service.listenLocationUpdates(deviceId).first;

      await Future<void>.delayed(Duration.zero);

      adapter.emitRaw(deviceId, '{invalid');
      adapter.emitNotification(deviceId, {
        'deviceId': deviceId,
        'lat': 33.3,
        'lon': 130.0,
      });

      final result = await future;
      expect(result.latitude, 33.3);
    });

    test('境界値: RSSIを取得できない場合はスキャン値を利用', () async {
      final adapter = _FakeBleAdapter()..mockRssi = null;
      final service = BleLocationService(adapter: adapter);
      const deviceId = 'DEV002';

      adapter.emitScanResult(
        const BleDeviceSummary(deviceId: deviceId, name: 'test', rssi: -70),
      );

      await service.connect(deviceId);

      final resultFuture = service.listenLocationUpdates(deviceId).first;

      await Future<void>.delayed(Duration.zero);

      adapter.emitNotification(deviceId, {
        'deviceId': deviceId,
        'lat': 10.0,
        'lon': 20.0,
      });

      final result = await resultFuture;
      expect(result.rssi, -70);
    });
  });
}

class _FakeBleAdapter implements BleAdapter {
  final StreamController<List<BleDeviceSummary>> scanController =
      StreamController<List<BleDeviceSummary>>.broadcast();
  final Map<String, StreamController<List<int>>> _notifications = {};

  int? mockRssi = -60;

  @override
  Stream<List<BleDeviceSummary>> get scanResults => scanController.stream;

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> enableNotification(String deviceId) async {}

  @override
  Stream<List<int>> onValueChanged(String deviceId) {
    return _controllerFor(deviceId).stream;
  }

  @override
  Future<int?> readRssi(String deviceId) async => mockRssi;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> dispose() async {
    await scanController.close();
    for (final controller in _notifications.values) {
      await controller.close();
    }
    _notifications.clear();
  }

  void emitNotification(String deviceId, Map<String, dynamic> json) {
    final payload = utf8.encode(jsonEncode(json));
    _controllerFor(deviceId).add(payload);
  }

  void emitRaw(String deviceId, String raw) {
    _controllerFor(deviceId).add(utf8.encode(raw));
  }

  void emitScanResult(BleDeviceSummary summary) {
    scanController.add([summary]);
  }

  StreamController<List<int>> _controllerFor(String deviceId) {
    return _notifications.putIfAbsent(
      deviceId,
      () => StreamController<List<int>>.broadcast(),
    );
  }
}
