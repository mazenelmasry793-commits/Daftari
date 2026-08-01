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
      guard let self else { return }
      let flutterViewController: FlutterViewController
      if let directFlutter = self.window?.rootViewController as? FlutterViewController {
        flutterViewController = directFlutter
      } else if let navigationController = self.window?.rootViewController as? UINavigationController,
                let embeddedFlutter = navigationController.viewControllers.first as? FlutterViewController {
        flutterViewController = embeddedFlutter
      } else {
        return
      }
      let navigationController: UINavigationController
      if let existing = flutterViewController.navigationController {
        navigationController = existing
      } else {
        // Flutter's storyboard controller starts as the window root. Detach it
        // before making it the child of the canonical native navigation stack.
        self.window?.rootViewController = nil
        navigationController = UINavigationController(rootViewController: flutterViewController)
        self.window?.rootViewController = navigationController
        self.window?.makeKeyAndVisible()
      }
      flutterViewController.edgesForExtendedLayout = [.bottom]
      flutterViewController.view.backgroundColor = .systemBackground
      navigationController.navigationBar.prefersLargeTitles = true
      let coordinator = NativeIntegrationCoordinator(rootViewController: flutterViewController)
      coordinator.start()
      self.nativeIntegrationCoordinator = coordinator
    }
  }
}
