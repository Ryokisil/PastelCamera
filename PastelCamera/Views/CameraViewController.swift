//画面1 アプリ起動時カメラを起動する画面

import UIKit
import AVFoundation
import SwiftUI
import Photos

// UIViewControllerをSwiftUIで使えるようにする
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 特に更新処理がないのでこのまま
    }
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, CameraViewModelDelegate {
    func didCapturePhoto(_ photo: UIImage) {
        // サムネイルの更新（例として表示）
        thumbnailButton.setImage(photo, for: .normal)
        // 撮影した画像を capturedImage にセット
        capturedImage = photo
        
        // サムネイルを更新（例として表示用に使用）
        thumbnailButton.setImage(photo, for: .normal)
    }
    
    var viewModel: CameraViewModel!                       // ViewModelのインスタンス。データ管理とUIロジックを担当。
    var isFlashOn = false                                 // フラッシュのオン/オフ状態を保持するフラグ。
    var captureSession: AVCaptureSession?                 // カメラのキャプチャセッション。映像入力の設定を管理する。
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?    // ビデオプレビューを表示するレイヤー（プレビュー画面に表示するため）。
    var capturedImage: UIImage?                           // サムネイルに表示する撮影済みの画像。
    private var previewLayer: AVCaptureVideoPreviewLayer! // カメラのプレビューを表示するレイヤー。
    private var gridOverlayView: UIView?                  // カメラのグリッドオーバーレイ表示用のビュー。
        
    // シャッターボタン
    private let shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.86, alpha: 1.0)
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor.lightGray.cgColor
        return button
    }()
    // インバックカメラ切り替えボタンのラベル
    private let flipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)  // カメラ切り替え用のアイコン
        button.tintColor = UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1.0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    // フラッシュボタンのラベル
    private let flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal) // 初期はフラッシュOFFのアイコン
        button.tintColor = UIColor(red: 0.75, green: 1.0, blue: 0.85, alpha: 1.0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // カウントダウン表示用のラベル
    private let countdownLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 80)
        label.textColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true  // 初期状態では非表示
        return label
    }()

    // 設定用の歯車アイコン
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "gearshape"), for: .normal) // 歯車アイコン
        button.tintColor = UIColor(red: 0.9, green: 0.8, blue: 1.0, alpha: 1.0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let thumbnailButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        return button
    }()
    
    // アプリ起動時のみviewDidLoadで初期設定を行う
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // グリッド表示の通知を受け取るオブザーバーを追加
        NotificationCenter.default.addObserver(self, selector: #selector(gridFeatureDidChange(_:)), name: .gridFeatureDidChange, object: nil)
        
        // 初回の設定（UserDefaultsの状態に基づいてグリッドを表示）
        let isGridEnabled = UserDefaults.standard.bool(forKey: "gridFeatureEnabled")
        updateGridVisibility(isGridEnabled)
        
        // videoPreviewLayer の上にグリッドを重ねる
        if let previewLayer = videoPreviewLayer {
            let gridLayer = CALayer()
            gridLayer.frame = previewLayer.bounds
            gridLayer.backgroundColor = UIColor.clear.cgColor
            addGridLines(to: gridLayer)
            
            previewLayer.addSublayer(gridLayer)
        }
        
        // ViewModelの初期化と設定
        viewModel = CameraViewModel()
        
        viewModel.delegate = self
        // AVCaptureSession の初期化
        captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession?.addInput(input)
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            captureSession?.addOutput(videoOutput)
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession?.startRunning()
            }
            
        } catch {
            print("カメラの設定中にエラーが発生しました: \(error)")
        }
        
        // カメラの設定をViewModelに任せる
        viewModel.setupCamera()
        
        // プレビューレイヤーのセットアップ
        setupCameraPreview()
        
        // UIのセットアップ
        setupUI()
        
        // サムネイル画像を設定
        updateThumbnail()
        
        // シャッターボタンにアクションを設定
        shutterButton.addTarget(self, action: #selector(didTapShutterButton), for: .touchUpInside)
        // フラッシュボタンのアクションを設定
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        //インバックカメラ切り替えアクション設定
        flipButton.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        // タップ時に設定画面へ遷移
        settingsButton.addTarget(self, action: #selector(didTapSettingsButton), for: .touchUpInside)
        // ボタンのタップアクションを追加
        thumbnailButton.addTarget(self, action: #selector(thumbnailTapped), for: .touchUpInside)
        
        // アプリ起動時はフラッシュをオフに設定
        isFlashOn = false
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        
    } // viewDidLoad
    
    // 初回撮影後に再度カメラプレビュー画面に戻ったらそれ以降はviewWillAppearで状態管理する
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // カメラ画面が再度表示されるたびにフラッシュ状態をリセット
        isFlashOn = false
        updateFlashButtonIcon(isFlashOn: isFlashOn)
        
        // 再表示時にグリッドの状態を再確認
        let isGridEnabled = UserDefaults.standard.bool(forKey: "gridFeatureEnabled")
        updateGridVisibility(isGridEnabled)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        captureSession?.stopRunning() // バックグラウンドへ移動中はリソースを節約したい
        
        // 通知オブザーバーを解除
        NotificationCenter.default.removeObserver(self, name: .gridFeatureDidChange, object: nil)
    }
    
    // カメラのフレームごとに呼ばれる
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 映像フレームごとに処理を行う
    }

    // カメラプレビューのセットアップ
    private func setupCameraPreview() {

        // プレビュー用のレイヤーを設定
        previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.captureSession)
        // 解像度に応じたアスペクト比の変更を適用
        switch viewModel.captureSession.sessionPreset {
        case .photo: // 4:3
            previewLayer.videoGravity = .resizeAspect  // 4:3
        case .high, .medium: // 16:9
            previewLayer.videoGravity = .resizeAspectFill  // 16:9
        default:
            previewLayer.videoGravity = .resizeAspect  // デフォルトは4:3
        }
        
        // プレビューの位置とサイズを設定
        let previewHeight = view.bounds.height * 0.8
        previewLayer.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: previewHeight)
        
        // プレビューを画面にフィットさせカメラレイヤーを1番下に設置
        view.layer.sublayers?.removeAll()  // これで古いレイヤーを削除
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    // 通知でグリッドの表示状態が変更されたときに呼ばれる
    @objc private func gridFeatureDidChange(_ notification: Notification) {
        if let isEnabled = notification.object as? Bool {
            updateGridVisibility(isEnabled)
        }
    }

    // グリッドの表示/非表示を更新する
    private func updateGridVisibility(_ isEnabled: Bool) {
        if isEnabled {
            // グリッドを表示する
            if let videoPreviewFrame = videoPreviewLayer?.frame {
                let gridView = UIView(frame: videoPreviewFrame)
                gridView.backgroundColor = UIColor.clear // 背景は透明
                gridView.layer.borderColor = UIColor.lightGray.cgColor
                gridView.layer.borderWidth = 1.0
                addGridLines(to: gridView.layer)

                view.addSubview(gridView)
                gridOverlayView = gridView
                // タッチイベントを無効化
                gridView.isUserInteractionEnabled = false
            }
        } else {
            // グリッドを非表示にする
            gridOverlayView?.removeFromSuperview()
            gridOverlayView = nil
        }
    }
    
    // ビューのレイアウトが変更される直前に呼び出される。フレームを再調整する
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let videoPreviewLayer = videoPreviewLayer else { return }

        // 画面幅を基準に4:3アスペクト比の高さを設定
        let screenWidth = view.bounds.width
        let previewHeight = screenWidth * 4 / 3

        // videoPreviewLayerとgridOverlayViewにフレームを適用
        let yOffset = (view.bounds.height - previewHeight) / 2 + 12
        let previewFrame = CGRect(x: 0, y: yOffset, width: screenWidth, height: previewHeight)

        videoPreviewLayer.frame = previewFrame
        gridOverlayView?.frame = previewFrame
    }

    // 指定したレイヤーにグリッド線を描画する
    private func addGridLines(to layer: CALayer) {
        let lineColor = UIColor.lightGray.cgColor
        
        // 縦線を追加
        for i in 1..<3 {
            let verticalLine = CALayer()
            verticalLine.backgroundColor = lineColor
            verticalLine.frame = CGRect(x: layer.bounds.width * CGFloat(i) / 3, y: 0, width: 1, height: layer.bounds.height)
            layer.addSublayer(verticalLine)

            // 横線を追加
            let horizontalLine = CALayer()
            horizontalLine.backgroundColor = lineColor
            horizontalLine.frame = CGRect(x: 0, y: layer.bounds.height * CGFloat(i) / 3, width: layer.bounds.width, height: 1)
            layer.addSublayer(horizontalLine)
        }
    }

    // インスタンス解放時に通知のオブザーバー登録を解除してメモリリークを防ぐ
    deinit {
        NotificationCenter.default.removeObserver(self, name: .gridFeatureDidChange, object: nil)
    }
    
    // UIのセットアップ
    private func setupUI() {
        view.addSubview(shutterButton)    // 撮影ボタン
        view.addSubview(flashButton)      // フラッシュボタン
        view.addSubview(countdownLabel)   // カウントダウンラベル
        view.addSubview(flipButton)       // フリップボタン
        view.addSubview(settingsButton)   // 歯車ボタン
        view.addSubview(thumbnailButton)

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        thumbnailButton.translatesAutoresizingMaskIntoConstraints = false

        // シャッターボタンのレイアウト
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70)
        ])

        // フラッシュボタンのレイアウト（シャッターボタンの左側に配置）
        NSLayoutConstraint.activate([
            flashButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor, constant: -5),
            flashButton.trailingAnchor.constraint(equalTo: shutterButton.leadingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // カウントダウンラベルを画面の中央に配置したい
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // フリップボタンのレイアウト
        NSLayoutConstraint.activate([
            flipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),  // 画面上部に配置
            flipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),  // 右端に配置
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 歯車ボタンのレイアウト
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // サムネイルボタンのレイアウト
        NSLayoutConstraint.activate([
            thumbnailButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            thumbnailButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            thumbnailButton.widthAnchor.constraint(equalToConstant: 60),
            thumbnailButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    // フラッシュボタンのアイコンを更新する
    func updateFlashButtonIcon(isFlashOn: Bool) {
        let flashIconName = isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: flashIconName), for: .normal)
    }
        
    // シャッターボタン押下時のアクション
    @objc private func didTapShutterButton() {
        startCountdown()
    }

    // カウントダウンを開始する
    private func startCountdown() {
        countdownLabel.isHidden = false
        countdown(from: 3)
    }

    // カウントダウン処理
    private func countdown(from count: Int) {
        countdownLabel.text = "\(count)"
        
        if count > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.countdown(from: count - 1)
            }
        } else {
            // カウントダウンが終了したら写真を撮影
            countdownLabel.isHidden = true
            viewModel.capturePhoto()  // ViewModelに写真撮影を依頼
        }
    }
    // フラッシュボタン設置
    @objc func toggleFlash() {
        // フラッシュの点灯/消灯を制御
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            print("エラー: カメラが利用できないか、またはトーチがサポートされていません")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // 現在のフラッシュ状態に応じてトーチモードを設定
            if isFlashOn {
                device.torchMode = .off  // フラッシュをオフに
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)  // フラッシュをオンに
            }
            
            device.unlockForConfiguration()
            
            // フラッシュの状態をトグル
            isFlashOn.toggle()
            
            // アイコンの更新
            flashButton.setImage(UIImage(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill"), for: .normal)
            
        } catch {
            print("トーチの切り替え中にエラーが発生しました: \(error)")
        }
    }
    
    // カメラ切り替えボタン設置と切り替え時にアニメーション追加
    @objc func flipButtonTapped() {
        // フェードアウトアニメーション
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0  // 画面を一度透明にする
        }) { _ in
            // カメラの切り替えを行う
            self.viewModel.flipCamera()
            
            // フロントカメラがアクティブならフラッシュボタンを非表示にする
            self.flashButton.isHidden = self.viewModel.isFrontCameraActive
            
            UIView.animate(withDuration: 0.3) {
                self.view.alpha = 1.0  // 画面を元に戻す
            }
        }
    }
    
    @objc private func didTapSettingsButton() {
        // 設定画面へ遷移
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // サムネイルがタップされた時の処理
    @objc private func thumbnailTapped() {
        print("サムネイルがタップされました")
        guard let image = capturedImage else {
            print("エラー: capturedImage が nil です")
            return
        }
        
        let detailVC = PhotoDetailViewController()
        detailVC.image = image
        detailVC.modalPresentationStyle = .fullScreen
        present(detailVC, animated: true, completion: nil)
    }
    
    func updateThumbnail() {
        // カメラロールから最新の画像を取得
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let latestAsset = fetchResult.firstObject else { return }

        // サムネイルサイズでリクエストを作成
        let imageManager = PHImageManager.default() // ここでimageManagerを定義
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        let scale = UIScreen.main.scale
        let thumbnailSize = CGSize(width: 500 * scale, height: 700 * scale)  // 必要に応じてサイズ調整

        imageManager.requestImage(for: latestAsset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            guard let self = self, let image = image else { return }
            self.thumbnailButton.setImage(image, for: .normal)
            self.capturedImage = image
        }
    }
}
