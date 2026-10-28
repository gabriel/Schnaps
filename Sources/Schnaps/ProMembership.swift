import AppKit
import Combine
import MeasurementCore
import Security

@MainActor
final class ProMembership: ObservableObject {
    @Published private(set) var tier: ProTier?
    @Published private(set) var isRestoring = false
    @Published private(set) var message: String?
    let catalog: ProCatalog?

    private struct Membership: Codable {
        let tier: ProTier
        let key: String
        let storeID: Int
        let productID: Int
    }
    private let keychain: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.gabrielhandford.Schnap.pro",
        kSecAttrAccount as String: "membership"
    ]

    init() {
        catalog = Bundle.main.url(forResource: "Pro", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(ProCatalog.self, from: $0) }
        var query = keychain
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let saved = try? JSONDecoder().decode(Membership.self, from: data),
           let catalog, catalog.isConfigured,
           saved.storeID == catalog.storeID, saved.productID == catalog.productID {
            tier = saved.tier
        }
    }

    func buy(_ tier: ProTier) {
        guard let catalog, catalog.isConfigured, let offer = catalog.offer(for: tier) else { return }
        NSWorkspace.shared.open(offer.checkoutURL)
    }

    func restore(key: String) async -> Bool {
        guard !isRestoring else { return false }
        message = nil
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 512 else { message = "That key needs another look."; return false }
        guard let catalog, catalog.isConfigured else { message = "The shelf is being stocked. Check back soon."; return false }
        isRestoring = true
        defer { isRestoring = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var form = URLComponents()
            form.queryItems = [URLQueryItem(name: "license_key", value: key)]
            request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
            let session = URLSession(configuration: .ephemeral)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if response.statusCode == 429 { message = "One sip at a time. Try again in a minute."; return false }
            guard (200..<300).contains(response.statusCode) else { message = "Couldn’t check that key. Try again shortly."; return false }
            let license = try JSONDecoder().decode(ProLicenseResponse.self, from: data)
            guard let unlocked = license.tier(in: catalog) else { message = "That isn’t a current Schnaps Pro key."; return false }
            if let tier, tier.rank > unlocked.rank { message = "Your shelf is already top shelf. Cheers!"; return true }
            let saved = Membership(tier: unlocked, key: key, storeID: catalog.storeID, productID: catalog.productID)
            let attributes = [kSecValueData as String: try JSONEncoder().encode(saved)]
            let status = SecItemUpdate(keychain as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var item = keychain.merging(attributes) { _, new in new }
                item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { message = "Couldn’t save your keepsake. Try again."; return false }
            } else if status != errSecSuccess {
                message = "Couldn’t save your keepsake. Try again."; return false
            }
            tier = unlocked
            message = "A little treasure, just for you. Cheers!"
            return true
        } catch {
            message = "Couldn’t reach the shelf. Try again when you’re online."
            return false
        }
    }
}
