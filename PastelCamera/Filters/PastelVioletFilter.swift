
import UIKit

// PastelVioletFilterクラス
class PastelVioletFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズのバイオレット色のレイヤーを作成
        let filterColor = UIColor(red: 0.84, green: 0.68, blue: 1.0, alpha: 0.5) // パステルバイオレットカラー #D6ADFF
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // バイオレットのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}
