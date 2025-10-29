import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:iot_ble_flutter_app/models/location_data.dart';
import 'package:iot_ble_flutter_app/providers/location_sync_controller.dart';
import 'package:iot_ble_flutter_app/services/ble/ble_adapter.dart';
import 'package:iot_ble_flutter_app/services/ble/ble_location_service.dart';
import 'package:iot_ble_flutter_app/services/location_api_service.dart';

void main() {
  group('LocationSyncController', () {
    late FakeLocationApiService api;
    late _TestBleAdapter adapter;
    late BleLocationService ble;
    late LocationSyncController controller;

    setUp(() {
      api = FakeLocationApiService();
      adapter = _TestBleAdapter();
      ble = BleLocationService(adapter: adapter);
      controller = LocationSyncController(
        apiService: api,
        bleService: ble,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('正常系: BLE受信で自動送信と履歴更新が行われる', () async {
      api.stats = {'totalLocations': 1, 'deviceCount': 1};
      adapter.emitScanResult(
        const BleDeviceSummary(deviceId: 'DEV', name: 'test', rssi: -55),
      );

      await controller.connectToDevice('DEV');

      await Future<void>.delayed(Duration.zero);

      adapter.emitNotification('DEV', {
        'deviceId': 'DEV',
        'lat': 35.0,
        'lon': 139.0,
        'timestamp': '2025-01-01T12:00:00Z',
      });

      await _waitFor(() => controller.latestBleLocation != null);
      await _waitFor(() => controller.history.isNotEmpty);

      expect(controller.latestBleLocation, isNotNull);
      expect(controller.history, isNotEmpty);
      expect(controller.history.first.success, isTrue);
      expect(controller.lastSentLocation?.deviceId, 'DEV');
    });

    test('異常系: 検証エラーは送信せず履歴に残す', () async {
      await controller.sendLocation(LocationData(
        deviceId: '',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now().toUtc(),
      ));

      expect(controller.history.length, 1);
      expect(controller.history.first.success, isFalse);
      expect(controller.lastError, contains('送信前検証エラー'));
    });

    test('エッジケース: API失敗は履歴に失敗として記録される', () async {
      api.postError = Exception('server down');

      await controller.sendLocation(LocationData(
        deviceId: 'DEV',
        latitude: 10,
        longitude: 20,
        timestamp: DateTime.now().toUtc(),
      ));

      expect(controller.history.first.success, isFalse);
      expect(controller.history.first.errorMessage, contains('失敗'));
    });
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class FakeLocationApiService extends LocationApiService {
  FakeLocationApiService()
      : super(
          httpClient: _DummyClient(),
          baseUrl: 'http://localhost',
        );

  List<LocationData> recent = const [];
  Map<String, dynamic>? stats;
  Exception? postError;

  @override
  Future<LocationData> postLocation(LocationData data) async {
    if (postError != null) {
      throw postError!;
    }
    final saved = data.copyWith(id: 1);
    recent = [saved];
    return saved;
  }

  @override
  Future<List<LocationData>> fetchRecentLocations() async {
    return recent;
  }

  @override
  Future<Map<String, dynamic>> fetchStats() async {
    if (stats == null) {
      throw Exception('no stats');
    }
    return stats!;
  }

  @override
  void dispose() {}
}

class _DummyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }
}

class _TestBleAdapter implements BleAdapter {
  final StreamController<List<BleDeviceSummary>> scanController =
      StreamController<List<BleDeviceSummary>>.broadcast();
  final Map<String, StreamController<List<int>>> _notifyControllers = {};

  int? rssi = -60;

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
    return _controller(deviceId).stream;
  }

  @override
  Future<int?> readRssi(String deviceId) async => rssi;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> dispose() async {
    await scanController.close();
    for (final controller in _notifyControllers.values) {
      await controller.close();
    }
    _notifyControllers.clear();
  }

  void emitNotification(String deviceId, Map<String, dynamic> data) {
    final json = jsonEncode(data);
    _controller(deviceId).add(utf8.encode(json));
  }

  void emitScanResult(BleDeviceSummary summary) {
    scanController.add([summary]);
  }

  StreamController<List<int>> _controller(String deviceId) {
    return _notifyControllers.putIfAbsent(
      deviceId,
      () => StreamController<List<int>>.broadcast(),
    );
  }
}
