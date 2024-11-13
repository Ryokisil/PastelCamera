// 撮った写真を表示する画面

import UIKit
import Photos
import CoreImage
import Foundation

// CameraViewControllerDelegateの実装
class PhotoDetailViewController: UIViewController {
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var isTransformed = false
    var image: UIImage?                             // 編集された画像を保持するプロパティ
    var originalImage: UIImage?                     // オリジナルの画像を保持するプロパティ
    var imageView: UIImageView!                     // 画像を表示するためのUIImageView
    var fetchResult: PHFetchResult<PHAsset>!        // カメラロールから取得したPHAssetのリスト
    var currentIndex: Int = 0                       // 現在表示中の画像のインデックス
    var photoDetailViewModel: PhotoDetailViewModel! // ビューモデルのインスタンス
    var collectionView: UICollectionView!           // フィルターを表示するためのUICollectionView
    var appliedFilters: [String] = []               // 適用されたフィルターのリスト
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
        view.backgroundColor = .black
        fetchPhotosFromCameraRoll()
        setupUI()  // UI セットアップを呼び出す
        displayImage(at: currentIndex, in: imageView)
        originalImage = imageView.image
    }
    
    // UIを設定するメソッド
    private func setupUI() {
        // UIImageViewの設定
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        // 閉じるボタン
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // 閉じるボタンのレイアウト
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
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
    }
    
    // フィルタービューを表示するトグル
    @objc private func didTapFilterButton() {
        UIView.animate(withDuration: 0.3) {
            if self.isTransformed {
                // 元の位置に戻す
                self.imageView.transform = .identity
            } else {
                // 上に移動する
                self.imageView.transform = CGAffineTransform(translationX: 0, y: -50)
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
    
    // カメラロールから写真を取得
    private func fetchPhotosFromCameraRoll() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }
    
    // 指定されたインデックスの写真を表示
    private func displayImage(at index: Int, in imageView: UIImageView) {
        let asset = fetchResult.object(at: index)
        let imageManager = PHImageManager.default()
        let targetSize = PHImageManagerMaximumSize
        let options = PHImageRequestOptions()
        options.isSynchronous = true

        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { (image, _) in
            imageView.image = image
            self.originalImage = image
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
                    
                    let asset = self.fetchResult[self.currentIndex]
                    self.requestOriginalImage(for: asset) { newImage in
                        self.updateImageAndReloadFilters(with: newImage!)
                    }
                }
            case .right:
                if self.currentIndex < self.fetchResult.count - 1 {
                    self.currentIndex += 1
                    self.animateTransition(to: self.currentIndex, direction: .right)
                    
                    let asset = self.fetchResult[self.currentIndex]
                    self.requestOriginalImage(for: asset) { newImage in
                        self.updateImageAndReloadFilters(with: newImage!)
                    }
                }
            default:
                break
            }
        }
    }

    // PHAssetからオリジナル画質で画像を取得する関数
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

    private func animateTransition(to index: Int, direction: UISwipeGestureRecognizer.Direction) {
        // アニメーションの設定
        let transitionOptions: UIView.AnimationOptions = (direction == .left) ? .transitionFlipFromRight : .transitionFlipFromLeft

        UIView.transition(with: imageView, duration: 0.3, options: [transitionOptions], animations: {
            self.displayImage(at: index, in: self.imageView)
        }, completion: nil)
    }
    
    // デリゲートメソッド：サムネイルがタップされたときに呼ばれる
    func didTapThumbnail(with image: UIImage) {
        self.image = image
    }
    
    // 閉じるボタンが押された時の動作
    @objc private func didTapCloseButton() {
        guard imageView.image != nil else {
            dismiss(animated: true, completion: nil)
            return
        }

        let asset = fetchResult.object(at: currentIndex)
        
        // フィルター名に応じたフィルターのインスタンスを取得する
        if let selectedFilterName = appliedFilters.last,
           let filter = CIFilter(name: selectedFilterName) {
            // フィルターを適用して編集を保存
            photoDetailViewModel.editPhoto(asset: asset, filter: filter) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        let alert = UIAlertController(title: "保存完了", message: "画像がカメラロールに保存されました", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self?.dismiss(animated: true, completion: nil)
                        })
                        self?.present(alert, animated: true)
                    } else if let error = error {
                        let alert = UIAlertController(title: "エラー", message: "画像の保存に失敗しました: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(alert, animated: true)
                    }
                }
            }
        } else {
            // フィルターが適用されていない場合、保存せずに閉じる
            dismiss(animated: true, completion: nil)
        }
    }

    // 保存完了時のコールバック
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
       if let error = error {
           // エラーが発生した場合の処理
           let alert = UIAlertController(title: "エラー", message: "画像の保存に失敗しました: \(error.localizedDescription)", preferredStyle: .alert)
           alert.addAction(UIAlertAction(title: "OK", style: .default))
           present(alert, animated: true)
       } else {
           // 保存が成功した場合の処理
           let alert = UIAlertController(title: "保存完了", message: "画像がカメラロールに保存されました", preferredStyle: .alert)
           alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
               self.dismiss(animated: true, completion: nil)
           })
           present(alert, animated: true)
       }
   }
    
    // スワイプダウンジェスチャーのアクション
    @objc private func handleSwipeDown() {
        // 編集中の場合はジェスチャーを無効化
        guard !isTransformed else { return }
        dismiss(animated: true, completion: nil)
    }
    
    // フィルターを適用
    func applyFilterAsync(_ filterName: String, to image: UIImage?, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = image, let ciImage = CIImage(image: image) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let filter = CIFilter(name: filterName)
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            guard let outputImage = filter?.outputImage else {
                DispatchQueue.main.async {
                    print("フィルターの適用に失敗しました: \(filterName)")
                    completion(nil)
                }
                return
            }
            
            let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                let filteredImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    completion(filteredImage)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
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
