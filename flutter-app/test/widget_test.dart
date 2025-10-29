import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:iot_ble_flutter_app/config/app_config.dart';
import 'package:iot_ble_flutter_app/models/location_data.dart';
import 'package:iot_ble_flutter_app/providers/location_sync_controller.dart';
import 'package:iot_ble_flutter_app/screens/home_screen.dart';
import 'package:iot_ble_flutter_app/services/ble/ble_adapter.dart';
import 'package:iot_ble_flutter_app/services/ble/ble_location_service.dart';
import 'package:iot_ble_flutter_app/services/location_api_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('HomeScreenのタブが表示される', (tester) async {
    final api = _WidgetFakeApiService();
    final adapter = _WidgetFakeBleAdapter();
    final controller = LocationSyncController(
      apiService: api,
      bleService: BleLocationService(adapter: adapter),
    );
    addTearDown(() {
      controller.dispose();
      adapter.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<LocationSyncController>.value(
        value: controller,
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    expect(find.text('デバイス'), findsOneWidget);
    expect(find.text('受信/送信'), findsOneWidget);
    expect(find.text('サーバー'), findsOneWidget);
  });
}

class _WidgetFakeApiService extends LocationApiService {
  _WidgetFakeApiService()
      : super(
          httpClient: _NoopClient(),
          baseUrl: AppConfig.apiBaseUrl,
        );

  @override
  Future<LocationData> postLocation(LocationData data) async {
    return data;
  }

  @override
  Future<List<LocationData>> fetchRecentLocations() async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> fetchStats() async {
    return const {'totalLocations': 0, 'deviceCount': 0};
  }

  @override
  void dispose() {}
}

class _NoopClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }
}

class _WidgetFakeBleAdapter implements BleAdapter {
  final StreamController<List<BleDeviceSummary>> _scanController =
      StreamController<List<BleDeviceSummary>>.broadcast();
  final StreamController<List<int>> _notifController =
      StreamController<List<int>>.broadcast();

  @override
  Stream<List<BleDeviceSummary>> get scanResults => _scanController.stream;

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> enableNotification(String deviceId) async {}

  @override
  Stream<List<int>> onValueChanged(String deviceId) => _notifController.stream;

  @override
  Future<int?> readRssi(String deviceId) async => -60;

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> dispose() async {
    await _scanController.close();
    await _notifController.close();
  }
}
