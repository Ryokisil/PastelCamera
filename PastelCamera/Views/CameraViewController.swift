//画面1 アプリ起動時カメラを起動する画面

import UIKit
import AVFoundation
import SwiftUI
import Photos
import CoreImage
import Combine
import AudioToolbox

// UIViewControllerをSwiftUIで使えるようにする
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 特に更新処理がないのでこのまま
    }
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, CameraViewModelDelegate {
    func didCapturePhoto(_ photo: UIImage) {
        // サムネイルの更新
        thumbnailButton.setImage(photo, for: .normal)
        // 撮影した画像を capturedImage にセット
        capturedImage = photo
    }
    
    private var initialZoomFactor: CGFloat = 1.0
    private var currentDevice: AVCaptureDevice? {
        return viewModel.currentDevice
    }
    private var viewModel = CameraViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let thumbnailViewModel = ThumbnailViewModel()
    var shutterSoundID: SystemSoundID = 0
    var isFlashOn = false
    var latestFilteredImage: UIImage?
    var capturedImage: UIImage?
    var ciContext = CIContext(options: nil)
    var filters: [CIFilter] = []
    var currentFilterIndex = 0
    var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
        
    // シャッターボタン
    private let shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 1.0, green: 0.8, blue: 0.86, alpha: 1.0)
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 5
        button.layer.borderColor = UIColor.lightGray.cgColor
        return button
    }()
    
    // インバックカメラ切り替えボタン
    private let flipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)  // カメラ切り替え用のアイコン
        button.tintColor = UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1.0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // フラッシュボタン
    private let flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal) // 初期はフラッシュOFFのアイコン
        button.tintColor = UIColor(red: 0.75, green: 1.0, blue: 0.85, alpha: 1.0)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // カメラロールのデータの最新画像をサムネとして表示するやつ
    private let thumbnailButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        return button
    }()
    
    // 広角カメラ(1.0)のボタン
    private let wideAngleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("1.0", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 25 // 円形にする
        button.clipsToBounds = true
        return button
    }()

    // 超広角カメラ(0.5)のボタン
    private let ultraWideButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("0.5", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 25 // 円形にする
        button.clipsToBounds = true
        return button
    }()
    
    // フィルター名表示用ラベル
    private let filterNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isHidden = true  // 初期表示は非表示
        return label
    }()
    
    // アプリ起動時のみviewDidLoadで初期設定を行う
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateButtonStates()
        
        viewModel.delegate = self

        viewModel.setupCamera()
        
        // ピンチジェスチャーの追加
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        // UIのセットアップ
        setupUI()
        self.view.bringSubviewToFront(wideAngleButton) //　UIを一番手前に設置
        self.view.bringSubviewToFront(ultraWideButton) // UIを一番手前に設置
        self.view.bringSubviewToFront(filterNameLabel) // UIを一番手前に設置
        
        // MP3ファイルから SystemSoundID を作成
        if let soundURL = Bundle.main.url(forResource: "Camera-Phone01-1", withExtension: "mp3") {
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &shutterSoundID)
        }
        
        ciContext = CIContext()
        
        addSwipeGestures()
        
        setupBindings()
        
        // photoViewModelから「サムネイル更新」の通知を受け取る
        thumbnailViewModel.onThumbnailUpdated = { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.thumbnailButton.setImage(image, for: .normal)
                self.capturedImage = image
            }
        }
    } // viewDidLoad
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let videoOutput = viewModel.videoOutput {
            let queue = DispatchQueue(label: "videoQueue")
            videoOutput.setSampleBufferDelegate(self, queue: queue)
        }
    }
    
    // 初回撮影後に再度カメラプレビュー画面に戻ったらそれ以降はviewWillAppearで状態管理する
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        
//        
//    }
//    
//    override func viewDidDisappear(_ animated: Bool) {
//        super.viewDidDisappear(animated)
//        
//    }
    
    func addSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            viewModel.switchToNextFilter()
        } else if gesture.direction == .right {
            viewModel.switchToPreviousFilter()
        }
        
        let name = viewModel.currentFilter.filterName
        filterNameLabel.text = name
        filterNameLabel.isHidden = false
        
        print("★handleSwipe: labelに \(name) をセット")

        print("現在のフィルター: \(viewModel.currentFilter)")
    }
    
    // カメラで写真を撮影する処理
    func capturePhoto() {
        print("写真撮影を開始")
        // latestFilteredImage が存在するならそれを保存
        guard let imageToSave = latestFilteredImage else {
            print("フィルタ適用後の画像がまだありません")
            return
        }

        // カメラロールへ保存
        UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil)
        print("フィルタ適用済み画像を保存しました")
    }
    
    // UIのセットアップ
    private func setupUI() {
        view.addSubview(shutterButton)    // 撮影ボタン
        view.addSubview(flashButton)      // フラッシュボタン
        view.addSubview(flipButton)       // フリップボタン
        view.addSubview(thumbnailButton)  // カメラロールから持ってきたサムネを表示（新しい順）
        view.addSubview(wideAngleButton)  // 広角カメラ(1.0)のボタン
        view.addSubview(ultraWideButton)  // 超広角カメラ(0.5)のボタン
        view.addSubview(imageView)        // 各種フィルター
        view.addSubview(filterNameLabel)  // フィルターの名前を表示するやつ

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
        wideAngleButton.translatesAutoresizingMaskIntoConstraints = false
        ultraWideButton.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        filterNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // シャッターボタンのレイアウト
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70)
        ])

        // フラッシュボタンのレイアウト
        NSLayoutConstraint.activate([
            flashButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20), // 画面右端から20pt離す
            flashButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),   // 画面下端から20pt離す
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // フリップボタンのレイアウト
        NSLayoutConstraint.activate([
            flipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),  // 画面上部に配置
            flipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),  // 右端に配置
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // サムネイルボタンのレイアウト
        NSLayoutConstraint.activate([
            thumbnailButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            thumbnailButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            thumbnailButton.widthAnchor.constraint(equalToConstant: 60),
            thumbnailButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // 広角カメラのレイアウト
        NSLayoutConstraint.activate([
            wideAngleButton.widthAnchor.constraint(equalToConstant: 50),
            wideAngleButton.heightAnchor.constraint(equalToConstant: 50),
            wideAngleButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 230),
            wideAngleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -60),
        ])
        
        // 超広角カメラのレイアウト
        NSLayoutConstraint.activate([
            ultraWideButton.widthAnchor.constraint(equalToConstant: 50),
            ultraWideButton.heightAnchor.constraint(equalToConstant: 50),
            ultraWideButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 230),
            ultraWideButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 60)
        ])
        
        // フィルター
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 3.0/4.0)
        ])
        
        NSLayoutConstraint.activate([
            filterNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            filterNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            filterNameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            filterNameLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // シャッターボタンに撮影アクション
        shutterButton.addTarget(self, action: #selector(didTapShutterButton), for: .touchUpInside)
        // フラッシュボタンのアクション
        flashButton.addTarget(self, action: #selector(didTapFlashButton), for: .touchUpInside)
        // インバックカメラ切り替えアクション
        flipButton.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        // カメラロールから取得してるサムネボタンのタップアクション
        thumbnailButton.addTarget(self, action: #selector(thumbnailTapped), for: .touchUpInside)
        // 広角カメラ切り替えアクション
        wideAngleButton.addTarget(self, action: #selector(didTapWideAngleButton), for: .touchUpInside)
        // 超広角カメラ切り替えアクション
        ultraWideButton.addTarget(self, action: #selector(didTapUltraWideButton), for: .touchUpInside)
    }
    
    private func setupBindings() {
        // filterNameForDisplay の値を購読し、UIを更新
        viewModel.$filterNameForDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filterName in
                guard let self = self else { return }
                if let name = filterName {
                    self.filterNameLabel.text = name
                    self.filterNameLabel.isHidden = false
                } else {
                    self.filterNameLabel.isHidden = true
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func didTapWideAngleButton() {
        viewModel.switchToWideAngle()
        updateButtonStates()
        flashButton.isHidden = false
    }

    @objc private func didTapUltraWideButton() {
        viewModel.switchToUltraWide()
        updateButtonStates()
        flashButton.isHidden = true
    }
    
    // ボタンの状態を更新
    private func updateButtonStates() {
        wideAngleButton.isEnabled = viewModel.canSwitchToWideAngle
        ultraWideButton.isEnabled = viewModel.canSwitchToUltraWide
    }
        
    // シャッターボタン押下時のアクション
    @objc private func didTapShutterButton() {
        capturePhoto()
        AudioServicesPlaySystemSound(shutterSoundID)
    }
    
    @objc private func didTapFlashButton() {
        // ここで「現在の状態」を反転させてトーチをオン/オフ切り替え
        let newIsOn = !viewModel.isTorchOn
        
        // トーチを操作 (ViewModel 側に書いてある toggleTorch(isOn:) を呼ぶ)
        viewModel.toggleTorch(isOn: newIsOn)
        
        // UIアイコンを更新 (オンなら "bolt.fill", オフなら "bolt.slash.fill")
        let iconName = newIsOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: iconName), for: .normal)
        
        // ViewModel がトーチの状態を保持しているなら、そこも更新
        viewModel.isTorchOn = newIsOn
    }
    
    // インカメとバックカメラ切り替えボタン
    @objc func flipButtonTapped() {
        // フェードアウトアニメーション
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0.0  // 画面を一度透明にする
        }) { _ in
            // カメラの切り替えを行う
            self.viewModel.flipBackandFrontCamera()
            
            // フロントカメラがアクティブならフラッシュボタン、広角カメラボタン、超広角カメラボタンを非表示にする
            self.flashButton.isHidden = self.viewModel.isFrontCameraActive
            self.wideAngleButton.isHidden = self.viewModel.isFrontCameraActive
            self.ultraWideButton.isHidden = self.viewModel.isFrontCameraActive
            
            UIView.animate(withDuration: 0.3) {
                self.view.alpha = 1.0  // 画面を元に戻す
            }
        }
    }
    
    // サムネイルがタップされた時の処理
    @objc private func thumbnailTapped() {
        print("サムネイルがタップされました")
        guard let image = capturedImage else {
            print("エラー: capturedImage が nil です")
            return
        }
        print("OK, capturedImageあり: \(image.size)")
        
        let detailVC = PhotoDetailViewController()
        detailVC.originalImage = image
        detailVC.modalPresentationStyle = .fullScreen
        
        print("Try presenting detailVC now")
        present(detailVC, animated: true) {
            print("Done presenting detailVC")
        }
    }
    
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = currentDevice else { return }
        
        switch pinch.state {
        case .began:
            // ピンチ開始時に初期ズームを記録
            initialZoomFactor = device.videoZoomFactor
            do {
                // ピンチ中ロックを保持し続ける（短時間ならOK）
                try device.lockForConfiguration()
            } catch {
                print("zoom lock error:", error)
            }
            
        case .changed:
            // ピンチ中は常にズームを更新
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            let minZoomFactor: CGFloat = 1.0
            
            // ピンチのscaleに初期ズーム値を掛け合わせる
            var zoomFactor = initialZoomFactor * pinch.scale
            zoomFactor = max(minZoomFactor, min(zoomFactor, maxZoomFactor))
            
            device.videoZoomFactor = zoomFactor
            
        case .ended, .cancelled, .failed:
            // ピンチ終了時にアンロック
            device.unlockForConfiguration()
            
        default:
            break
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 重いフィルタ処理は非同期で実行
        DispatchQueue.global(qos: .userInitiated).async {
            // 現在のフィルタを取得
            let currentFilter = self.viewModel.currentFilter as (CustomFilterProtocol & CIFilter)
            
            // フィルタに入力画像をセット
            currentFilter.inputImage = ciImage
            
            // フィルタ出力 → CGImage を生成
            guard
                let outputImage = currentFilter.outputImage,
                let cgImage = self.ciContext.createCGImage(outputImage,
                                                                     from: outputImage.extent)
            else {
                // フィルタ適用失敗
                return
            }
            
            // UI更新はメインスレッドで
            DispatchQueue.main.async {
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                self.imageView.image = uiImage
                self.latestFilteredImage = uiImage
            }
        }
    }
}
