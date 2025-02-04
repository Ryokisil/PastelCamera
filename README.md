## 実行環境
- macOS Sequoia 15.2

- iPhone16 iOS18.1.1

## 開発ツール
- Swift 6.0
- Xcode 16.0
- TOCropViewController

## アプリケーションの仕様
PastelCamera は、以下の機能を備えたカメラアプリです。
- リアルタイムフィルター適用（パステルカラー）
- カメラロール保存
- スワイプでフィルターを変更
- AVFoundation を利用したカメラ制御(広角＆超広角＆インカメとバック)
- フラッシュ機能
- ズーム機能
- トリミング機能

## 要件
- iOS 16.0以降
- カメラへのアクセス許可が必要
- フォトライブラリへのアクセス許可が必要

## 実行手順
1. リポジトリをクローン
　　　git clone https://github.com/Ryokisil/PastelCamera.git
2. Xcodeでプロジェクトを開き、ターゲットを選択してビルド
3. Swift Package Manager (SPM)をインストール
