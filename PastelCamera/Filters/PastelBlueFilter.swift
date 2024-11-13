
import UIKit

// PastelLightBlueFilterクラス
class PastelLightBlueFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズのライトブルー色のレイヤーを作成
        let filterColor = UIColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 0.5) // パステルライトブルーカラー #B2B2FF
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // ライトブルーのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}

