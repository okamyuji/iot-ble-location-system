import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_config.dart';
import '../../models/location_data.dart';

/// BLE Peripheral（送信）サービス
///
/// このデバイスをBLEビーコンとして動作させ、
/// 位置情報を周囲のデバイスにブロードキャストします。
class BlePeripheralService {
  BlePeripheralService();

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  Timer? _updateTimer;
  Position? _lastKnownPosition; // 最後に取得成功した位置情報をキャッシュ

  /// 現在アドバタイジング中かどうか
  bool get isAdvertising => _isAdvertising;

  /// BLE送信を開始
  ///
  /// このデバイスをBLEビーコンとして動作させます。
  /// 定期的に位置情報を更新してブロードキャストします。
  Future<void> startAdvertising() async {
    debugPrint('[BLE Peripheral] アドバタイジング開始要求');

    try {
      // 初回の位置情報を送信
      await _advertiseCurrentLocation();

      _isAdvertising = true;
      debugPrint('[BLE Peripheral] アドバタイジング開始成功');

      // 10秒ごとに位置情報を更新
      _updateTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _advertiseCurrentLocation(),
      );
    } catch (e, stackTrace) {
      debugPrint('[BLE Peripheral] アドバタイジング開始エラー: $e');
      debugPrint('[BLE Peripheral] スタックトレース: $stackTrace');
      _isAdvertising = false;
      rethrow;
    }
  }

  /// BLE送信を停止
  Future<void> stopAdvertising() async {
    debugPrint('[BLE Peripheral] アドバタイジング停止要求');

    _updateTimer?.cancel();
    _updateTimer = null;

    try {
      await _peripheral.stop();
      _isAdvertising = false;
      debugPrint('[BLE Peripheral] アドバタイジング停止成功');
    } catch (e) {
      debugPrint('[BLE Peripheral] アドバタイジング停止エラー: $e');
      _isAdvertising = false;
    }
  }

  /// 現在の位置情報をアドバタイズ
  Future<void> _advertiseCurrentLocation() async {
    try {
      // 実際のGPS位置情報を取得
      final position = await _getCurrentPosition();

      Position? positionToUse;

      if (position == null) {
        // GPS取得失敗時は最後に成功した位置情報を使用
        if (_lastKnownPosition != null) {
          debugPrint('[BLE Peripheral] GPS取得失敗。最後に成功した位置情報を使用します');
          positionToUse = _lastKnownPosition;
        } else {
          debugPrint('[BLE Peripheral] GPS位置情報の取得に失敗しました（キャッシュなし）');
          return;
        }
      } else {
        // GPS取得成功時はキャッシュを更新
        _lastKnownPosition = position;
        positionToUse = position;
        debugPrint('[BLE Peripheral] GPS位置情報取得成功: '
            'lat=${position.latitude}, lon=${position.longitude}, accuracy=${position.accuracy}');
      }

      // positionToUseがnullの場合は既にreturnしているため、ここでは必ずnon-null
      if (positionToUse == null) return;

      // 実際のGPS位置情報を使用
      final location = LocationData(
        deviceId: 'iOS-BLE-Beacon',
        latitude: positionToUse.latitude,
        longitude: positionToUse.longitude,
        accuracy: positionToUse.accuracy,
        rssi: -60,
        timestamp: DateTime.now(),
      );

      debugPrint('[BLE Peripheral] 位置情報をアドバタイズ: '
          'lat=${location.latitude}, lon=${location.longitude}');

      // 位置情報をJSONに変換
      final jsonData = jsonEncode(location.toApiJson());
      debugPrint('[BLE Peripheral] JSON: $jsonData');

      // アドバタイジング開始
      await _peripheral.start(
        advertiseData: AdvertiseData(
          serviceUuid: AppConfig.locationServiceUuid,
          localName: 'IoT-BLE-${location.deviceId.substring(0, 4)}',
          manufacturerData: utf8.encode(jsonData),
          includeDeviceName: false,
        ),
      );

      debugPrint('[BLE Peripheral] アドバタイズ成功');
    } catch (e, stackTrace) {
      debugPrint('[BLE Peripheral] アドバタイズエラー: $e');
      debugPrint('[BLE Peripheral] スタックトレース: $stackTrace');
    }
  }

  /// 現在のGPS位置情報を取得
  ///
  /// 位置情報サービスが無効、または権限がない場合はnullを返します。
  Future<Position?> _getCurrentPosition() async {
    try {
      // 位置情報サービスが有効かチェック
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] 位置情報サービスが無効です');
        return null;
      }

      // 位置情報の権限をチェック
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[GPS] 位置情報の権限が拒否されています');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GPS] 位置情報の権限リクエストが拒否されました');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] 位置情報の権限が恒久的に拒否されています');
        return null;
      }

      // 現在位置を取得
      debugPrint('[GPS] 位置情報を取得中...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return position;
    } catch (e, stackTrace) {
      debugPrint('[GPS] 位置情報取得エラー: $e');
      debugPrint('[GPS] スタックトレース: $stackTrace');
      return null;
    }
  }

  /// リソースを解放
  Future<void> dispose() async {
    await stopAdvertising();
  }
}
