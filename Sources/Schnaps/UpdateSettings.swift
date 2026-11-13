import Foundation
import Combine
import Sparkle
import MeasurementCore

enum ReleaseUpdates {
    static let enabled = supports(
        configuration: Bundle.main.object(forInfoDictionaryKey: "SchnapsBuildConfiguration") as? String,
        bundleIdentifier: Bundle.main.bundleIdentifier)

    static func supports(configuration: String?, bundleIdentifier: String?) -> Bool {
        configuration == "release" && bundleIdentifier == "com.gabrielhandford.Schnap"
    }
}

@MainActor
final class UpdateSettings: ObservableObject {
    let supportsUpdates = ReleaseUpdates.enabled
    private let updater: SPUUpdater
    private let channels: UpdateChannelSettings
    @Published var channel: UpdateChannel {
        didSet {
            guard channels.channel != channel else { return }
            channels.channel = channel
            if supportsUpdates { updater.resetUpdateCycleAfterShortDelay() }
        }
    }
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            if supportsUpdates && updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates {
                updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
        }
    }
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            if supportsUpdates && updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates {
                updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            }
        }
    }

    init(updater: SPUUpdater, channels: UpdateChannelSettings) {
        self.updater = updater
        self.channels = channels
        channel = channels.channel
        automaticallyChecksForUpdates = supportsUpdates && updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = supportsUpdates && updater.automaticallyDownloadsUpdates
        guard supportsUpdates else { return }
        // Observe Sparkle's own preferences, including changes made in its update dialogs.
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.allowsAutomaticUpdates).assign(to: &$allowsAutomaticUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloadsUpdates)
    }

    func checkForUpdates() {
        guard supportsUpdates else { return }
        updater.checkForUpdates()
    }
}
