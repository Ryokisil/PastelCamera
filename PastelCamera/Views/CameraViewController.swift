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
    
    private let thumbnailImageView = UIImageView()
    private var frameCounter = 0
    private var viewModel = CameraViewModel()                      // ViewModelのインスタンス。データ管理とUIロジックを担当
    private let photoViewModel = PhotoViewModel()
    private var cancellables = Set<AnyCancellable>()
    var shutterSoundID: SystemSoundID = 0
    var isFlashOn = false                                 // フラッシュのオン/オフ状態を保持するフラグ
    var latestFilteredImage: UIImage?
    var capturedImage: UIImage?                           // サムネイルに表示する撮影済みの画像
    var ciContext: CIContext!
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
    
    // アプリ起動時のみviewDidLoadで初期設定を行う
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ViewModelの初期化と設定
        viewModel = CameraViewModel()
        updateButtonStates()
        
        viewModel.delegate = self
        
        // カメラの設定をViewModelに任せる
        viewModel.setupCamera()
        
        // プレビューレイヤーのセットアップ
        setupCameraPreview()
        
        // UIのセットアップ
        setupUI()
        self.view.bringSubviewToFront(wideAngleButton) //　UIを一番手前に設置
        self.view.bringSubviewToFront(ultraWideButton) // UIを一番手前に設置
        
        // MP3ファイルから SystemSoundID を作成
        if let soundURL = Bundle.main.url(forResource: "Camera-Phone01-1", withExtension: "mp3") {
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &shutterSoundID)
        }
        
        // photoViewModelから「サムネイル更新」の通知を受け取る
        photoViewModel.onThumbnailUpdated = { [weak self] image in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.thumbnailButton.setImage(image, for: .normal)
                self.capturedImage = image
            }
        }
        
        ciContext = CIContext()
        
        addSwipeGestures()
        
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

    // カメラプレビューのセットアップ
    private func setupCameraPreview() {
        guard let captureSession = viewModel.captureSession else {
            print("captureSessionがまだ初期化されていません")
            return
        }
    }
    
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

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        thumbnailButton.translatesAutoresizingMaskIntoConstraints = false
        wideAngleButton.translatesAutoresizingMaskIntoConstraints = false
        ultraWideButton.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
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
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,didOutput sampleBuffer: CMSampleBuffer,from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)


        DispatchQueue.global(qos: .userInitiated).async {
            let currentFilter = self.viewModel.currentFilter as (CustomFilterProtocol & CIFilter)

            currentFilter.inputImage = ciImage

            // inputImage セット後の状態をログ出力
            if (currentFilter.inputImage) != nil {
                //print("inputImage セット後: \(currentFilter) inputImage=\(input)")
            } else {
                //print("inputImage セットに失敗しました")
            }

            guard let outputImage = currentFilter.outputImage,
                  let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                //print("フィルター処理に失敗しました")
                return
            }
            //print("Got outputImage")
            
            DispatchQueue.main.async {
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                self.imageView.image = uiImage
                self.latestFilteredImage = uiImage
            }
        }
    }
}

class ZoomSelectorView: UIView {
    var onZoomSelected: ((CGFloat) -> Void)?

    private let zoomOptions: [CGFloat] = [0.5, 1.0]
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.layer.cornerRadius = 10
        self.clipsToBounds = true

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 8

        for zoom in zoomOptions {
            let button = UIButton(type: .system)
            button.setTitle(zoom == 1.0 ? "1x" : "\(zoom)x", for: .normal)
            button.tag = Int(zoom * 10)
            button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            button.setTitleColor(.white, for: .normal)
            button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)

            buttons.append(button) // ボタンを配列に追加
            stackView.addArrangedSubview(button)
        }

        self.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
            stackView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8)
        ])
    }

    @objc private func zoomButtonTapped(_ sender: UIButton) {
        let selectedZoom = CGFloat(sender.tag) / 10.0
        onZoomSelected?(selectedZoom)
        updateSelection(for: selectedZoom)
    }

    func updateSelection(for selectedZoom: CGFloat) {
        for button in buttons {
            if CGFloat(button.tag) / 10.0 == selectedZoom {
                button.layer.borderColor = UIColor.yellow.cgColor
                button.layer.borderWidth = 2
                button.layer.cornerRadius = 5
            } else {
                button.layer.borderWidth = 0
            }
        }
    }
}
