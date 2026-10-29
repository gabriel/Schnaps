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
    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        channel = UpdateChannel.selected(
            saved: defaults.string(forKey: Self.preferenceKey),
            bundled: bundle.object(forInfoDictionaryKey: "SchnapsUpdateChannel") as? String)
        super.init()
    }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel.allowedSparkleChannels }
}
