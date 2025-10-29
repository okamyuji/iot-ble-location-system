import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/location_data.dart';

/// Spring Bootサーバーと通信するサービス
class LocationApiService {
  LocationApiService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// 現在使用中のベースURLを取得
  String get baseUrl => _baseUrl;

  /// タイムアウト設定
  static const Duration _timeout =
      Duration(seconds: AppConfig.httpTimeoutSeconds);

  /// 位置情報をサーバーへ送信し、保存結果を返す
  Future<LocationData> postLocation(LocationData data) async {
    final uri = Uri.parse('$_baseUrl/api/locations');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(data.toApiJson()),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      return LocationData.fromApiJson(json);
    }

    throw LocationApiException(
      statusCode: response.statusCode,
      message: '位置情報の送信に失敗しました (${response.statusCode})',
      body: response.body,
    );
  }

  /// 最新50件の位置情報を取得
  Future<List<LocationData>> fetchRecentLocations() async {
    final uri = Uri.parse('$_baseUrl/api/locations/recent');
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList
          .cast<Map<String, dynamic>>()
          .map(LocationData.fromApiJson)
          .toList();
    }
    throw LocationApiException(
      statusCode: response.statusCode,
      message: '最新位置情報の取得に失敗しました',
      body: response.body,
    );
  }

  /// 統計情報を取得（デバイス数・登録件数など）
  Future<Map<String, dynamic>> fetchStats() async {
    final uri = Uri.parse('$_baseUrl/api/stats');
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw LocationApiException(
      statusCode: response.statusCode,
      message: '統計情報の取得に失敗しました',
      body: response.body,
    );
  }

  /// すべての位置情報を取得
  Future<List<LocationData>> fetchAllLocations() async {
    final uri = Uri.parse('$_baseUrl/api/locations');
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
      return jsonList
          .cast<Map<String, dynamic>>()
          .map(LocationData.fromApiJson)
          .toList();
    }
    throw LocationApiException(
      statusCode: response.statusCode,
      message: '位置情報一覧の取得に失敗しました',
      body: response.body,
    );
  }

  /// 明示的に破棄したい場合に利用する
  void dispose() {
    _client.close();
  }
}

/// API呼び出し失敗時の例外
class LocationApiException implements Exception {
  LocationApiException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() => 'LocationApiException($statusCode): $message';
}
