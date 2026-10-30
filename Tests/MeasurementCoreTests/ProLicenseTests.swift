import Foundation
import Testing
@testable import MeasurementCore

private func catalog(_ checkout: String = "https://schnaps.lemonsqueezy.com/buy/sip") throws -> ProCatalog {
    try JSONDecoder().decode(ProCatalog.self, from: Data("""
    {"storeID":123,"productID":456,"offers":{
      "sip":{"variantID":1,"checkoutURL":"\(checkout)"},
      "pour":{"variantID":2,"checkoutURL":"https://schnaps.lemonsqueezy.com/buy/pour"},
      "reserve":{"variantID":3,"checkoutURL":"https://schnaps.lemonsqueezy.com/buy/reserve"}
    }}
    """.utf8))
}

private func response(valid: Bool = true, store: Int = 123, product: Int = 456,
                      variant: Int = 1, status: String = "active", testMode: Bool = false) throws -> ProLicenseResponse {
    try JSONDecoder().decode(ProLicenseResponse.self, from: Data("""
    {"valid":\(valid),"error":null,"license_key":{"status":"\(status)"},
     "meta":{"store_id":\(store),"product_id":\(product),"variant_id":\(variant),"test_mode":\(testMode)}}
    """.utf8))
}

@Test func proReceiptRecognizesAllThreeTiers() throws {
    let config = try catalog()
    #expect(try response(variant: 1).tier(in: config) == .sip)
    #expect(try response(variant: 2).tier(in: config) == .pour)
    #expect(try response(variant: 3, status: "inactive").tier(in: config) == .reserve)
}

@Test func unrelatedOrInvalidProReceiptsAreRejected() throws {
    let config = try catalog()
    #expect(try response(store: 999).tier(in: config) == nil)
    #expect(try response(product: 999).tier(in: config) == nil)
    #expect(try response(variant: 999).tier(in: config) == nil)
    #expect(try response(valid: false).tier(in: config) == nil)
    #expect(try response(status: "disabled").tier(in: config) == nil)
    #expect(try response(status: "expired").tier(in: config) == nil)
    #expect(try response(testMode: true).tier(in: config) == nil)
    let missingMeta = try JSONDecoder().decode(ProLicenseResponse.self, from: Data("{\"valid\":true}".utf8))
    #expect(missingMeta.tier(in: config) == nil)
}

@Test func checkoutMustBeAnOfficialHTTPSLemonSqueezyBuyLink() throws {
    #expect(try catalog().isConfigured)
    #expect(try catalog("https://schnaps.lemonsqueezy.com/checkout/buy/00000000-0000-0000-0000-000000000001").isConfigured)
    for url in ["http://schnaps.lemonsqueezy.com/buy/sip", "https://lemonsqueezy.com.attacker.example/buy/sip",
                "https://schnaps.lemonsqueezy.com/products/sip", "https://name:password@schnaps.lemonsqueezy.com/buy/sip"] {
        #expect(try !catalog(url).isConfigured)
    }
    let empty = try JSONDecoder().decode(ProCatalog.self, from: Data("{\"storeID\":0,\"productID\":0,\"offers\":{}}".utf8))
    #expect(!empty.isConfigured)
    #expect(try response().tier(in: empty) == nil)
}
