
import CoreImage

class PastelLavenderFilter: CIFilter, CustomFilterProtocol {
    
    var filterName: String {
        return "Pastel Lavender"
    }
    
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Lavender Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }

        let filterColor = CIColor(red: 1.0, green: 0.66, blue: 1.0, alpha: 0.1)
        let colorFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: filterColor])
        
        guard let overlay = colorFilter?.outputImage?.cropped(to: inputImage.extent) else { return inputImage }
        
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
