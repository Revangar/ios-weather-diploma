import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Weather", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        self.window = window
        let coordinator = AppCoordinator(window: window)
        self.coordinator = coordinator
        coordinator.start()
    }
}

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    init(window: UIWindow) { self.window = window }
    func start() {
        let loading = UIViewController()
        loading.view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        loading.view.addSubview(spinner)
        NSLayoutConstraint.activate([spinner.centerXAnchor.constraint(equalTo: loading.view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: loading.view.centerYAnchor)])
        spinner.startAnimating()
        window.rootViewController = loading
        window.tintColor = Palette.accent
        window.makeKeyAndVisible()
        Task {
            do {
                var defaults = UserDefaults.standard
                var storeURL: URL?
                var session = URLSession.shared
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                    let namespace = ProcessInfo.processInfo.environment["WEATHER_TEST_NAMESPACE"] ?? "default"
                    defaults = UserDefaults(suiteName: "WeatherUITests.\(namespace)")!
                    storeURL = NSPersistentContainerDirectory().appendingPathComponent("UITests-\(namespace).sqlite")
                    if ProcessInfo.processInfo.arguments.contains("--reset-test-state") {
                        defaults.removePersistentDomain(forName: "WeatherUITests.\(namespace)")
                        // Remove only this explicit test namespace, never the user's store.
                        for suffix in ["", "-wal", "-shm"] {
                            let url = URL(fileURLWithPath: storeURL!.path + suffix)
                            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                        }
                    }
                    if ProcessInfo.processInfo.arguments.contains("--fixture-network") { session = DebugNetwork.session() }
                }
                #endif
                let store = try await CoreDataStack.make(storeURL: storeURL)
                let repository = WeatherRepository(store: store, api: WeatherAPIClient(session: session))
                let root = WeatherRootViewController(repository: repository, defaults: defaults, geocoding: GeocodingService(session: session))
                let navigation = UINavigationController(rootViewController: root)
                navigation.navigationBar.prefersLargeTitles = false
                window.rootViewController = navigation
            } catch {
                spinner.stopAnimating()
                let alert = UIAlertController(title: "Хранилище недоступно", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in self?.start() })
                loading.present(alert, animated: true)
            }
        }
    }
    private func NSPersistentContainerDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
