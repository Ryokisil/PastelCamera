
import CoreImage

class PastelRoseFilter: CIFilter, CustomFilterProtocol {
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Rose Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }

        // パステルローズカラー（#FFA8D3）
        let filterColor = CIColor(red: 1.0, green: 0.66, blue: 0.83, alpha: 0.1)
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
