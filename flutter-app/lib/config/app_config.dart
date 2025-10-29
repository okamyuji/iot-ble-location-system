/// アプリ全体で共有する定数や設定値をまとめたクラス
///
/// サーバーURLは以下の優先順位で決定されます：
/// 1. --dart-define で指定された API_BASE_URL
/// 2. 環境変数 API_BASE_URL
/// 3. デフォルト値（プラットフォーム別）
class AppConfig {
  AppConfig._();

  /// ビルド時に --dart-define で指定されたAPI Base URL
  ///
  /// 使用例:
  /// ```bash
  /// # Androidエミュレータ向け（ホストマシンのlocalhost）
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  ///
  /// # iOSシミュレータ向け（ホストマシンのlocalhost）
  /// flutter run --dart-define=API_BASE_URL=http://localhost:8080
  ///
  /// # 実機向け（開発マシンのIPアドレス）
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080
  ///
  /// # 本番環境
  /// flutter build apk --dart-define=API_BASE_URL=https://api.example.com
  /// ```
  static const _dartDefineApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// プラットフォーム別のデフォルトURL
  /// - Android: 10.0.2.2 (エミュレータからホストマシンへのアクセス)
  /// - iOS: localhost (シミュレータからホストマシンへのアクセス)
  /// - その他: localhost
  static String get _defaultApiBaseUrl {
    // プラットフォーム判定はビルド時に行われるため、
    // ここではAndroidエミュレータ用をデフォルトとする
    // 実機では必ず --dart-define で指定することを推奨
    return 'http://10.0.2.2:8080';
  }

  /// 実際に使用されるAPI Base URL
  ///
  /// dart-defineで指定されていればそれを使用、
  /// なければデフォルト値を使用
  static String get apiBaseUrl => _dartDefineApiBaseUrl.isNotEmpty
      ? _dartDefineApiBaseUrl
      : _defaultApiBaseUrl;

  /// BLEサービスUUID（ESP32ファームウェアと合わせる）
  static const String locationServiceUuid =
      '12345678-1234-5678-1234-56789abcdef0';

  /// 位置情報を通知する特性UUID
  static const String locationCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef1';

  /// HTTPタイムアウト設定（秒）
  static const int httpTimeoutSeconds =
      int.fromEnvironment('HTTP_TIMEOUT', defaultValue: 30);

  /// デバッグモード
  static const bool isDebugMode =
      bool.fromEnvironment('DEBUG_MODE', defaultValue: false);

  /// 設定情報を文字列で返す（デバッグ用）
  static String get configInfo => '''
API Base URL: $apiBaseUrl
HTTP Timeout: ${httpTimeoutSeconds}s
Debug Mode: $isDebugMode
BLE Service UUID: $locationServiceUuid
BLE Characteristic UUID: $locationCharacteristicUuid
''';
}
