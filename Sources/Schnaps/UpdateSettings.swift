import Combine
import Sparkle
import MeasurementCore

@MainActor
final class UpdateSettings: ObservableObject {
    private let updater: SPUUpdater
    private let channels: UpdateChannelSettings
    @Published var channel: UpdateChannel {
        didSet {
            guard channels.channel != channel else { return }
            channels.channel = channel
            updater.resetUpdateCycleAfterShortDelay()
        }
    }
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            if updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates {
                updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
        }
    }
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            if updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates {
                updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            }
        }
    }

    init(updater: SPUUpdater, channels: UpdateChannelSettings) {
        self.updater = updater
        self.channels = channels
        channel = channels.channel
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        // Observe Sparkle's own preferences, including changes made in its update dialogs.
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.allowsAutomaticUpdates).assign(to: &$allowsAutomaticUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloadsUpdates)
    }

    func checkForUpdates() { updater.checkForUpdates() }
}
