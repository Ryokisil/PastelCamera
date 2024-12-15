
import Photos
import UIKit
import Combine

class PhotoDetailViewModel: NSObject {
    
    @Published var photos: [PHAsset] = [] // カメラロールの写真リスト
    var isFilterApplied: Bool = false // フィルター適用状態を管理
    var selectedImage: UIImage? // 保存された画像を保持するプロパティ
    var currentIndex: Int = 0
    var onFetchResultUpdate: ((PHAsset?) -> Void)?  // ViewControllerへ通知するクロージャ
    var fetchResult: PHFetchResult<PHAsset>? // PHFetchResultを保持
    private let imageManager = PHCachingImageManager()
    private var saveCompletionHandler: ((Result<Void, Error>) -> Void)?
    
    // フィルター適用後の写真を保存
    func editPhoto(asset: PHAsset, filter: CIFilter, completion: @escaping (Bool, Error?) -> Void) {
        print("Step 1: editPhoto 関数が呼ばれました")
        print("editPhoto 関数呼び出し時の asset: \(String(describing: asset))")
        print("editPhoto 関数呼び出し時の filter: \(String(describing: filter))")

        
        asset.requestContentEditingInput(with: nil) { contentEditingInput, _ in
            guard let input = contentEditingInput else {
                print("Step 2: contentEditingInput の取得に失敗しました")
                completion(false, nil)
                return
            }
            
            print("Step 2: contentEditingInput を取得しました")

            // フルサイズの画像URLにアクセス
            guard let url = input.fullSizeImageURL,
                  let ciImage = CIImage(contentsOf: url) else {
                print("Step 3: フルサイズの画像の URL 取得または CIImage の作成に失敗しました")
                completion(false, nil)
                return
            }
            
            print("Step 3: フルサイズの画像を取得し CIImage を作成しました")

            // フィルターの適用
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            guard let outputImage = filter.outputImage else {
                print("Step 4: フィルター適用後の画像の生成に失敗しました")
                completion(false, nil)
                return
            }
            
            print("Step 4: フィルター適用後の画像の生成に成功しました")

            // 編集した画像を一時ファイルに保存
            let context = CIContext()
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            do {
                try context.writeJPEGRepresentation(of: outputImage, to: outputURL, colorSpace: ciImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!)
                print("Step 5: 編集した画像を一時ファイルに保存しました - 保存先: \(outputURL.path)")
            } catch {
                print("Step 5: 編集した画像の一時ファイル保存に失敗しました - エラー: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // PHContentEditingOutputの準備
            let contentEditingOutput = PHContentEditingOutput(contentEditingInput: input)
            
            // 保存先のURLをrenderedContentURLから取得
            let renderedContentURL = contentEditingOutput.renderedContentURL
            do {
                try FileManager.default.copyItem(at: outputURL, to: renderedContentURL)
                print("Step 6: 一時ファイルから renderedContentURL へのコピーに成功しました")
            } catch {
                print("Step 6: 一時ファイルから renderedContentURL へのコピーに失敗しました - エラー: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // 編集情報を保存
            contentEditingOutput.adjustmentData = PHAdjustmentData(formatIdentifier: "com.PastelCamera", formatVersion: "1.0", data: Data())
            print("Step 7: 編集情報の adjustmentData を設定しました")

            // 編集をPhotosライブラリに保存
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest(for: asset)
                request.contentEditingOutput = contentEditingOutput
            }) { success, error in
                if let error = error {
                    print("Step 8: Photosライブラリへの保存中にエラーが発生しました - エラー: \(error.localizedDescription)")
                } else if success {
                    print("Step 8: Photosライブラリへの保存に成功しました")
                }
                completion(success, error)
            }
        }
    }
    
    func saveEditedImage(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let imageToSave = selectedImage else {
            let error = NSError(domain: "PhotoDetailViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "加工した画像がありません。"])
            completion(.failure(error))
            return
        }

        // カメラロールに保存
        UIImageWriteToSavedPhotosAlbum(imageToSave, self, #selector(saveCompletion(_:didFinishSavingWithError:contextInfo:)), nil)
        
        // Completionクロージャを保存処理完了後に呼び出すために参照を保持する
        self.saveCompletionHandler = completion
    }

    // 保存完了のセレクタメソッド
    @objc private func saveCompletion(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        if let error = error {
            print("Image save failed: \(error.localizedDescription)")
            self.saveCompletionHandler?(.failure(error)) // クロージャにエラーを渡す
        } else {
            print("Image saved successfully")
            self.saveCompletionHandler?(.success(())) // クロージャに成功を通知
        }
    }
    
    // 保存後にリロードして新しい写真を反映
    func reloadUIAfterSave(completion: @escaping (PHAsset?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // デバッグログを追加
        print("Updated fetchResult count: \(fetchResult?.count ?? 0)")

        // 最新の写真を取得
        let latestAsset = fetchResult?.firstObject
        if let latestAsset = latestAsset {
            print("Latest photo asset fetched successfully")
        } else {
            print("Failed to fetch the latest photo asset")
        }
        completion(latestAsset)
    }
}

