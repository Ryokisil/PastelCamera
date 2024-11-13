
import UIKit

// ImageFilterプロトコル
protocol ImageFilter {
    func apply(to image: UIImage) -> UIImage
}

// PastelPinkFilterクラス
class PastelPinkFilter: ImageFilter {
    func apply(to image: UIImage) -> UIImage {
        // 画像サイズと同じサイズのピンク色のレイヤーを作成
        let filterColor = UIColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 0.5) // パステルピンクカラー
        let rect = CGRect(origin: .zero, size: image.size)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: rect)
        
        // ピンクのオーバーレイを重ねる
        filterColor.setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        let filteredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return filteredImage ?? image
    }
}




