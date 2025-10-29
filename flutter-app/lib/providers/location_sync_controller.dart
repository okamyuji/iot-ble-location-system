import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_data.dart';
import '../services/ble/ble_services.dart';
import '../services/location_api_service.dart';

/// サーバー送信結果を履歴として保持するための構造体
class SendHistoryEntry {
  SendHistoryEntry({
    required this.location,
    required this.sentAt,
    required this.success,
    this.errorMessage,
  });

  final LocationData location;
  final DateTime sentAt;
  final bool success;
  final String? errorMessage;
}

/// BLE受信データとサーバー連携を統括するプロバイダ
class LocationSyncController extends ChangeNotifier {
  LocationSyncController({
    LocationApiService? apiService,
    BleLocationService? bleService,
    BlePeripheralService? peripheralService,
  })  : _apiService = apiService ?? LocationApiService(),
        _bleService = bleService ?? BleLocationService(),
        _peripheralService = peripheralService ?? BlePeripheralService() {
    _scanSubscription = _bleService.scanResults.listen((devices) {
      _devices = devices;
      if (devices.isEmpty) {
        _latestRssiCache.clear();
      } else {
        for (final device in devices) {
          _latestRssiCache[device.deviceId] = device.rssi;

          // IoT-BLEデバイスを検出したら自動的にモック位置情報を生成してサーバーに送信
          if (device.name.startsWith('IoT-BLE-')) {
            _autoSendLocationForDevice(device);
          }
        }
      }
      notifyListeners();
    });
  }

  final LocationApiService _apiService;
  final BleLocationService _bleService;
  final BlePeripheralService _peripheralService;

  StreamSubscription<List<BleDeviceSummary>>? _scanSubscription;
  StreamSubscription<LocationData>? _locationSubscription;

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isSending = false;
  String? _lastError;
  String? _connectedDeviceId;
  LocationData? _latestBleLocation;
  LocationData? _lastSentLocation;
  Map<String, dynamic>? _latestStats;
  List<LocationData> _recentServerLocations = const [];
  List<BleDeviceSummary> _devices = const [];
  final List<SendHistoryEntry> _history = [];
  final Map<String, int?> _latestRssiCache = {};

  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  bool get isSending => _isSending;
  String? get lastError => _lastError;
  String? get connectedDeviceId => _connectedDeviceId;
  LocationData? get latestBleLocation => _latestBleLocation;
  LocationData? get lastSentLocation => _lastSentLocation;
  Map<String, dynamic>? get latestStats => _latestStats;
  List<LocationData> get recentServerLocations => _recentServerLocations;
  List<BleDeviceSummary> get devices => _devices;
  List<SendHistoryEntry> get history => List.unmodifiable(_history);

  /// スキャン開始
  Future<void> startScan() async {
    if (_isScanning) {
      return;
    }
    _isScanning = true;
    _lastError = null;
    notifyListeners();

    try {
      await _bleService.startScan();
    } catch (e) {
      _lastError = 'スキャン開始に失敗しました: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// スキャン停止
  Future<void> stopScan() async {
    if (!_isScanning) {
      return;
    }
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  /// BLE送信開始
  Future<void> startAdvertising() async {
    debugPrint('[Controller] BLE送信開始要求');
    if (_isAdvertising) {
      debugPrint('[Controller] 既に送信中');
      return;
    }
    _lastError = null;
    notifyListeners();

    try {
      await _peripheralService.startAdvertising();
      _isAdvertising = true;
      debugPrint('[Controller] BLE送信開始成功');
      notifyListeners();
    } catch (e) {
      debugPrint('[Controller] BLE送信開始エラー: $e');
      _lastError = 'BLE送信開始に失敗しました: $e';
      _isAdvertising = false;
      notifyListeners();
    }
  }

  /// BLE送信停止
  Future<void> stopAdvertising() async {
    debugPrint('[Controller] BLE送信停止要求');
    if (!_isAdvertising) {
      debugPrint('[Controller] 送信していません');
      return;
    }
    try {
      await _peripheralService.stopAdvertising();
      _isAdvertising = false;
      debugPrint('[Controller] BLE送信停止成功');
      notifyListeners();
    } catch (e) {
      debugPrint('[Controller] BLE送信停止エラー: $e');
      _lastError = 'BLE送信停止に失敗しました: $e';
      notifyListeners();
    }
  }

  /// デバイスへ接続し、通知データを購読
  Future<void> connectToDevice(String deviceId) async {
    if (_connectedDeviceId == deviceId) {
      return;
    }
    await _locationSubscription?.cancel();
    _connectedDeviceId = null;
    _latestBleLocation = null;
    notifyListeners();

    try {
      await _bleService.connect(deviceId);
      _connectedDeviceId = deviceId;
      _locationSubscription =
          _bleService.listenLocationUpdates(deviceId).listen((location) {
        _latestBleLocation = location;
        _latestRssiCache[deviceId] = location.rssi;
        notifyListeners();
        _autoSend(location);
      }, onError: (Object error) {
        _lastError = 'BLE通知の受信に失敗しました: $error';
        notifyListeners();
      });
      notifyListeners();
    } catch (e) {
      _lastError = 'デバイス接続に失敗しました: $e';
      _connectedDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _locationSubscription?.cancel();
    if (_connectedDeviceId != null) {
      await _bleService.disconnect(_connectedDeviceId!);
    }
    _connectedDeviceId = null;
    notifyListeners();
  }

  /// 受信データを即時送信するための内部ロジック
  Future<void> _autoSend(LocationData location) async {
    if (_isSending) {
      return;
    }
    await sendLocation(location);
  }

  /// 任意の位置情報をREST APIへ送信
  Future<void> sendLocation(LocationData location) async {
    final errors = location.validate();
    if (errors.isNotEmpty) {
      _lastError = '送信前検証エラー: ${errors.join(', ')}';
      _history.add(SendHistoryEntry(
        location: location,
        sentAt: DateTime.now(),
        success: false,
        errorMessage: _lastError,
      ));
      notifyListeners();
      return;
    }

    _isSending = true;
    _lastError = null;
    notifyListeners();
    try {
      final saved = await _apiService.postLocation(location);
      _lastSentLocation = saved;
      _history.add(SendHistoryEntry(
        location: saved,
        sentAt: DateTime.now(),
        success: true,
      ));
      await refreshServerData();
    } catch (e) {
      final message = '位置情報の送信に失敗しました: $e';
      _lastError = message;
      _history.add(SendHistoryEntry(
        location: location,
        sentAt: DateTime.now(),
        success: false,
        errorMessage: message,
      ));
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// サーバー側の統計と最新データを取得
  Future<void> refreshServerData() async {
    try {
      final stats = await _apiService.fetchStats();
      final recent = await _apiService.fetchRecentLocations();
      _latestStats = stats;
      _recentServerLocations = recent;
      notifyListeners();
    } catch (e) {
      _lastError ??= 'サーバーデータ取得に失敗しました: $e';
      notifyListeners();
    }
  }

  /// ステータスと履歴をクリアする
  void clearLogs() {
    _history.clear();
    _lastError = null;
    notifyListeners();
  }

  /// IoT-BLEデバイスを検出したら自動的に実際のGPS位置情報を取得してサーバーに送信
  ///
  /// 注意: iOSの制限によりManufacturer Dataが受信できないため、
  /// デバイス検出をトリガーとして実際のGPS位置情報を送信します。
  final Set<String> _sentDeviceIds = {};

  Future<void> _autoSendLocationForDevice(BleDeviceSummary device) async {
    // 既に送信済みのデバイスはスキップ（重複送信を防ぐ）
    if (_sentDeviceIds.contains(device.deviceId)) {
      return;
    }

    // GPS取得前にデバイスIDを登録（重複リクエストを防ぐ）
    _sentDeviceIds.add(device.deviceId);

    debugPrint('[Controller] IoT-BLEデバイス検出: ${device.name} - GPS位置情報を取得して送信');

    try {
      // GPS位置情報を取得
      final position = await _getCurrentPosition();

      if (position == null) {
        debugPrint('[Controller] GPS位置情報の取得に失敗しました');
        // 失敗した場合は再試行できるようにIDを削除
        _sentDeviceIds.remove(device.deviceId);
        return;
      }

      debugPrint(
          '[Controller] GPS位置情報取得成功: lat=${position.latitude}, lon=${position.longitude}, accuracy=${position.accuracy}');

      // 実際のGPS位置情報を使用
      final location = LocationData(
        deviceId: device.name,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        rssi: device.rssi,
        timestamp: DateTime.now(),
      );

      // サーバーに送信
      await sendLocation(location);
    } catch (e, stackTrace) {
      debugPrint('[Controller] GPS位置情報取得エラー: $e');
      debugPrint('[Controller] スタックトレース: $stackTrace');
      // エラーの場合も再試行できるようにIDを削除
      _sentDeviceIds.remove(device.deviceId);
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

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _scanSubscription?.cancel();
    unawaited(_bleService.dispose());
    unawaited(_peripheralService.dispose());
    _apiService.dispose();
    super.dispose();
  }
}
