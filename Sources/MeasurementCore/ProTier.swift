import Foundation

public enum ProTier: String, Codable, CaseIterable, Sendable, Identifiable {
    case sip, pour, reserve
    public var id: Self { self }
    public var name: String {
        switch self { case .sip: "Sip"; case .pour: "Pour"; case .reserve: "Reserve" }
    }
    public var price: Int {
        switch self { case .sip: 5; case .pour: 10; case .reserve: 50 }
    }
    public var rank: Int {
        switch self { case .sip: 1; case .pour: 2; case .reserve: 3 }
    }
    public var keepsake: String {
        switch self { case .sip: "Lucky Cork"; case .pour: "Little Bottle"; case .reserve: "Golden Decanter" }
    }
}

public struct ProCatalog: Codable, Sendable {
    public struct Offer: Codable, Sendable {
        public let variantID: Int
        public let checkoutURL: URL
    }
    public let storeID: Int
    public let productID: Int
    public let offers: [String: Offer]

    public var isConfigured: Bool {
        guard storeID > 0, productID > 0 else { return false }
        let variants = ProTier.allCases.compactMap { offer(for: $0)?.variantID }
        return variants.count == 3 && Set(variants).count == 3
    }

    public func offer(for tier: ProTier) -> Offer? {
        guard storeID > 0, productID > 0, let offer = offers[tier.rawValue], offer.variantID > 0,
              offer.checkoutURL.scheme == "https", let host = offer.checkoutURL.host,
              host.hasSuffix(".lemonsqueezy.com"), offer.checkoutURL.path.hasPrefix("/buy/"),
              offer.checkoutURL.user == nil, offer.checkoutURL.password == nil else { return nil }
        return offer
    }
}

public struct ProLicenseResponse: Decodable, Sendable {
    public struct License: Decodable, Sendable { let status: String }
    public struct Meta: Decodable, Sendable {
        let store_id: Int
        let product_id: Int
        let variant_id: Int
        let test_mode: Bool?
    }
    let valid: Bool
    let error: String?
    let license_key: License?
    let meta: Meta?

    public func tier(in catalog: ProCatalog) -> ProTier? {
        guard catalog.isConfigured, valid, error == nil,
              let license_key, ["active", "inactive"].contains(license_key.status),
              let meta, meta.test_mode != true,
              meta.store_id == catalog.storeID, meta.product_id == catalog.productID else { return nil }
        return ProTier.allCases.first { catalog.offer(for: $0)?.variantID == meta.variant_id }
    }
}
