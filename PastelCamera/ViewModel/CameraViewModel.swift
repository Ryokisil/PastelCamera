
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
    
    @Published var isTorchOn = false
    private var photoOutput: AVCapturePhotoOutput!     // 写真のキャプチャを管理する出力オブジェクト
    private(set) var currentDevice: AVCaptureDevice?   // 現在使用中のカメラデバイス（広角や超広角カメラなど）を保持する
    private(set) var isWideAngle: Bool = true          // 現在のカメラ状態(広角か超広角か)を追跡
    private(set) var isFrontCameraActive: Bool = false // インカメの追跡
    var captureSession: AVCaptureSession!              // カメラの入力（デバイス）と出力（写真、ビデオなど）のデータフローを管理する
    var videoOutput: AVCaptureVideoDataOutput!
    var currentFilterIndex = 0
    // 現在のフィルターを取得
    var currentFilter: (CIFilter & CustomFilterProtocol) {
        return filters[currentFilterIndex]
    }
    // フィルタ配列をCustomFilterProtocol & CIFilterで型指定
    var filters: [CIFilter & CustomFilterProtocol] = [
        OriginalFilter(),
        PastelLavenderFilter(),
        PastelLightBlueFilter(),
        PastelPinkFilter(),
        PastelRoseFilter(),
        PastelVioletFilter(),
        PastelYellowFilter()
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
        currentFilterIndex = (currentFilterIndex + 1) % filters.count
        print("Switched to next filter. currentFilterIndex:", currentFilterIndex)
        print("Current filter:", currentFilter)
    }
    
    // 前のフィルターに切り替え
    func switchToPreviousFilter() {
        currentFilterIndex = (currentFilterIndex - 1 + filters.count) % filters.count
        print("Switched to previous filter. currentFilterIndex:", currentFilterIndex)
        print("Current filter:", currentFilter)
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
        } catch {
            print("Error: \(error)")
        }
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
}

// 最新の写真サムネイルを扱うViewModel
final class PhotoViewModel: NSObject, PHPhotoLibraryChangeObserver {
    
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

// 撮影した写真を処理するクラス
class PhotoProcessor {

    // 画像の向きを修正
    private static func fixImageOrientation(_ image: UIImage) -> UIImage? {
        // すでに正しい向きならそのまま返す
        if image.imageOrientation == .up {
            return image
        }

        // 画像のコンテキストを作成
        guard let cgImage = image.cgImage else { return nil }
        let width = image.size.width
        let height = image.size.height
        var transform = CGAffineTransform.identity

        // 向きに応じてアフィン変換を設定
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height).rotated(by: -.pi / 2)
        case .up, .upMirrored:
            break
        @unknown default:
            return image
        }

        // ミラー処理（反転）
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }

        // コンテキストの作成
        guard let colorSpace = cgImage.colorSpace else { return nil }
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            return nil
        }

        context.concatenate(transform)

        // 描画範囲を設定し、画像を描画
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // 新しいCGImageを作成し、UIImageに変換
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
}
