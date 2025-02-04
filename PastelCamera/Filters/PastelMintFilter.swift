
import CoreImage

class PastelMintFilter: CIFilter, CustomFilterProtocol {
    
    var filterName: String {
        return "PastelMintFilter"
    }
    
    @objc dynamic var inputImage: CIImage?
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Mint Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        
        // パステルミントカラー（#B2FFB2）
        let filterColor = CIColor(red: 0.698, green: 1.0, blue: 0.698, alpha: 0.1)
        let colorFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: filterColor])
        
        guard let overlay = colorFilter?.outputImage?.cropped(to: inputImage.extent) else {
            return inputImage
        }
        
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
