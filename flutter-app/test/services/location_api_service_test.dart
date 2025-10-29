import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:iot_ble_flutter_app/models/location_data.dart';
import 'package:iot_ble_flutter_app/services/location_api_service.dart';

void main() {
  group('LocationApiService', () {
    test('正常系: postLocationが201でLocationDataを返す', () async {
      final client = _FakeClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/locations');
        final body = jsonDecode(await _readRequestBody(request));
        expect(body['deviceId'], 'ESP');
        return http.Response(
          jsonEncode({
            'id': 1,
            'deviceId': 'ESP',
            'latitude': 10.0,
            'longitude': 20.0,
            'timestamp': '2025-01-01T00:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = LocationApiService(
        httpClient: client,
        baseUrl: 'http://localhost',
      );
      final data = LocationData(
        deviceId: 'ESP',
        latitude: 10,
        longitude: 20,
        timestamp: DateTime.utc(2025),
      );

      final result = await service.postLocation(data);
      expect(result.id, 1);
      expect(result.deviceId, 'ESP');
    });

    test('異常系: postLocationが400なら例外', () async {
      final client = _FakeClient((request) async {
        return http.Response('bad request', 400);
      });
      final service = LocationApiService(
        httpClient: client,
        baseUrl: 'http://localhost',
      );

      final data = LocationData(
        deviceId: 'ESP',
        latitude: 10,
        longitude: 20,
        timestamp: DateTime.utc(2025),
      );

      expect(
        () => service.postLocation(data),
        throwsA(isA<LocationApiException>()),
      );
    });

    test('境界値: fetchRecentLocationsが空配列でも成功する', () async {
      final client = _FakeClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });
      final service = LocationApiService(
        httpClient: client,
        baseUrl: 'http://localhost',
      );
      final list = await service.fetchRecentLocations();
      expect(list, isEmpty);
    });

    test('エッジケース: ネットワーク例外はFutureエラーになる', () async {
      final client = _FakeClient((request) async {
        throw http.ClientException('network down');
      });
      final service = LocationApiService(
        httpClient: client,
        baseUrl: 'http://localhost',
      );

      expect(
        () => service.fetchStats(),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    final stream =
        Stream<List<int>>.fromIterable(<List<int>>[response.bodyBytes]);
    return http.StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

Future<String> _readRequestBody(http.BaseRequest request) async {
  final builder = BytesBuilder();
  final stream = request.finalize();
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return utf8.decode(builder.toBytes());
}
