
import CoreImage
import Metal

protocol CustomFilterProtocol: AnyObject {
    var inputImage: CIImage? { get set }
    var outputImage: CIImage? { get }
    var filterName: String { get }
}
