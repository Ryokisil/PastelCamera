
import SwiftUI

@main
struct CameraApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                CameraViewControllerRepresentable()
            }
        }
    }
}