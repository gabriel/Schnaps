import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published var error: String?
    var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    func refresh() { enabled = SMAppService.mainApp.status == .enabled }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            self.error = error.localizedDescription
            refresh()
        }
    }
}
