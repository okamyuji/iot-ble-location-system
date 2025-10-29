#!/bin/bash

# iOS完全クリーンビルドスクリプト
# 権限問題やビルド問題が発生した場合に実行

echo "🧹 iOS完全クリーンビルドを開始します..."
echo ""

# 1. Flutterのクリーン
echo "📦 Flutterクリーン中..."
flutter clean

# 2. Podの完全削除
echo "🗑️  Pods削除中..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec

# 3. DerivedDataの削除
echo "🗑️  DerivedData削除中..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# 4. Flutter pub get
echo "📦 依存関係取得中..."
cd ..
flutter pub get

# 5. Pod install
echo "📦 Pod install中..."
cd ios
pod install
cd ..

echo ""
echo "✅ クリーンビルド完了！"
echo ""
echo "次のステップ:"
echo "1. デバイスからアプリを完全に削除してください"
echo "2. デバイスを再起動してください（推奨）"
echo "3. 以下のコマンドでアプリをインストール:"
echo ""
echo "   flutter run --dart-define=API_BASE_URL=http://192.168.0.15:8080"
echo ""

