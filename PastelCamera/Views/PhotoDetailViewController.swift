// 撮った写真を表示する画面

import UIKit
import Photos
import CoreImage
import Foundation
import Combine
import TOCropViewController

// CameraViewControllerDelegateの実装
class PhotoDetailViewController: UIViewController, PHPhotoLibraryChangeObserver {
    // PHPhotoLibraryChangeObserver プロトコルの必須メソッド
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = fetchResult else { return }
        guard let changes = changeInstance.changeDetails(for: fetchResult) else { return }

        if changes.insertedObjects.isEmpty == false {
            // 新しい写真が挿入された場合の処理
            print("New photo added")
            DispatchQueue.main.async {
                self.fetchPhotosFromCameraRoll()
            }
        } else if changes.removedObjects.isEmpty == false {
            // 写真が削除された場合の処理
            print("Photo removed")
        }
    }
    
    private var isTransformed = false                 // 編集中かどうかの状態管理プロパティ
    private var currentIndex: Int = 0                 // 現在表示中の画像のインデックス
    var originalImage: UIImage?                       // オリジナルの画像を保持するプロパティ
    var imageView: UIImageView!                       // 画像を表示するためのUIImageView
    var fetchResult: PHFetchResult<PHAsset>?          // カメラロールから取得したPHAssetのリスト
    var cameraViewController = CameraViewController() // ビューコントローラーのインスタンス
    var collectionView: UICollectionView!             // フィルターを表示するためのUICollectionView

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad: imageView is \(String(describing: imageView))")
        view.backgroundColor = .black
        fetchPhotosFromCameraRoll()
        setupUI()
        if let imageView = imageView {
            displayImage(at: currentIndex, in: imageView)
        } else {
            print("Error: imageView is nil in viewDidLoad")
        }
        originalImage = imageView.image
        
        // フォトライブラリの変更監視を開始
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        // メモリ解放時に監視を解除
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // UIを設定するメソッド
    private func setupUI() {
        // UIImageViewの設定
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        // スワイプジェスチャー右
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        
        // スワイプジェスチャー左
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        
        // 下スワイプで閉じるジェスチャー
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        
        // ゴミ箱アイコンの設定
        let trashButton = UIButton(type: .system)
        trashButton.setImage(UIImage(systemName: "trash"), for: .normal)
        trashButton.addTarget(self, action: #selector(didTapDeleteButton), for: .touchUpInside)
        view.addSubview(trashButton)
        
        // ゴミボタンのレイアウト設定
        trashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trashButton)
        NSLayoutConstraint.activate([
            trashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -340),
            trashButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -45),
            trashButton.widthAnchor.constraint(equalToConstant: 44),
            trashButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 編集ボタン
        let editButton = UIButton(type: .system)
        editButton.setTitle("トリミング", for: .normal)
        editButton.addTarget(self, action: #selector(didTapEditButton), for: .touchUpInside)
        editButton.frame = CGRect(x: 20, y: 50, width: 100, height: 40)
        view.addSubview(editButton)
       
    } // private func setupUI
    
    @objc private func didTapEditButton() {
        // TOCropViewControllerのインスタンスを作成
        guard let image = originalImage else { return }
        let cropViewController = TOCropViewController(image: image)
        cropViewController.delegate = self
        present(cropViewController, animated: true, completion: nil)
        provideHapticFeedback()
        showSuccessAlert(message: "画像を保存しました")
    }
    
    // 成功時のアラート
    private func showSuccessAlert(message: String) {
        print("showSuccessAlert called with message: \(message)")
        let alert = UIAlertController(title: "保存完了", message: "画像を保存しました", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true) {
            print("Alert presented successfully")
        }
    }

    // 失敗時のアラート
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // 少し振動するやつ　名前知らん
    func provideHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // カメラロールから写真を取得
    private func fetchPhotosFromCameraRoll() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.fetchResult = fetchResult

        if fetchResult.firstObject != nil {
            // 現在のインデックスが範囲外でないか確認
            if currentIndex >= fetchResult.count {
                currentIndex = 0
            }
            displayImage(at: currentIndex, in: imageView)
        } else {
            print("カメラロールに画像がありません")
        }
    }
    
    // 指定されたインデックスの写真を表示
    private func displayImage(at index: Int, in imageView: UIImageView?) {
        guard let fetchResult = fetchResult else {
            print("Error: fetchResult is nil")
            return
        }

        guard index < fetchResult.count else {
            print("Error: Index out of bounds")
            return
        }

        let asset = fetchResult.object(at: index)
        let imageManager = PHImageManager.default()
        let targetSize = PHImageManagerMaximumSize // 最大サイズで画像を取得
        let options = PHImageRequestOptions()
        options.isSynchronous = true

        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { (image, _) in
            if let image = image {
                imageView?.image = image
                self.originalImage = image // 必要に応じて保存
                print("Image successfully displayed")
            } else {
                print("Error: Failed to fetch image for asset")
            }
        }
    }
    
    // 左右スワイプジェスチャーのアクション
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard !isTransformed else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch gesture.direction {
            case .left:
                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                    self.animateTransition(to: self.currentIndex, direction: .left)
                    
                    if let asset = self.fetchResult?.object(at: self.currentIndex) {
                        self.requestOriginalImage(for: asset) { newImage in
                            if let newImage = newImage {
                                self.updateImageAndReloadFilters(with: newImage)
                            } else {
                                print("Failed to fetch the new image")
                            }
                        }
                    } else {
                        print("No asset found at index \(self.currentIndex)")
                    }
                }
            case .right:
                if self.currentIndex < (self.fetchResult?.count ?? 0) - 1 {
                    self.currentIndex += 1
                    self.animateTransition(to: self.currentIndex, direction: .right)
                    
                    if let asset = self.fetchResult?.object(at: self.currentIndex) {
                        self.requestOriginalImage(for: asset) { newImage in
                            if let newImage = newImage {
                                self.updateImageAndReloadFilters(with: newImage)
                            } else {
                                print("Failed to fetch the new image")
                            }
                        }
                    } else {
                        print("No asset found at index \(self.currentIndex)")
                    }
                }
            default:
                break
            }
        }
    }

    // PHAssetからオリジナル画質で画像を取得する関数　なんかこれがないと撮影時の画質のまま表示しない
    private func requestOriginalImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none  // リサイズなしでオリジナル画質を取得

        manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    // 左右swipeで写真切り替える時にアニメーションつける
    private func animateTransition(to index: Int, direction: UISwipeGestureRecognizer.Direction) {
        // アニメーションの設定
        let transitionOptions: UIView.AnimationOptions = (direction == .left) ? .transitionFlipFromRight : .transitionFlipFromLeft

        UIView.transition(with: imageView, duration: 0.3, options: [transitionOptions], animations: {
            self.displayImage(at: index, in: self.imageView)
        }, completion: nil)
    }
    
    // スワイプダウンジェスチャーのアクション
    @objc private func handleSwipeDown() {
        // 編集中の場合はジェスチャーを無効化
        guard !isTransformed else { return }
        dismiss(animated: true, completion: nil)
    }
    
    func updateImageAndReloadFilters(with newImage: UIImage) {
        // `originalImage`プロパティを新しい画像に設定
        self.originalImage = newImage
        
        // collectionViewがnilでないか確認してからリロード
        if let collectionView = self.collectionView {
            collectionView.reloadData()
        } else {
            print("Error: collectionView is nil")
        }
    }
    
    @objc private func didTapDeleteButton() {
        guard let fetchResult = fetchResult, currentIndex < fetchResult.count else {
            print("削除する写真が見つかりません")
            return
        }
        
        let assetToDelete = fetchResult.object(at: currentIndex)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSArray)
        }) { success, error in
            if success {
                DispatchQueue.main.async {
                    print("写真を削除しました")
                    self.animatePhotoDeletion {
                        self.updateFetchResultAfterDeletion()
                        if self.currentIndex >= (fetchResult.count - 1) {
                            self.currentIndex = max(0, fetchResult.count, -2)
                        }
                        self.updateDisplayedPhotoAfterDeletion()
                    }
                }
            } else if let error = error {
                print("写真の削除に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateFetchResultAfterDeletion() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] // 最新順にソート
        fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }

    func updateDisplayedPhotoAfterDeletion() {
        guard let fetchResult = fetchResult, fetchResult.count > 0 else {
            print("すべての写真が削除されました")
            return
        }

        // インデックスを適切に設定し、次に表示する写真を選択
        if currentIndex >= fetchResult.count {
            currentIndex = fetchResult.count - 1 // 現在のインデックスが範囲外の場合に修正
        }

        let latestAsset = fetchResult.object(at: currentIndex)
        displayPhoto(asset: latestAsset)
    }
    
    func displayPhoto(asset: PHAsset) {
        // 「写真がありません」ラベルがあれば削除
        imageView.viewWithTag(999)?.removeFromSuperview()

        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true

        imageManager.requestImage(for: asset, targetSize: imageView.bounds.size, contentMode: .aspectFill, options: requestOptions) { [weak self] image, _ in
            guard let self = self else { return }
            if let image = image {
                print("Image successfully fetched: \(image)")
                self.imageView.image = image
                print("ImageView.image is now set: \(self.imageView.image ?? UIImage())")
            } else {
                print("Failed to fetch image for asset")
            }
        }
    }
    
    func animatePhotoDeletion(completion: @escaping () -> Void) {
        // 最初のフェードアウトアニメーション
        UIView.animate(withDuration: 0.3, animations: {
            self.imageView.alpha = 0.0
        }, completion: { _ in
            // アニメーションが完了した後に完了クロージャーを呼び出す
            completion()

            // データの更新が完了した後に、次のフェードインアニメーションを行う
            UIView.animate(withDuration: 0.3, animations: {
                self.imageView.alpha = 1.0
            })
        })
    }

    private func handleAllPhotosDeleted() {
        // すべての写真が削除された場合の処理
        dismiss(animated: true)
    }
}

extension PhotoDetailViewController: TOCropViewControllerDelegate {
    
    // クロップが完了した時に呼ばれるメソッド
    func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        // クロップ後の画像を使用
        self.imageView.image = image
        self.imageView.image = cameraViewController .latestFilteredImage

        // カメラロールに保存
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveError), nil)

        cropViewController.dismiss(animated: true, completion: nil)
    }
    
    // クロップがキャンセルされた時に呼ばれるメソッド
    func cropViewControllerDidCancel(_ cropViewController: TOCropViewController) {
        cropViewController.dismiss(animated: true, completion: nil)
    }

    // 保存時のエラーハンドリング
    @objc func saveError(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("保存エラー: \(error.localizedDescription)")
        } else {
            print("画像がカメラロールに保存されました")
        }
    }
}
