
import CoreImage

class PastelVioletFilter: CIFilter, CustomFilterProtocol {
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Violet Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }

        // パステルバイオレットカラー (#D6ADFF)
        let filterColor = CIColor(red: 0.84, green: 0.68, blue: 1.0, alpha: 0.1)
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
}
