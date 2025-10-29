import 'dart:convert';

/// 位置情報データモデル
///
/// BLE通知とREST APIの両方で共通利用するデータ構造を提供する
class LocationData {
  /// サーバーが採番した一意識別子
  final int? id;

  /// BLEデバイスに割り当てられた一意識別子
  final String deviceId;

  /// 緯度（-90.0 ~ 90.0）
  final double latitude;

  /// 経度（-180.0 ~ 180.0）
  final double longitude;

  /// 高度（メートル、省略可）
  final double? altitude;

  /// 位置精度（メートル、省略可）
  final double? accuracy;

  /// BLE信号強度（dBm、省略可）
  final int? rssi;

  /// 位置情報の発生時刻（UTC推奨）
  final DateTime timestamp;

  /// サーバーが付与する作成日時
  final DateTime? createdAt;

  const LocationData({
    this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.rssi,
    required this.timestamp,
    this.createdAt,
  });

  /// BLEから取得したJSON文字列を解析してLocationDataを生成する
  factory LocationData.fromBleJson(
    Map<String, dynamic> json, {
    int? fallbackRssi,
  }) {
    return LocationData(
      id: _readInt(json['id']),
      deviceId: (json['deviceId'] ?? '').toString(),
      latitude: _readDouble(json['lat']) ?? _readDouble(json['latitude']) ?? 0.0,
      longitude:
          _readDouble(json['lon']) ?? _readDouble(json['longitude']) ?? 0.0,
      altitude: _readDouble(json['alt']) ?? _readDouble(json['altitude']),
      accuracy:
          _readDouble(json['accuracy']) ?? _readDouble(json['horizontalAcc']),
      rssi: _readInt(json['rssi']) ?? fallbackRssi,
      timestamp: _readDate(json['timestamp']) ??
          _readDate(json['time']) ??
          DateTime.now().toUtc(),
      createdAt: _readDate(json['createdAt']),
    );
  }

  /// REST APIから取得したJSONを解析してLocationDataを生成する
  factory LocationData.fromApiJson(Map<String, dynamic> json) {
    return LocationData(
      id: _readInt(json['id']),
      deviceId: (json['deviceId'] ?? '').toString(),
      latitude: _readDouble(json['latitude']) ?? 0.0,
      longitude: _readDouble(json['longitude']) ?? 0.0,
      altitude: _readDouble(json['altitude']),
      accuracy: _readDouble(json['accuracy']),
      rssi: _readInt(json['rssi']),
      timestamp: _readDate(json['timestamp']) ?? DateTime.now().toUtc(),
      createdAt: _readDate(json['createdAt']),
    );
  }

  /// BLE通知の生文字列を安全に解析し、失敗時はnullを返す
  static LocationData? tryParseBlePayload(
    String payload, {
    int? fallbackRssi,
  }) {
    try {
      final Map<String, dynamic> jsonMap =
          jsonDecode(payload) as Map<String, dynamic>;
      return LocationData.fromBleJson(jsonMap, fallbackRssi: fallbackRssi);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// サーバーへPOSTするためのJSONマップへ変換する
  Map<String, dynamic> toApiJson() {
    return <String, dynamic>{
      'id': id,
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (rssi != null) 'rssi': rssi,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  /// 値の妥当性をチェックし、エラーがあればメッセージを返す
  List<String> validate() {
    final errors = <String>[];

    if (deviceId.trim().isEmpty) {
      errors.add('デバイスIDが空です');
    }
    if (latitude < -90.0 || latitude > 90.0) {
      errors.add('緯度が範囲外です (-90 ~ 90)');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      errors.add('経度が範囲外です (-180 ~ 180)');
    }
    if (timestamp.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) {
      errors.add('タイムスタンプが未来を指しています');
    }
    return errors;
  }

  /// バリデーションが通ればtrueを返す
  bool get isValid => validate().isEmpty;

  LocationData copyWith({
    int? id,
    String? deviceId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    int? rssi,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return LocationData(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      rssi: rssi ?? this.rssi,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

double? _readDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _readInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _readDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value.toString())?.toUtc();
}
