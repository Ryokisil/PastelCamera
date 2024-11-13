
import Photos
import UIKit

class PhotoDetailViewModel {

    // フィルター適用後の写真を保存
    func editPhoto(asset: PHAsset, filter: CIFilter, completion: @escaping (Bool, Error?) -> Void) {
        asset.requestContentEditingInput(with: nil) { contentEditingInput, _ in
            guard let input = contentEditingInput else {
                completion(false, nil)
                return
            }
            
            // フルサイズの画像URLにアクセス
            guard let url = input.fullSizeImageURL,
                  let ciImage = CIImage(contentsOf: url) else {
                completion(false, nil)
                return
            }
            
            // フィルターの適用
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            guard let outputImage = filter.outputImage else {
                completion(false, nil)
                return
            }
            
            // 編集した画像を一時ファイルに保存
            let context = CIContext()
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
            do {
                try context.writeJPEGRepresentation(of: outputImage, to: outputURL, colorSpace: ciImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!)
            } catch {
                completion(false, error)
                return
            }
            
            // PHContentEditingOutputの準備（renderedContentURLの設定を削除）
            let contentEditingOutput = PHContentEditingOutput(contentEditingInput: input)
            contentEditingOutput.adjustmentData = PHAdjustmentData(formatIdentifier: "com.PastelCameraApp.customfilter", formatVersion: "1.0", data: Data())
            
            // 編集をPhotosライブラリに保存
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest(for: asset)
                request.contentEditingOutput = contentEditingOutput
            }, completionHandler: completion)
        }
    }
}

