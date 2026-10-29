import Foundation

public enum ReleaseFeed {
    public enum Failure: Error { case invalidFeed, duplicateBuild }
    public struct Entry {
        public let build: Int
        public let version: String
        public let channel: UpdateChannel
        public let url: String
        public let signature: String
        fileprivate let element: XMLElement
    }
    public static func entries(_ data: Data) throws -> [Entry] {
        let document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        guard let channel = document.rootElement()?.elements(forName: "channel").first else {
            throw Failure.invalidFeed
        }
        return try channel.elements(forName: "item").map { item in
            guard let enclosure = item.elements(forName: "enclosure").first,
                let build = Int(
                    item.elements(forName: "sparkle:version").first?.stringValue ?? enclosure.attribute(
                        forName: "sparkle:version")?.stringValue ?? ""), build > 0,
                let version = item.elements(forName: "sparkle:shortVersionString").first?.stringValue
                    ?? enclosure.attribute(forName: "sparkle:shortVersionString")?.stringValue,
                ReleaseVersion(version) != nil,
                let url = enclosure.attribute(forName: "url")?.stringValue,
                url.hasPrefix("https://github.com/gabriel/Schnaps/releases/download/"),
                let signature = enclosure.attribute(forName: "sparkle:edSignature")?.stringValue,
                Data(base64Encoded: signature)?.count == 64
            else { throw Failure.invalidFeed }
            let name = item.elements(forName: "sparkle:channel").first?.stringValue
            guard name == nil || name == "beta" else { throw Failure.invalidFeed }
            return Entry(
                build: build, version: version, channel: name == "beta" ? .beta : .stable,
                url: url, signature: signature, element: item)
        }
    }
    public static func merge(_ feeds: [Data]) throws -> Data {
        var byBuild: [Int: Entry] = [:]
        for entry in try feeds.flatMap({ try entries($0) }) {
            if let prior = byBuild[entry.build],
                prior.url != entry.url || prior.channel != entry.channel || prior.version != entry.version
            {
                throw Failure.duplicateBuild
            }
            byBuild[entry.build] = entry
        }
        let root = XMLElement(name: "rss")
        root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "2.0") as! XMLNode)
        root.addNamespace(
            XMLNode.namespace(withName: "sparkle", stringValue: "http://www.andymatuschak.org/xml-namespaces/sparkle")
                as! XMLNode)
        let channel = XMLElement(name: "channel")
        channel.addChild(XMLElement(name: "title", stringValue: "Schnaps"))
        root.addChild(channel)
        var counts: [UpdateChannel: Int] = [:]
        for entry in byBuild.values.sorted(by: { $0.build > $1.build }) {
            let count = counts[entry.channel, default: 0]
            guard count < 10 else { continue }
            counts[entry.channel] = count + 1
            channel.addChild(entry.element.copy() as! XMLNode)
        }
        guard !counts.isEmpty else { throw Failure.invalidFeed }
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "utf-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }
}
