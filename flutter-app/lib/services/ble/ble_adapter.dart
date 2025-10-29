import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../config/app_config.dart';

/// スキャンで見つけたデバイスのサマリー情報
class BleDeviceSummary {
  const BleDeviceSummary({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });

  final String deviceId;
  final String name;
  final int? rssi;
}

/// BLE操作を抽象化するインターフェース
abstract class BleAdapter {
  Stream<List<BleDeviceSummary>> get scanResults;

  Future<void> startScan();

  Future<void> stopScan();

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  Stream<List<int>> onValueChanged(String deviceId);

  Future<void> enableNotification(String deviceId);

  Future<int?> readRssi(String deviceId);

  Future<void> dispose();
}

/// 実機でFlutterBluePlusを利用する実装
class FlutterBleAdapter implements BleAdapter {
  FlutterBleAdapter({
    this.serviceUuid = AppConfig.locationServiceUuid,
    this.characteristicUuid = AppConfig.locationCharacteristicUuid,
  });

  final String serviceUuid;
  final String characteristicUuid;

  final StreamController<List<BleDeviceSummary>> _scanController =
      StreamController<List<BleDeviceSummary>>.broadcast();

  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, BluetoothCharacteristic> _notifyCharacteristics = {};
  final Map<String, BleDeviceSummary> _latestScanSummary = {};

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  Stream<List<BleDeviceSummary>> get scanResults => _scanController.stream;

  @override
  Future<void> startScan() async {
    debugPrint('[BLE] スキャン開始要求');

    // Bluetooth状態をチェック（最大3秒待機）
    debugPrint('[BLE] Bluetooth状態を確認中...');
    BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;

    for (int i = 0; i < 6; i++) {
      adapterState = await FlutterBluePlus.adapterState.first;
      debugPrint('[BLE] Bluetoothアダプター状態 (試行${i + 1}/6): $adapterState');

      if (adapterState == BluetoothAdapterState.on) {
        break;
      }

      if (adapterState == BluetoothAdapterState.unknown && i < 5) {
        debugPrint('[BLE] 状態が不明です。500ms待機してリトライします...');
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      if (adapterState != BluetoothAdapterState.on) {
        break;
      }
    }

    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('[BLE] エラー: Bluetoothがオフまたは利用不可です (状態: $adapterState)');
      throw Exception('Bluetoothが利用できません (状態: $adapterState)。\n'
          'デバイスの設定でBluetoothをオンにしてください。');
    }

    debugPrint('[BLE] Bluetooth状態確認完了: ON');

    // 既存のスキャンをキャンセル
    await _scanSubscription?.cancel();

    debugPrint('[BLE] スキャン結果のリスニング開始');
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // IoT-BLEデバイスのみをフィルタリング
      final filtered = results.where((result) {
        final advName = result.advertisementData.advName;
        final platformName = result.device.platformName;
        return advName.startsWith('IoT-BLE-') ||
            platformName.startsWith('IoT-BLE-');
      }).toList();

      if (filtered.isNotEmpty) {
        debugPrint(
            '[BLE] スキャン結果: ${results.length}件中 IoT-BLEデバイス: ${filtered.length}件');
      }

      final mapped = filtered.map((result) {
        final deviceId = result.device.remoteId.str;
        final advName = result.advertisementData.advName;

        // Manufacturer Dataをログ出力
        if (result.advertisementData.manufacturerData.isNotEmpty) {
          debugPrint(
              '[BLE] Manufacturer Data: ${result.advertisementData.manufacturerData}');
        }

        final summary = BleDeviceSummary(
          deviceId: deviceId,
          name: advName.isNotEmpty
              ? advName
              : (result.device.platformName.isNotEmpty
                  ? result.device.platformName
                  : deviceId),
          rssi: result.rssi,
        );
        _latestScanSummary[deviceId] = summary;
        debugPrint(
            '[BLE] デバイス検出: ${summary.name} ($deviceId) RSSI: ${summary.rssi}');
        return summary;
      }).toList();

      _scanController.add(mapped);
    });

    debugPrint('[BLE] FlutterBluePlus.startScan() 呼び出し');
    debugPrint('[BLE] サービスUUID: $serviceUuid (フィルタなしでスキャン)');

    try {
      // iOSのPeripheralモードではサービスUUIDが正しく送信されないため、
      // フィルタなしでスキャンし、デバイス名でフィルタリングする
      await FlutterBluePlus.startScan(
        // withServices: [Guid(serviceUuid)], // コメントアウト
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[BLE] スキャン開始成功');
    } catch (e, stackTrace) {
      debugPrint('[BLE] スキャン開始エラー: $e');
      debugPrint('[BLE] スタックトレース: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  Future<void> connect(String deviceId) async {
    debugPrint('[BLE] 接続開始: $deviceId');

    final device = await _resolveDevice(deviceId);
    if (device == null) {
      debugPrint('[BLE] エラー: デバイスが見つかりません');
      throw StateError('デバイスが見つかりません: $deviceId');
    }

    if (device.isConnected) {
      debugPrint('[BLE] 既に接続済み');
      _connectedDevices[deviceId] = device;
      return;
    }

    debugPrint('[BLE] デバイスに接続中...');
    try {
      await device.connect(
          autoConnect: false, timeout: const Duration(seconds: 10));
      _connectedDevices[deviceId] = device;
      debugPrint('[BLE] 接続成功');
    } catch (e, stackTrace) {
      debugPrint('[BLE] 接続エラー: $e');
      debugPrint('[BLE] スタックトレース: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = _connectedDevices.remove(deviceId);
    if (device != null) {
      await device.disconnect();
    }
    _notifyCharacteristics.remove(deviceId);
  }

  @override
  Stream<List<int>> onValueChanged(String deviceId) async* {
    final characteristic = await _ensureCharacteristic(deviceId);
    yield* characteristic.onValueReceived;
  }

  @override
  Future<void> enableNotification(String deviceId) async {
    final characteristic = await _ensureCharacteristic(deviceId);
    if (characteristic.isNotifying) {
      return;
    }
    await characteristic.setNotifyValue(true);
  }

  @override
  Future<int?> readRssi(String deviceId) async {
    final device = await _resolveDevice(deviceId);
    if (device == null) {
      return null;
    }
    try {
      return await device.readRssi();
    } on Exception {
      return null;
    }
  }

  Future<BluetoothDevice?> _resolveDevice(String deviceId) async {
    if (_connectedDevices.containsKey(deviceId)) {
      return _connectedDevices[deviceId];
    }
    if (_latestScanSummary.containsKey(deviceId)) {
      return BluetoothDevice.fromId(deviceId);
    }

    final devices = FlutterBluePlus.connectedDevices
        .where((device) => device.remoteId.str == deviceId)
        .toList();
    if (devices.isNotEmpty) {
      return devices.first;
    }

    return BluetoothDevice.fromId(deviceId);
  }

  Future<BluetoothCharacteristic> _ensureCharacteristic(String deviceId) async {
    if (_notifyCharacteristics.containsKey(deviceId)) {
      return _notifyCharacteristics[deviceId]!;
    }

    final device = await _resolveDevice(deviceId);
    if (device == null) {
      throw StateError('Characteristic取得に失敗しました（デバイス未接続）');
    }
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == Guid(serviceUuid)) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == Guid(characteristicUuid)) {
            _notifyCharacteristics[deviceId] = characteristic;
            return characteristic;
          }
        }
      }
    }
    throw StateError('位置情報用Characteristicが見つかりませんでした');
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    for (final device in _connectedDevices.values) {
      await device.disconnect();
    }
    _connectedDevices.clear();
    await _scanController.close();
  }
}
