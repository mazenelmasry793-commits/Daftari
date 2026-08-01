import Flutter
import UIKit

final class SceneDelegate: FlutterSceneDelegate {
  private var nativeIntegrationCoordinator: NativeIntegrationCoordinator?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    DispatchQueue.main.async { [weak self] in
      guard let self,
            let flutterViewController = self.window?.rootViewController as? FlutterViewController else {
        return
      }
      let coordinator = NativeIntegrationCoordinator(rootViewController: flutterViewController)
      coordinator.start()
      self.nativeIntegrationCoordinator = coordinator
    }
  }
}
