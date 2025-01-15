
import CoreImage

protocol CustomFilterProtocol: AnyObject {
    var inputImage: CIImage? { get set }
    var outputImage: CIImage? { get }
}
