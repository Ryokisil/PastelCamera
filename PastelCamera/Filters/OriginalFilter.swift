
import UIKit

// 加工なしのオリジナルフィルター
class OriginalFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 元の画像をそのまま返す
        return image
    }
}
