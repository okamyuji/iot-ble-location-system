#!/bin/bash

# Androidエミュレータ向けの実行スクリプト
# エミュレータからホストマシンのlocalhostにアクセスするため、10.0.2.2を使用

echo "🚀 Androidエミュレータ向けにアプリを起動します..."
echo "📡 API Base URL: http://10.0.2.2:8080"
echo ""

flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=HTTP_TIMEOUT=30 \
  --dart-define=DEBUG_MODE=true

