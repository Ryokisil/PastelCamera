// 設定画面　このファイルの必要性は不明

import UIKit
import SwiftUI
import WebKit

struct SettingsViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SettingsViewController {
        return SettingsViewController()
    }
    
    func updateUIViewController(_ uiViewController: SettingsViewController, context: Context) {
        // 特に更新処理はここでは必要ないので空のまま
    }
}

protocol SettingsDelegate: AnyObject {
    func updateSaveLocation(to location: CameraViewModel.SaveLocation)
    func updateGridEnabled(isEnabled: Bool)
}

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
   
   var isGridEnabled: Bool = false                  // グリッド表示の初期状態を設定
   var cameraViewController: CameraViewController?  // CameraViewControllerへの参照。設定画面からカメラ画面にアクセスするために使用
   var cameraViewModel: CameraViewModel?            // CameraViewModelへの参照。カメラのデータと設定の管理に使用
   weak var delegate: SettingsDelegate?             // 設定画面での操作を他のコンポーネントに通知する
   private let saveLocationPicker = UIPickerView()  // 保存先を選択するためのピッカービュー
   private var gridToggleSwitch: UISwitch!          // グリッド表示のオンオフトグル用のスイッチ
   private var viewModel = SettingsViewModel()      // 設定に関するデータや状態を管理するSettingsViewModelのインスタンス
   var settingsViewModel: SettingsViewModel?        // 他のクラスから設定データを受け取るためのSettingsViewModelのインスタンス
    
   let saveOptions = ["カメラロール", "アプリ内"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraViewModel = CameraViewModel()
        
        if settingsViewModel == nil {
            settingsViewModel = SettingsViewModel()
            print("SettingsViewModelが作成されました: \(settingsViewModel!)")
        } else {
            print("SettingsViewModelはすでに存在します: \(settingsViewModel!)")
        }
        
        // UISwitch の初期化
        gridToggleSwitch = UISwitch()

        // ViewModel のトグル状態を UI に反映
        print("ViewModel grid feature state: \(viewModel.isGridFeatureEnabled)")  // 状態を確認するログ
        gridToggleSwitch.isOn = viewModel.isGridFeatureEnabled  // ここでの値が期待通りかどうか確認

        // トグルが変更された時に ViewModel に状態を反映
        gridToggleSwitch.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        
        saveLocationPicker.delegate = self
        saveLocationPicker.dataSource = self
        
        // 初期状態を設定（UserDefaultsから読み込んだ保存先を反映）
        if let cameraViewModel = cameraViewModel {
            let selectedRow = cameraViewModel.saveLocation == .cameraRoll ? 0 : 1
            saveLocationPicker.selectRow(selectedRow, inComponent: 0, animated: false)
        }
        
        // 右上に「アプリについて」ボタンを追加
        let aboutButton = UIBarButtonItem(title: "アプリについて", style: .plain, target: self, action: #selector(openAboutPage))
        navigationItem.rightBarButtonItem = aboutButton
        
        view.backgroundColor = UIColor(red: 0.85, green: 0.93, blue: 0.85, alpha: 1.0)
        
        // ナビゲーションバーを表示
        navigationController?.isNavigationBarHidden = false
        navigationItem.title = "Settings"
        navigationController?.navigationBar.tintColor = UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)]

        
        setupUI()
    } // viewDidLoad
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ViewModel のトグル状態を UI に反映
        print("ViewWillAppear grid feature state: \(viewModel.isGridFeatureEnabled)")  // デバッグログ
        gridToggleSwitch.isOn = viewModel.isGridFeatureEnabled
    }

    @objc func saveLocationChanged(_ sender: UISegmentedControl) {
        // 保存先が変更された時の処理
        if sender.selectedSegmentIndex == 0 {
            cameraViewModel?.saveLocation = .cameraRoll
        } else {
            cameraViewModel?.saveLocation = .documentDirectory
        }
    }
    
    // トグルの状態が変更された時に呼ばれる
    @objc private func toggleChanged(_ sender: UISwitch) {
        viewModel.isGridFeatureEnabled = sender.isOn
    }
    
    @objc func openAboutPage() {
        let webViewController = WebViewController()
        webViewController.urlString = "https://github.com/Ryokisil/cameraApp/blob/main/README.md"
        present(webViewController, animated: true, completion: nil)
    }

    // UIのセットアップ
    private func setupUI() {
        // 保存先のラベルを追加
        let saveLocationLabel = UILabel()
        saveLocationLabel.text = "保存先"
        saveLocationLabel.textAlignment = .center
        saveLocationLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        view.addSubview(saveLocationLabel)
        saveLocationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveLocationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveLocationLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
        
        // 保存先選択ピッカーを追加
        view.addSubview(saveLocationPicker)
        saveLocationPicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveLocationPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveLocationPicker.topAnchor.constraint(equalTo: saveLocationLabel.bottomAnchor, constant: 10),
            saveLocationPicker.widthAnchor.constraint(equalToConstant: 200),
            saveLocationPicker.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        // グリッド機能のラベルを追加
        let gridSwitchLabel = UILabel()
        gridSwitchLabel.text = "グリッド"
        gridSwitchLabel.textAlignment = .center
        gridSwitchLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.8, alpha: 1.0)
        view.addSubview(gridSwitchLabel)
        gridSwitchLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gridSwitchLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gridSwitchLabel.topAnchor.constraint(equalTo: saveLocationPicker.bottomAnchor, constant: 20)
        ])
        
        // UISwitchのセットアップと追加
        gridToggleSwitch.isOn = isGridEnabled
        view.addSubview(gridToggleSwitch)
        gridToggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gridToggleSwitch.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gridToggleSwitch.topAnchor.constraint(equalTo: gridSwitchLabel.bottomAnchor, constant: 10)
        ])
    }

    // UIPickerViewのデリゲートメソッド: 列の数を返す
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // UIPickerViewのデリゲートメソッド: 行の数を返す
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return saveOptions.count // 保存先の選択肢は2つ
    }
    
    // UIPickerViewのデリゲートメソッド: 各行のタイトルを設定
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return saveOptions[row]
    }
    
    // UIPickerViewのデリゲートメソッド: 選択された行の処理
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row == 0 {
            cameraViewModel?.saveLocation = .cameraRoll
            print("保存先: カメラロール")
        } else {
            cameraViewModel?.saveLocation = .documentDirectory
            print("保存先: ドキュメントディレクトリ")
        }
        
        // デリゲートを通じて保存先の変更を通知
        cameraViewModel?.saveLocation = row == 0 ? .cameraRoll : .documentDirectory
    }
}

class WebViewController: UIViewController {
    var urlString: String?
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // WKWebViewの初期化と設定
        webView = WKWebView(frame: self.view.frame)
        self.view.addSubview(webView)
        
        if let urlString = urlString, let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}
