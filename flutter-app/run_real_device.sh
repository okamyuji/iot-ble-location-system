#!/bin/bash

# 実機向けの実行スクリプト
# 実機から開発マシンにアクセスするため、開発マシンのIPアドレスを指定

# デフォルトのIPアドレス（環境に合わせて変更してください）
DEFAULT_IP="192.168.0.15"

# コマンドライン引数からIPアドレスを取得（指定されていればそれを使用）
API_IP=${1:-$DEFAULT_IP}

echo "🚀 実機向けにアプリを起動します..."
echo "📡 API Base URL: http://${API_IP}:8080"
echo ""
echo "💡 IPアドレスを変更する場合："
echo "   ./run_real_device.sh 192.168.1.XXX"
echo ""

flutter run \
  --dart-define=API_BASE_URL=http://${API_IP}:8080 \
  --dart-define=HTTP_TIMEOUT=30 \
  --dart-define=DEBUG_MODE=true

