// 設定画面のモデル達　設定画面が不要ってなったら消すかも

import Foundation

// トグルのオンオフ状態を管理するViewModel
class SettingsViewModel: ObservableObject {
    // UserDefaultsのキー
    private let gridFeatureKey = "gridFeatureEnabled"

    // @Publishedを使いトグル状態をSwiftUI側と連携
    @Published var isGridFeatureEnabled: Bool {
        didSet {
            // トグルの状態が変更されたらUserDefaultsに保存
            UserDefaults.standard.set(isGridFeatureEnabled, forKey: gridFeatureKey)
            // トグルが変更された際に通知を送信
            NotificationCenter.default.post(name: .gridFeatureDidChange, object: isGridFeatureEnabled)
        }
    }

    // 初期化時にUserDefaultsから状態を読み込む
    init() {
            let savedState = UserDefaults.standard.bool(forKey: gridFeatureKey)
            self.isGridFeatureEnabled = savedState
    }
}

// Notification.Nameを拡張して通知名を定義
extension Notification.Name {
    static let gridFeatureDidChange = Notification.Name("gridFeatureDidChange")
}
