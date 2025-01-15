
import CoreImage

class PastelLightBlueFilter: CIFilter, CustomFilterProtocol {
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Light Blue Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }

        // パステルライトブルーのオーバーレイ作成 (#B2B2FF)
        let filterColor = CIColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 0.1)
        let colorFilter = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: filterColor])

        // オーバーレイ画像を元画像に合成
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
