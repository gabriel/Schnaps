import Combine
import Foundation
import MeasurementCore
import Sparkle

@MainActor
final class UpdateChannelSettings: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let preferenceKey = "updateChannel"
    private let defaults: UserDefaults
    @Published var channel: UpdateChannel {
        didSet { defaults.set(channel.rawValue, forKey: Self.preferenceKey) }
    }
    init(
        defaults: UserDefaults = .standard,
        bundledChannel: String? = Bundle.main.object(forInfoDictionaryKey: "SchnapsUpdateChannel") as? String
    ) {
        self.defaults = defaults
        channel = UpdateChannel.selected(
            saved: defaults.string(forKey: Self.preferenceKey),
            bundled: bundledChannel)
        super.init()
        // A beta's default opt-in must survive its next stable-channel update.
        defaults.set(channel.rawValue, forKey: Self.preferenceKey)
    }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel.allowedSparkleChannels }
}
