import Foundation

/// One anonymous event per app process; reopening windows never creates another event.
@MainActor
final class SchnapsLaunchReporter {
    private let session: URLSession
    private let endpoint: URL
    private let launchID: UUID
    private let installationID: UUID
    private let version: String
    private let build: String
    private let defaults: UserDefaults
    private var task: URLSessionDataTask?
    private var hasStarted = false

    init(
        session: URLSession? = nil,
        endpoint: URL = URL(string: "https://getschnaps.com/api/app-starts")!,
        launchID: UUID = UUID(),
        defaults: UserDefaults = .standard,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
        build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        self.session = session ?? URLSession(configuration: configuration)
        self.endpoint = endpoint
        self.launchID = launchID
        self.version = version
        self.build = build
        self.defaults = defaults
        // This random identifier belongs only to Schnaps's preferences domain. Never
        // reuse licensing identifiers, browser identities, hardware IDs, or Keychain.
        let key = "SchnapsAnalyticsInstallationID"
        if let stored = defaults.string(forKey: key), let id = UUID(uuidString: stored) {
            installationID = id
        } else {
            let id = UUID()
            defaults.set(id.uuidString, forKey: key)
            installationID = id
        }
    }

    func start(runtime: String) {
        guard !hasStarted else { return }
        hasStarted = true
        guard runtime == "release", !defaults.bool(forKey: "SchnapsAnalyticsExcluded") else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("macos-app", forHTTPHeaderField: "X-Schnaps-Client")
        request.httpBody = try? JSONEncoder().encode(Event(launchID: launchID.uuidString, runtime: runtime, version: version, installationID: installationID.uuidString, build: build))
        task = session.dataTask(with: request) { _, response, error in
            if error != nil || (response as? HTTPURLResponse)?.statusCode != 204 {
                NSLog("Schnaps launch statistics could not be recorded.")
            }
        }
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private struct Event: Encodable {
        let launchID: String
        let runtime: String
        let version: String
        let installationID: String
        let build: String
    }
}
