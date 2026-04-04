import Foundation

public struct SubscriptionConfig: Codable, Equatable, Sendable {
    public var sourceURL: URL
    public var fetchedAt: Date
    public var subscriptionName: String?
    public var proxies: [ClashProxy]

    public init(
        sourceURL: URL,
        fetchedAt: Date = .init(),
        subscriptionName: String? = nil,
        proxies: [ClashProxy]
    ) {
        self.sourceURL = sourceURL
        self.fetchedAt = fetchedAt
        self.subscriptionName = subscriptionName
        self.proxies = proxies
    }

    public var configurationID: String {
        sourceURL.absoluteString
    }
}

public struct ClashProxy: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var type: String
    public var server: String?
    public var port: Int?
    public var udp: Bool?
    public var metadata: [String: String]

    public init(
        id: String? = nil,
        name: String,
        type: String,
        server: String? = nil,
        port: Int? = nil,
        udp: Bool? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id ?? ClashProxy.makeIdentifier(name: name, type: type, server: server, port: port)
        self.name = name
        self.type = type
        self.server = server
        self.port = port
        self.udp = udp
        self.metadata = metadata
    }

    private static func makeIdentifier(
        name: String,
        type: String,
        server: String?,
        port: Int?
    ) -> String {
        let host = server ?? "unknown-host"
        let portText = port.map(String.init) ?? "unknown-port"
        return "\(name)|\(type)|\(host)|\(portText)"
    }
}
