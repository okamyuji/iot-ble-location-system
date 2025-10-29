import 'package:flutter_test/flutter_test.dart';

import 'package:iot_ble_flutter_app/models/location_data.dart';

void main() {
  group('LocationData.fromBleJson', () {
    test('正常系: BLE JSONを正しく解析できる', () {
      final json = {
        'deviceId': 'ESP32-001',
        'lat': 35.0,
        'lon': 139.0,
        'alt': 12.3,
        'accuracy': 4.5,
        'rssi': -42,
        'timestamp': '2025-01-01T12:00:00Z',
      };

      final data = LocationData.fromBleJson(json);

      expect(data.deviceId, 'ESP32-001');
      expect(data.latitude, 35.0);
      expect(data.longitude, 139.0);
      expect(data.altitude, 12.3);
      expect(data.rssi, -42);
      expect(data.timestamp.toUtc().toIso8601String(),
          '2025-01-01T12:00:00.000Z');
    });

    test('異常系: deviceId欠如は検証エラーになる', () {
      final json = {'lat': 35.0, 'lon': 139.0};
      final data = LocationData.fromBleJson(json);
      final errors = data.validate();
      expect(errors, contains('デバイスIDが空です'));
    });

    test('境界値: 緯度の上限値90度でエラーにならない', () {
      final json = {
        'deviceId': 'EDGE',
        'lat': 90.0,
        'lon': 0.0,
      };
      final data = LocationData.fromBleJson(json);
      expect(data.latitude, 90.0);
      expect(data.validate(), isEmpty);
    });

    test('境界値: 経度の下限値-180度でエラーにならない', () {
      final json = {
        'deviceId': 'EDGE',
        'lat': 0.0,
        'lon': -180.0,
      };
      final data = LocationData.fromBleJson(json);
      expect(data.longitude, -180.0);
      expect(data.validate(), isEmpty);
    });

    test('エッジケース: 無効なJSON文字列はnullを返す', () {
      final data =
          LocationData.tryParseBlePayload('{invalid-json', fallbackRssi: -60);
      expect(data, isNull);
    });

    test('異常系: 未来時刻は検証エラーになる', () {
      final future = DateTime.now().add(const Duration(hours: 1)).toUtc();
      final json = {
        'deviceId': 'ESP32',
        'lat': 35.0,
        'lon': 139.0,
        'timestamp': future.toIso8601String(),
      };
      final data = LocationData.fromBleJson(json);
      final errors = data.validate();
      expect(errors.first, contains('タイムスタンプが未来'));
    });
  });

  group('LocationData API 変換', () {
    test('正常系: toApiJsonが必要なフィールドを含む', () {
      final data = LocationData(
        deviceId: 'ESP',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime.utc(2025, 1, 1),
      );
      final json = data.toApiJson();
      expect(json['deviceId'], 'ESP');
      expect(json['latitude'], 10.0);
      expect(json['longitude'], 20.0);
      expect(json['timestamp'], '2025-01-01T00:00:00.000Z');
    });
  });
}
