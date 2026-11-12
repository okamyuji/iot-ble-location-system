import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'providers/location_sync_controller.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IotBleApp());
}

/// アプリのルートウィジェット
class IotBleApp extends StatelessWidget {
  const IotBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocationSyncController(),
        ),
      ],
      child: MaterialApp(
        title: 'IoT BLE Location',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const PermissionGate(
          child: HomeScreen(),
        ),
      ),
    );
  }
}

/// 必要な権限が揃うまでは説明画面を表示する
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;
  bool _granted = false;
  String? _error;
  bool _needsOpenSettings = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    debugPrint('[権限] 権限リクエスト開始');

    setState(() {
      _checking = true;
      _error = null;
      _needsOpenSettings = false;
    });

    // プラットフォーム別の権限リクエスト
    final permissions = <Permission>[];

    // iOS: Bluetooth権限
    // Android 12+: bluetoothScan, bluetoothConnect
    // Android 11以下: bluetooth, location
    if (Platform.isIOS) {
      debugPrint('[権限] iOS: Bluetooth + 位置情報をリクエスト');
      permissions.addAll([
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ]);
    } else {
      debugPrint('[権限] Android: BluetoothScan + BluetoothConnect + 位置情報をリクエスト');
      // Android
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ]);
    }

    debugPrint('[権限] リクエスト実行中...');
    final statuses = await permissions.request();

    debugPrint('[権限] リクエスト結果:');
    for (final entry in statuses.entries) {
      debugPrint('[権限]   ${entry.key}: ${entry.value}');
    }

    if (!mounted) {
      return;
    }

    final hasPermanentDenial = statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );
    final hasDenied = statuses.values.any((status) => status.isDenied);
    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    debugPrint('[権限] 恒久的拒否: $hasPermanentDenial');
    debugPrint('[権限] 拒否: $hasDenied');
    debugPrint('[権限] すべて許可: $allGranted');

    setState(() {
      _checking = false;
      _granted = allGranted;
      _needsOpenSettings = hasPermanentDenial && !allGranted;
      if (_needsOpenSettings) {
        _error = '権限が恒久的に拒否されています。設定アプリでBluetoothと位置情報を許可してください。';
        debugPrint('[権限] エラー: 恒久的拒否');
      } else if (hasDenied) {
        _error = 'Bluetoothおよび位置情報の権限が必要です。';
        debugPrint('[権限] エラー: 拒否');
      } else {
        _error = null;
        debugPrint('[権限] 成功: すべての権限が許可されました');
      }
    });
  }

  Future<void> _openSettings() async {
    final opened = await openAppSettings();
    if (!mounted) {
      return;
    }
    if (!opened) {
      setState(() {
        _error = '設定アプリを開けませんでした。手動で権限を付与してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_granted) {
      return widget.child;
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? '必要な権限が許可されていません。\nアプリの利用にはBluetoothと位置情報の権限が必要です。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_needsOpenSettings) ...[
                ElevatedButton(
                  onPressed: _openSettings,
                  child: const Text('設定を開く'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _requestPermissions,
                  child: const Text('権限を再確認'),
                ),
              ] else
                ElevatedButton(
                  onPressed: _requestPermissions,
                  child: const Text('権限を再確認'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
