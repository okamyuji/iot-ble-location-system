import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/location_sync_controller.dart';

/// 設定・デバッグ情報を表示する画面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定・デバッグ情報'),
      ),
      body: Consumer<LocationSyncController>(
        builder: (context, controller, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: 'サーバー設定',
                children: [
                  _buildInfoTile(
                    'API Base URL',
                    AppConfig.apiBaseUrl,
                    icon: Icons.cloud,
                    onTap: () => _copyToClipboard(
                      context,
                      AppConfig.apiBaseUrl,
                    ),
                  ),
                  _buildInfoTile(
                    'タイムアウト',
                    '${AppConfig.httpTimeoutSeconds}秒',
                    icon: Icons.timer,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'BLE設定',
                children: [
                  _buildInfoTile(
                    'Service UUID',
                    AppConfig.locationServiceUuid,
                    icon: Icons.bluetooth,
                    onTap: () => _copyToClipboard(
                      context,
                      AppConfig.locationServiceUuid,
                    ),
                  ),
                  _buildInfoTile(
                    'Characteristic UUID',
                    AppConfig.locationCharacteristicUuid,
                    icon: Icons.bluetooth_connected,
                    onTap: () => _copyToClipboard(
                      context,
                      AppConfig.locationCharacteristicUuid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'アプリ情報',
                children: [
                  _buildInfoTile(
                    'デバッグモード',
                    AppConfig.isDebugMode ? '有効' : '無効',
                    icon: Icons.bug_report,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: '接続テスト',
                children: [
                  ListTile(
                    leading: const Icon(Icons.network_check),
                    title: const Text('サーバー接続テスト'),
                    subtitle: const Text('統計情報を取得して接続を確認'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _testConnection(context, controller),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'ログ',
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('ログをクリア'),
                    subtitle: const Text('送信履歴とエラーログを削除'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      controller.clearLogs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ログをクリアしました')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '設定変更方法',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'サーバーURLを変更するには、ビルド時に --dart-define を使用してください：',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _buildCodeBlock(
                        '# Androidエミュレータ\n'
                        'flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080\n\n'
                        '# iOSシミュレータ\n'
                        'flutter run --dart-define=API_BASE_URL=http://localhost:8080\n\n'
                        '# 実機（開発マシンのIPアドレス）\n'
                        'flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    String label,
    String value, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(label),
      subtitle: Text(
        value,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      trailing: onTap != null ? const Icon(Icons.copy, size: 16) : null,
      onTap: onTap,
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('クリップボードにコピーしました: $text')),
    );
  }

  Future<void> _testConnection(
    BuildContext context,
    LocationSyncController controller,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('接続テスト中...')),
    );

    try {
      await controller.refreshServerData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ サーバーへの接続に成功しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ 接続に失敗しました: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
