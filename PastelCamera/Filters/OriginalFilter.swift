
import CoreImage

class OriginalFilter: CIFilter, CustomFilterProtocol {
    
    var filterName: String {
        return "Original"
    }
    
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Original Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        // 加工なし、そのまま返す
        return inputImage
    }
}
