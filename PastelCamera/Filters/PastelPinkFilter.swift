
import CoreImage

class PastelPinkFilter: CIFilter, CustomFilterProtocol {
    @objc dynamic var inputImage: CIImage?

    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Pastel Pink Filter",
            kCIInputImageKey: [
                kCIAttributeClass: "CIImage",
                kCIAttributeDisplayName: "Input Image",
                kCIAttributeType: kCIAttributeTypeImage
            ]
        ]
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }

        // ピンク色のオーバーレイを作成
        let filterColor = CIColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 0.1)
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
}
