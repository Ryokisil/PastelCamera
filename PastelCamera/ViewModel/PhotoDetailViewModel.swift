
import Combine
import Photos
import UIKit

class PhotoDetailViewModel: NSObject, PHPhotoLibraryChangeObserver {
    @Published var currentImage: UIImage?
    @Published var isLibraryEmpty: Bool = false
    
    private var fetchResult: PHFetchResult<PHAsset>?
    private var currentIndex: Int = 0
    private let imageManager = PHImageManager.default()
    private let fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }()
    
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        fetchPhotos()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func fetchPhotos() {
        fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        if let fetchResult = fetchResult, fetchResult.count > 0 {
            isLibraryEmpty = false
            updateCurrentImage()
        } else {
            isLibraryEmpty = true
        }
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = fetchResult else { return }
        guard let changes = changeInstance.changeDetails(for: fetchResult) else { return }
        
        if !changes.removedObjects.isEmpty {
            // 写真削除後の処理
            fetchPhotos()
        }
    }
    
    func deleteCurrentPhoto() {
        guard let fetchResult = fetchResult, currentIndex < fetchResult.count else { return }
        
        let assetToDelete = fetchResult.object(at: currentIndex)
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSArray)
        }) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.fetchPhotos()
                }
            } else if let error = error {
                print("写真の削除に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    func nextImage() {
        guard let fetchResult = fetchResult, currentIndex < fetchResult.count - 1 else { return }
        currentIndex += 1
        updateCurrentImage()
    }
    
    func previousImage() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        updateCurrentImage()
    }
    
    private func updateCurrentImage() {
        guard let fetchResult = fetchResult, currentIndex < fetchResult.count else { return }
        let asset = fetchResult.object(at: currentIndex)
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            self?.currentImage = image
        }
    }
}
