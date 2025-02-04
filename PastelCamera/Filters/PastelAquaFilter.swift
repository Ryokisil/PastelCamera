
import CoreImage

class PastelAquaFilter: CIFilter, CustomFilterProtocol {
    
    var filterName: String {
        return "PastelAquaFilter"
    }
    
    @objc dynamic var inputImage: CIImage?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Aqua Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        // アクアブルーのオーバーレイを作成
        let filterColor = CIColor(red: 0.7, green: 1.0, blue: 1.0, alpha: 0.1)
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
