
import UIKit

// PastelLavenderFilterクラス
class PastelLavenderFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズのラベンダー色のレイヤーを作成
        let filterColor = UIColor(red: 1.0, green: 0.66, blue: 1.0, alpha: 0.5) // パステルラベンダーカラー #FFA8FF
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // ラベンダーのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}
