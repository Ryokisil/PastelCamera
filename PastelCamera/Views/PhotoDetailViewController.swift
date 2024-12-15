// 撮った写真を表示する画面

import UIKit
import Photos
import CoreImage
import Foundation
import Combine

// CameraViewControllerDelegateの実装
class PhotoDetailViewController: UIViewController, PHPhotoLibraryChangeObserver {
    // PHPhotoLibraryChangeObserver プロトコルの必須メソッド
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("カメラロールが更新されました")
            self.fetchPhotosFromCameraRoll()
        }
    }
    
    private var isTransformed = false                 // 編集中かどうかの状態管理プロパティ
    private var doneButton = UIButton()
    private var currentIndex: Int = 0                 // 現在表示中の画像のインデックス
    var image: UIImage?                               // 編集された画像を保持するプロパティ
    var originalImage: UIImage?                       // オリジナルの画像を保持するプロパティ
    var imageView: UIImageView!                       // 画像を表示するためのUIImageView
    var fetchResult: PHFetchResult<PHAsset>?          // カメラロールから取得したPHAssetのリスト
    var photoDetailViewModel = PhotoDetailViewModel() // ビューモデルのインスタンス
    var collectionView: UICollectionView!             // フィルターを表示するためのUICollectionView
    var appliedFilters: [String] = []                 // 適用されたフィルターのリスト
    var filters: [ImageFilter] = [
        OriginalFilter(),
        PastelLightBlueFilter(),
        PastelLavenderFilter(),
        PastelPinkFilter(),
        PastelRoseFilter(),
        PastelVioletFilter(),
        PastelYellowFilter()
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad: imageView is \(String(describing: imageView))")
        view.backgroundColor = .black
        fetchPhotosFromCameraRoll()
        setupUI()  // UI セットアップを呼び出す
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
        
        // スワイプジェスチャーの追加
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        view.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        view.addGestureRecognizer(rightSwipe)
        
        // 下スワイプで閉じるジェスチャー
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
        
        // フィルターアイコンの設定
        let filterButton = UIButton(type: .system)
        filterButton.setImage(UIImage(systemName: "paintbrush"), for: .normal)
        filterButton.tintColor = .white
        filterButton.addTarget(self, action: #selector(didTapFilterButton), for: .touchUpInside)
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterButton)
        
        // フィルターアイコンのレイアウト
        NSLayoutConstraint.activate([
            filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            filterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // ゴミ箱アイコンの設定
        let trashButton = UIButton(type: .system)
        trashButton.setImage(UIImage(systemName: "trash"), for: .normal)
        trashButton.addTarget(self, action: #selector(deletePhoto), for: .touchUpInside)
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
        
        // Doneボタンの設定
        doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.systemBlue, for: .normal) // テキスト色
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold) // フォント
        doneButton.addTarget(self, action: #selector(didTapDoneButton), for: .touchUpInside)
        doneButton.isHidden = true
        view.addSubview(doneButton)

        // Doneボタンのレイアウト設定
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), // 画面右端から16pt
            doneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), // 画面上端から16pt
            doneButton.widthAnchor.constraint(equalToConstant: 60), // ボタン幅
            doneButton.heightAnchor.constraint(equalToConstant: 44) // ボタン高さ
        ])
    }
    
    // フィルターコレクションビューの設定
    private func setupFilterCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 60, height: 60)
        layout.minimumLineSpacing = 10
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FilterCollectionViewCell.self, forCellWithReuseIdentifier: "FilterCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isHidden = true
        view.addSubview(collectionView)

        // UICollectionViewのレイアウト
        NSLayoutConstraint.activate([
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        collectionView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 290),
        collectionView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    // doneボタンっタップ時の処理
    @objc private func didTapDoneButton() {
        // ビューモデルの保存処理を呼び出し
        print("Doneボタンがタップされました") // このログが出力されるか確認
        photoDetailViewModel.saveEditedImage { [weak self] result in
            print("画像保存処理の結果: \(result)") // 保存処理の結果をログ出力
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("成功アラートを表示します") // ここが呼ばれているか確認
                    self?.showSuccessAlert(message: "画像が保存されました。")
                    self?.resetToOriginalPosition() // 元の位置に戻す処理
                    
                    // カメラロール更新確認用のデバッグログ
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 1
                    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                    
                    if let latestAsset = fetchResult.firstObject {
                        print("Latest photo fetched: \(latestAsset)")
                        print("Asset creation date: \(latestAsset.creationDate ?? Date())")
                    } else {
                        print("Failed to fetch the latest photo from the camera roll.")
                    }
                    
                case .failure(let error):
                    print("Calling showErrorAlert") // エラー処理のログ
                    self?.showErrorAlert(message: "保存に失敗しました: \(error.localizedDescription)")
                }
            }
        }
        provideHapticFeedback()
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
    
    private func resetToOriginalPosition() {
        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = .identity // 元の位置に戻す
            self.doneButton.isHidden = true // doneButton を非表示
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.toggleFilterCollectionView() // フィルターコレクションを非表示に切り替え
            self.isTransformed = false // 状態をリセット
            
            print("ImageView isHidden: \(self.imageView.isHidden)")
            print("ImageView alpha: \(self.imageView.alpha)")

            // リロード処理を実行
            self.photoDetailViewModel.reloadUIAfterSave { latestAsset in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard let latestAsset = latestAsset else {
                        print("新しい写真が見つかりませんでした")
                        return
                    }
                    self.displayPhoto(asset: latestAsset) // 新しい写真を表示
                }
            }
        }
    }
    
    // 少し振動するやつ　名前知らん
    func provideHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // フィルターボタンタップ時に写真を少し上に移動させてからフィルターコレクションビューを表示する
    @objc private func didTapFilterButton() {
        UIView.animate(withDuration: 0.3) {
            if self.isTransformed {
                // 元の位置に戻す
                self.imageView.transform = .identity
                self.doneButton.isHidden = true
            } else {
                // 上に移動する
                self.imageView.transform = CGAffineTransform(translationX: 0, y: -50)
                self.doneButton.isHidden = false
            }
        } completion: { _ in
            // アニメーション完了後にコレクションビューを表示する
            self.toggleFilterCollectionView()
            self.isTransformed.toggle()
        }
    }
    
    private func toggleFilterCollectionView() {
        if collectionView == nil {
            setupFilterCollectionView()
        }
        UIView.animate(withDuration: 0.3) {
            self.collectionView.isHidden.toggle()
        }
    }
    
    // カメラロールから写真を取得
    private func fetchPhotosFromCameraRoll() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.fetchResult = fetchResult

        if let firstAsset = fetchResult.firstObject {
            self.currentIndex = 0 // 最新の写真を表示するためのインデックスを設定
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

    // 選択されたフィルターを適用
    func applySelectedFilter(_ filter: ImageFilter) {
        guard let currentImageView = imageView else { return }
        
        // PHAssetからオリジナル画質の画像を取得
        if let asset = fetchResult?[currentIndex] {
            requestOriginalImage(for: asset) { [weak self] originalImage in
                guard let self = self, let originalImage = originalImage else { return }
                
                // フィルターをオリジナル画質の画像に適用
                let filteredImage = filter.apply(to: originalImage)
                
                // 画質を保持したフィルター適用後の画像を表示
                DispatchQueue.main.async {
                    // 保存用プロパティに加工後の画像を設定
                    self.photoDetailViewModel.selectedImage = filteredImage
                    // UIに反映
                    currentImageView.image = filteredImage
                }
            }
        }
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
    
    @objc private func deletePhoto() {
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

// データソースとデリゲートを追加するための拡張
extension PhotoDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filters.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as! FilterCollectionViewCell
        let filter = filters[indexPath.item]  // 適用するフィルターを取得
        
        // 非同期でフィルターを適用
        DispatchQueue.global(qos: .userInitiated).async {
            let filteredImage = filter.apply(to: self.originalImage ?? UIImage())  // フィルター適用処理
            
            // メインスレッドでUI更新
            DispatchQueue.main.async {
                // セルがまだ同じインデックスか確認（セルの再利用で画像が他のセルに反映されないようにする）
                if let currentCell = collectionView.cellForItem(at: indexPath) as? FilterCollectionViewCell {
                    currentCell.imageView.image = filteredImage
                }
            }
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedFilter = filters[indexPath.item]
        applySelectedFilter(selectedFilter)
    }
}

// FilterCollectionViewCellの定義
class FilterCollectionViewCell: UICollectionViewCell {
    var imageView: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImageView()
    }

    private func setupImageView() {
        imageView = UIImageView(frame: contentView.bounds)
        imageView.contentMode = .scaleAspectFill // ここでスケーリングモードを調整
        imageView.clipsToBounds = true // 画像がセルの枠からはみ出さないようにする
        contentView.addSubview(imageView)
    }
}
