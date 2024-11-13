
import UIKit

// PastelYellowFilterクラス
class PastelYellowFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズの黄色のレイヤーを作成
        let filterColor = UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 0.5) // パステルイエローカラー
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // イエローのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}

