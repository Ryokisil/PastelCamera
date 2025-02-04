
import AVFoundation
import CoreImage
import UIKit
import Combine
import Photos

// ViewModel用のプロトコル定義
protocol CameraViewModelDelegate: AnyObject {
    func didCapturePhoto(_ photo: UIImage)
    
}

class CameraViewModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate: CameraViewModelDelegate?
    
    @Published var filterNameForDisplay: String? = nil // フィルター名を一時的に表示させるプロパテjィ
    @Published var isTorchOn = false                   //トーチの追跡
    private var initialZoomFactor: CGFloat = 1.0
    private var photoOutput: AVCapturePhotoOutput!     // 写真のキャプチャを管理する出力オブジェクト
    private var hideLabelTask: DispatchWorkItem?       // 切り替え時の消去用タスク（前回のタイマーをキャンセルするために保持しておく）
    private(set) var currentDevice: AVCaptureDevice?   // 現在使用中のカメラデバイス（広角や超広角カメラなど）を保持する
    private(set) var isWideAngle: Bool = true          // 現在のカメラ状態(広角か超広角か)を追跡
    private(set) var isFrontCameraActive: Bool = false // インカメの追跡
    var captureSession: AVCaptureSession!              // カメラの入力（デバイス）と出力（写真、ビデオなど）のデータフローを管理する
    var videoOutput: AVCaptureVideoDataOutput!
    var originalInputImage: CIImage?
    var currentFilterIndex = 0
    // 現在のフィルターインスタンスを取得
    var currentFilter: (CIFilter & CustomFilterProtocol) {
        return filters[currentFilterIndex]()
    }
    // フィルタインスタンスを都度生成して不要なリソースを抱えないようにしたい
    lazy var filters: [() -> (CIFilter & CustomFilterProtocol)] = [
        { OriginalFilter() },
        { PastelLavenderFilter() },
        { PastelLightBlueFilter() },
        { PastelMintFilter() },
        { PastelPinkFilter() },
        { PastelRoseFilter() },
        { PastelVioletFilter() },
        { PastelYellowFilter() },
        { PastelLilacFilter() },
        { PastelAquaFilter() }
    ]
    
    var canUseTorch: Bool {
        return isWideAngle  // 広角なら true、超広角なら false
    }
    
    // ボタンの有効/無効状態を取得
    var canSwitchToWideAngle: Bool {
        return !isWideAngle
    }

    var canSwitchToUltraWide: Bool {
        return isWideAngle
    }
    
    // 次のフィルターに切り替え
    func switchToNextFilter() {
        switchFilter(isNext: true)
        // フィルターをキャッシュから取得
        _ = currentFilter
    }
    
    // 前のフィルターに切り替え
    func switchToPreviousFilter() {
        switchFilter(isNext: false)
        // フィルターをキャッシュから取得
        _ = currentFilter
    }
    
    // フィルターの切り替え
    func switchFilter(isNext: Bool) {
        // インデックス更新前のチェック
        guard !filters.isEmpty else {
            print("エラー: フィルター配列が空です")
            return
        }
        
        // 現在のフィルターインスタンスを解放
        let currentFilterName = currentFilter.filterName
        
        // インデックスを更新
        let previousIndex = currentFilterIndex
        currentFilterIndex = isNext
        ? (currentFilterIndex + 1) % filters.count // 次のフィルター
        : (currentFilterIndex - 1 + filters.count) % filters.count // 前のフィルター
        
        // 新しいフィルターの取得
        let newFilter = currentFilter
        
        // フィルターの入力画像をリセット
        if let originalImage = originalInputImage { // originalInputImage は元の画像
            newFilter.inputImage = originalImage
        }
        
        // フィルター名を表示
        filterNameForDisplay = newFilter.filterName
        
        // 前のタスクをキャンセル
        hideLabelTask?.cancel()
        
        // 新しいタスクをスケジュール
        let task = DispatchWorkItem { [weak self] in
            self?.filterNameForDisplay = nil
        }
        hideLabelTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
        
        // デバッグ情報
        print("Switched filter. Previous index: \(previousIndex), Current index: \(currentFilterIndex)")
        print("Current filter:", newFilter)
    }
    
    // カメラの初期設定を行う
    func setupCamera() {
        // セッション作成
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("エラー: カメラが利用できません")
            return
        }

        captureSession.addInput(input)
        
        self.currentDevice = backCamera

        // PhotoOutput 設定
        photoOutput = AVCapturePhotoOutput()
        photoOutput?.isHighResolutionCaptureEnabled = false
        if #available(iOS 13.0, *) {
            photoOutput?.maxPhotoQualityPrioritization = .balanced
        }
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        // VideoOutput 設定 (リアルタイムフィルター用)
        videoOutput = AVCaptureVideoDataOutput()
        let queue = DispatchQueue(label: "videoQueue")
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // セッション開始
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
            print("Capture session started in background thread")
            
            do {
                try backCamera.lockForConfiguration()
                let minZoom = backCamera.minAvailableVideoZoomFactor
                let maxZoom = backCamera.maxAvailableVideoZoomFactor
                print("★起動直後 backCamera minZoom=\(minZoom), maxZoom=\(maxZoom)")
                backCamera.unlockForConfiguration()
                
            } catch {
                print("Lock error for zoom debug: \(error)")
            }
        }
    }

    // 広角カメラに切り替える
    func switchToWideAngle() {
        switchCamera(to: .builtInWideAngleCamera)
        guard !isWideAngle else { return }
        isWideAngle = true
    }

    // 超広角カメラに切り替える
    func switchToUltraWide() {
        switchCamera(to: .builtInUltraWideCamera)
        guard isWideAngle else { return }
        isWideAngle = false
    }

    // カメラを切り替える共通処理
    private func switchCamera(to deviceType: AVCaptureDevice.DeviceType) {
        captureSession.beginConfiguration()

        // 現在の入力を削除
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }

        // 新しいカメラデバイスを設定
        guard let newDevice = AVCaptureDevice.default(deviceType, for: .video, position: .back) else {
            print("エラー: 指定したカメラが見つかりません")
            captureSession.commitConfiguration()
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentDevice = newDevice
            } else {
                print("エラー: 新しいカメラデバイスを追加できませんでした")
            }
        } catch {
            print("カメラ切り替え中にエラー: \(error)")
        }

        captureSession.commitConfiguration()
    }
    
    // トーチの設定（フラッシュ）
    func toggleTorch(isOn: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .back),
              device.hasTorch else {
            return
        }
        do {
            try device.lockForConfiguration()
            if isOn {
                try device.setTorchModeOn(level: 1.0) // 0.0~1.0
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            
            // 内部状態も更新するなら
            isTorchOn = isOn
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
    
    //カメラのフロントとバックを切り替える関数
    func flipBackandFrontCamera() {
        // 現在の入力デバイスを取得
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return
        }

        // 切り替えるカメラデバイスを取得（バックカメラ → フロントカメラ or フロントカメラ → バックカメラ）
        let newCameraDevice: AVCaptureDevice?
        if currentInput.device.position == .back {
            newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            isFrontCameraActive = true // フロントカメラがアクティブ
        } else {
            newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            isFrontCameraActive = false // バックカメラがアクティブ
        }

        // 新しいカメラが取得できなかった場合は終了
        guard let newDevice = newCameraDevice else {
            return
        }

        do {
            // 新しいカメラの入力を作成
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            
            // セッションの設定を再構成
            captureSession.beginConfiguration()
            
            // 現在のカメラ入力を削除
            captureSession.removeInput(currentInput)
            
            // 新しいカメラ入力を追加
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            } else {
                print("エラー: 新しいカメラ入力を追加できませんでした")
            }
            
            // 設定変更を確定
            captureSession.commitConfiguration()
            updatePreviewMirroring(isFrontCamera: isFrontCameraActive)
            
            // フロントカメラがアクティブなら解像度とフレームレートを確認
            if isFrontCameraActive {
                configureSessionForFrontCamera()
                logCurrentCameraSpecifications(for: newDevice)
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    /// 新しいデバイスの解像度とフレームレートをログに出力するヘルパー関数
    private func logCurrentCameraSpecifications(for device: AVCaptureDevice) {
        // 解像度の取得
        let activeFormat = device.activeFormat
        let description = activeFormat.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        print("現在の解像度: \(dimensions.width) x \(dimensions.height)")
        
        // フレームレートの取得
        for range in activeFormat.videoSupportedFrameRateRanges {
            print("サポートされているフレームレート範囲: \(range.minFrameRate) - \(range.maxFrameRate) fps")
        }
        
        let minFrameDuration = device.activeVideoMinFrameDuration
        let maxFrameDuration = device.activeVideoMaxFrameDuration
        
        let currentMinFPS = Double(minFrameDuration.timescale) / Double(minFrameDuration.value)
        let currentMaxFPS = Double(maxFrameDuration.timescale) / Double(maxFrameDuration.value)
        print("現在のフレームレート範囲: \(currentMinFPS) - \(currentMaxFPS) fps")
    }
    
    // インカメの時のプレビュー向きを調整
    func updatePreviewMirroring(isFrontCamera: Bool) {
        guard let connection = videoOutput.connection(with: .video) else {
            return
        }
        
        // ミラーリング
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isFrontCamera
        
        // 回転設定
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
        }
    }
    
    func configureSessionForFrontCamera() {
        captureSession.beginConfiguration()
        
        // フロントカメラ使用時に解像度をVGA(640x480)に下げる（4:3のアスペクト比）
        if isFrontCameraActive {
            if captureSession.canSetSessionPreset(.vga640x480) {
                captureSession.sessionPreset = .vga640x480
            } else {
                print("エラー: VGA640x480 プリセットに設定できません")
            }
        }
        
        captureSession.commitConfiguration()
    }
}

// 最新の写真サムネイルを扱うViewModel
final class ThumbnailViewModel: NSObject, PHPhotoLibraryChangeObserver {
    
    private(set) var latestThumbnail: UIImage?    // サムネイルの最新の写真
    var onThumbnailUpdated: ((UIImage?) -> Void)? // 新しい写真を取得したら呼ばれる通知クロージャ
    
    // フォトライブラリで取得したFetchResult
    private var fetchResult: PHFetchResult<PHAsset>?
    
    override init() {
        super.init()
        // フォトライブラリの変更を受け取るよう登録
        PHPhotoLibrary.shared().register(self)
        // 初回ロード時に最新写真を取得
        fetchLatestPhoto()
    }
    
    // 最新の写真を取得してサムネイル更新
    func fetchLatestPhoto() {
        let fetchOptions = PHFetchOptions()
        // creationDate降順で1枚だけ取得
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        // 写真アセットを取得
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        if let asset = result.firstObject {
            // 実際のサムネ画像を取得
            getThumbnail(for: asset) { [weak self] image in
                guard let self = self else { return }
                self.latestThumbnail = image
                // クロージャでViewControllerに通知
                self.onThumbnailUpdated?(image)
            }
        }
        
        // 今取得したFetchResultを保持しておき、ライブラリ変更時に差分をとる
        fetchResult = result
    }
    
    // 指定したPHAssetからサムネイルUIImageを生成
    private func getThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let scale = UIScreen.main.scale
        // サムネイルのサイズ（適宜調整）
        let size = CGSize(width: 200 * scale, height: 200 * scale)
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            completion(image)
        }
    }
    
    // フォトライブラリに変更があったとき呼ばれる
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 既にfetchResultを持っていたら、それに対する差分を取得
        guard let fetchResult = fetchResult,
              let details = changeInstance.changeDetails(for: fetchResult) else {
            return
        }
        
        // 最新のFetchResultに差し替え
        let updatedResult = details.fetchResultAfterChanges
        self.fetchResult = updatedResult
        
        // もし新しい写真が追加されていたらサムネ更新を行う
        let inserted = details.insertedObjects
        if !inserted.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.fetchLatestPhoto()
            }
        }
    }
    
    deinit {
        // ViewModel破棄時にリスナー解除
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}
