
import CoreImage

class PastelLilacFilter: CIFilter, CustomFilterProtocol {
    
    var filterName: String {
        return "PastelLilacFilter"
    }
    
    @objc dynamic var inputImage: CIImage?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Lilac Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        // ライラックのオーバーレイを作成
        let filterColor = CIColor(red: 0.9, green: 0.7, blue: 1.0, alpha: 0.2)
        let colorFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: filterColor])
        
        guard let overlay = colorFilter?.outputImage?.cropped(to: inputImage.extent) else {
            return inputImage
        }
        
        // オーバーレイと元の画像をブレンド
        let blendFilter = CIFilter(name: "CISourceOverCompositing", parameters: [
            kCIInputImageKey: overlay,
            kCIInputBackgroundImageKey: inputImage
        ])
        return blendFilter?.outputImage
    }
    
    deinit {
        //print("\(filterName) が解放されました")
    }
}
