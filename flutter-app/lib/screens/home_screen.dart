import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location_data.dart';
import '../providers/location_sync_controller.dart';
import '../services/ble/ble_adapter.dart';
import 'settings_screen.dart';

/// アプリのメイン画面。BLE操作とサーバーの状態をタブで表示する
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IoT BLE ロケーション'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              tooltip: '設定・デバッグ情報',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bluetooth), text: 'デバイス'),
              Tab(icon: Icon(Icons.my_location), text: '受信/送信'),
              Tab(icon: Icon(Icons.bar_chart), text: 'サーバー'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BleDevicesTab(),
            _LiveDataTab(),
            _ServerStatusTab(),
          ],
        ),
      ),
    );
  }
}

class _BleDevicesTab extends StatelessWidget {
  const _BleDevicesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationSyncController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildScanControls(controller),
              const SizedBox(height: 16),
              Expanded(
                child: controller.devices.isEmpty
                    ? const _EmptyMessage(
                        message: '周囲のBLEデバイスを検出していません。\nスキャンを開始してください。',
                      )
                    : ListView.separated(
                        itemCount: controller.devices.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final device = controller.devices[index];
                          final isConnected =
                              controller.connectedDeviceId == device.deviceId;
                          return _DeviceTile(
                            device: device,
                            isConnected: isConnected,
                            onConnect: () =>
                                controller.connectToDevice(device.deviceId),
                            onDisconnect: controller.disconnect,
                          );
                        },
                      ),
              ),
              if (controller.lastError != null)
                Text(
                  controller.lastError!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanControls(LocationSyncController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BLE受信（スキャン）
        Row(
          children: [
            ElevatedButton.icon(
              icon: Icon(controller.isScanning ? Icons.stop : Icons.search),
              label: Text(controller.isScanning ? 'スキャン停止' : 'スキャン開始'),
              onPressed: controller.isScanning
                  ? controller.stopScan
                  : controller.startScan,
            ),
            const SizedBox(width: 12),
            if (controller.isScanning) const CircularProgressIndicator(),
          ],
        ),
        const SizedBox(height: 12),
        // BLE送信（アドバタイジング）
        Row(
          children: [
            ElevatedButton.icon(
              icon: Icon(controller.isAdvertising
                  ? Icons.stop
                  : Icons.broadcast_on_personal),
              label: Text(controller.isAdvertising ? 'BLE送信停止' : 'BLE送信開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    controller.isAdvertising ? Colors.orange : Colors.green,
              ),
              onPressed: controller.isAdvertising
                  ? controller.stopAdvertising
                  : controller.startAdvertising,
            ),
            const SizedBox(width: 12),
            if (controller.isAdvertising)
              const Row(
                children: [
                  Icon(Icons.broadcast_on_personal, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('送信中', style: TextStyle(color: Colors.orange)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '💡 2台のデバイスで動作テスト:\n'
          '  1台目: BLE送信開始\n'
          '  2台目: スキャン開始\n'
          '  → デバイス検出時に自動的にGPS位置情報を取得してサーバーに送信',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _LiveDataTab extends StatelessWidget {
  const _LiveDataTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationSyncController>(
      builder: (context, controller, _) {
        final latest = controller.latestBleLocation;
        final lastSent = controller.lastSentLocation;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LocationCard(
                title: '最新のBLE受信データ',
                location: latest,
                emptyMessage: 'まだBLEデータを受信していません',
              ),
              const SizedBox(height: 12),
              _LocationCard(
                title: '最後に送信したデータ',
                location: lastSent,
                emptyMessage: '送信履歴がありません',
              ),
              const SizedBox(height: 12),
              if (controller.isSending) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              _HistorySection(history: controller.history),
            ],
          ),
        );
      },
    );
  }
}

class _ServerStatusTab extends StatelessWidget {
  const _ServerStatusTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationSyncController>(
      builder: (context, controller, _) {
        final stats = controller.latestStats;
        return RefreshIndicator(
          onRefresh: controller.refreshServerData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('サーバー統計', style: TextStyle(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshServerData,
                  ),
                ],
              ),
              if (stats == null)
                const _EmptyMessage(
                  message: '統計情報がまだ取得されていません。\n更新ボタンを押してください。',
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('記録件数: ${stats['totalLocations']}'),
                        const SizedBox(height: 8),
                        Text('デバイス数: ${stats['deviceCount']}'),
                        const SizedBox(height: 8),
                        Text('タイムスタンプ: ${stats['timestamp']}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('最新の記録 (上位50件)', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              if (controller.recentServerLocations.isEmpty)
                const _EmptyMessage(message: 'サーバーから取得した位置情報がありません。')
              else
                ...controller.recentServerLocations.map(
                  (location) => _ServerLocationTile(location: location),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerLocationTile extends StatelessWidget {
  const _ServerLocationTile({required this.location});

  final LocationData location;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
            '${location.deviceId} (${location.latitude}, ${location.longitude})'),
        subtitle: Text(
          '時刻: ${location.timestamp.toLocal()}\nRSSI: ${location.rssi ?? '-'}',
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.history});

  final List<SendHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const _EmptyMessage(message: '送信履歴がありません。');
    }
    return Expanded(
      child: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          return Card(
            child: ListTile(
              leading: Icon(
                entry.success ? Icons.check_circle : Icons.error,
                color: entry.success ? Colors.green : Colors.red,
              ),
              title: Text(
                '${entry.location.deviceId} (${entry.location.latitude.toStringAsFixed(5)}, '
                '${entry.location.longitude.toStringAsFixed(5)})',
              ),
              subtitle: Text(
                '送信時刻: ${entry.sentAt.toLocal()}\n結果: '
                '${entry.success ? '成功' : entry.errorMessage ?? '失敗'}',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.location,
    required this.emptyMessage,
  });

  final String title;
  final LocationData? location;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            if (location == null)
              Text(emptyMessage)
            else
              Text(
                'デバイスID: ${location!.deviceId}\n'
                '緯度/経度: ${location!.latitude}, ${location!.longitude}\n'
                '高度: ${location!.altitude ?? '-'}\n'
                '精度: ${location!.accuracy ?? '-'}\n'
                'RSSI: ${location!.rssi ?? '-'}\n'
                '時刻: ${location!.timestamp.toLocal()}',
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final BleDeviceSummary device;
  final bool isConnected;
  final VoidCallback onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(device.name),
        subtitle: Text('ID: ${device.deviceId}\nRSSI: ${device.rssi ?? '-'}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text(
                '検出済み',
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
