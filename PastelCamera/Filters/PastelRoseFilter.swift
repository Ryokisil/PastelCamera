
import UIKit

// PastelRoseFilterクラス
class PastelRoseFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズのローズ色のレイヤーを作成
        let filterColor = UIColor(red: 1.0, green: 0.66, blue: 0.83, alpha: 0.5) // パステルローズカラー #FFA8D3
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // ローズのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}
