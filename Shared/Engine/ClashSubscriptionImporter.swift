import Foundation

public protocol SubscriptionContentFetching: Sendable {
    func fetch(from url: URL) async throws -> Data
}

public final class ClashSubscriptionImporter: Sendable {
    private let fetcher: any SubscriptionContentFetching
    private let clock: @Sendable () -> Date

    public init(
        fetcher: any SubscriptionContentFetching = URLSessionSubscriptionContentFetcher(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetcher = fetcher
        self.clock = clock
    }

    public func importSubscription(from link: String) async -> SubscriptionImportResult {
        guard let url = URL(string: link), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return .rejected(
                SubscriptionImportFailure(
                    reason: .invalidURL,
                    message: "The subscription link is invalid."
                )
            )
        }

        do {
            let data = try await fetcher.fetch(from: url)
            return importSubscription(from: data, sourceURL: url)
        } catch {
            return .rejected(
                SubscriptionImportFailure(
                    reason: .fetchFailed,
                    message: "Could not load the Clash subscription link.",
                    isRetryable: true
                )
            )
        }
    }

    public func importSubscription(from data: Data, sourceURL: URL) -> SubscriptionImportResult {
        guard !data.isEmpty else {
            return .rejected(
                SubscriptionImportFailure(
                    reason: .emptyContent,
                    message: "The subscription response was empty."
                )
            )
        }

        let rawText = String(decoding: data, as: UTF8.self)
        let decodedText = Self.decodeBase64IfNeeded(from: rawText)
        let subscriptionText = Self.chooseBestText(rawText: rawText, decodedText: decodedText)

        switch SubscriptionTextParser.parse(subscriptionText) {
        case .parsed(let parsed):
            guard !parsed.proxies.isEmpty else {
                return .rejected(
                    SubscriptionImportFailure(
                        reason: .unsupportedContent,
                        message: "The subscription does not contain any usable proxies."
                    )
                )
            }

            let config = SubscriptionConfig(
                sourceURL: sourceURL,
                fetchedAt: clock(),
                subscriptionName: parsed.subscriptionName,
                proxies: parsed.proxies
            )
            return .accepted(config)
        case .unsupported:
            return .rejected(
                SubscriptionImportFailure(
                    reason: .unsupportedContent,
                    message: "RockeRoom fetched the subscription, but this format is not supported yet."
                )
            )
        case .malformed:
            return .rejected(
                SubscriptionImportFailure(
                    reason: .malformedContent,
                    message: "The subscription response is not valid Clash YAML or a supported share-link feed."
                )
            )
        }
    }

    private static func decodeBase64IfNeeded(from text: String) -> String? {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty, let data = Data(base64Encoded: stripped) else { return nil }
        let decoded = String(decoding: data, as: UTF8.self)
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : decoded
    }

    private static func chooseBestText(rawText: String, decodedText: String?) -> String {
        if let decodedText, looksLikeStructuredSubscription(decodedText) {
            return decodedText
        }
        if looksLikeStructuredSubscription(rawText) {
            return rawText
        }
        return decodedText ?? rawText
    }

    private static func looksLikeStructuredSubscription(_ text: String) -> Bool {
        text.contains("proxies:") ||
        text.contains("proxy-providers:") ||
        text.localizedCaseInsensitiveContains("vless://") ||
        text.localizedCaseInsensitiveContains("vmess://") ||
        text.localizedCaseInsensitiveContains("trojan://") ||
        text.localizedCaseInsensitiveContains("ss://")
    }
}

public struct URLSessionSubscriptionContentFetcher: SubscriptionContentFetching, @unchecked Sendable {
    public init() {}

    public func fetch(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

private struct ParsedSubscriptionText {
    var subscriptionName: String?
    var proxies: [ClashProxy]
}

private enum SubscriptionTextParseResult {
    case parsed(ParsedSubscriptionText)
    case unsupported
    case malformed
}

private enum SubscriptionTextParser {
    static func parse(_ text: String) -> SubscriptionTextParseResult {
        if looksLikeClashYAML(text) {
            return parseClashYAML(text)
        }
        if looksLikeURIFeed(text) {
            return parseURIFeed(text)
        }
        return .malformed
    }

    private static func parseClashYAML(_ text: String) -> SubscriptionTextParseResult {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return .malformed }

        var subscriptionName: String?
        var proxies: [ClashProxy] = []
        var currentProxy: [String: String] = [:]
        var currentName: String?
        var currentType: String?
        var currentServer: String?
        var currentPort: Int?
        var currentUDP: Bool?

        func flushCurrentProxy() {
            guard let name = currentName, let type = currentType else {
                currentProxy = [:]
                currentName = nil
                currentType = nil
                currentServer = nil
                currentPort = nil
                currentUDP = nil
                return
            }

            proxies.append(
                ClashProxy(
                    name: name,
                    type: type,
                    server: currentServer,
                    port: currentPort,
                    udp: currentUDP,
                    metadata: currentProxy
                )
            )

            currentProxy = [:]
            currentName = nil
            currentType = nil
            currentServer = nil
            currentPort = nil
            currentUDP = nil
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("name:") && subscriptionName == nil, let value = value(after: "name:", in: line) {
                subscriptionName = value
            }

            if line.hasPrefix("- ") && line.contains("name:") {
                flushCurrentProxy()
                if let inline = parseInlineMap(line) {
                    currentName = inline["name"]
                    currentType = inline["type"]
                    currentServer = inline["server"]
                    currentPort = inline["port"].flatMap(Int.init)
                    currentUDP = inline["udp"].flatMap(Self.parseBool)
                    currentProxy = inline
                } else if let name = value(after: "- name:", in: line) {
                    currentName = name
                    currentProxy["name"] = name
                }
                continue
            }

            if line.hasPrefix("proxies:") || line.hasPrefix("proxy-providers:") || line.hasPrefix("proxy-groups:") || line.hasPrefix("rules:") {
                continue
            }

            if line.hasPrefix("- ") {
                flushCurrentProxy()
                if let inline = parseInlineMap(line) {
                    currentName = inline["name"]
                    currentType = inline["type"]
                    currentServer = inline["server"]
                    currentPort = inline["port"].flatMap(Int.init)
                    currentUDP = inline["udp"].flatMap(Self.parseBool)
                    currentProxy = inline
                }
                continue
            }

            guard line.contains(":") else { continue }
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            currentProxy[key] = value

            switch key {
            case "name":
                currentName = value
            case "type":
                currentType = value
            case "server":
                currentServer = value
            case "port":
                currentPort = Int(value)
            case "udp":
                currentUDP = Self.parseBool(value)
            default:
                break
            }
        }

        flushCurrentProxy()
        guard !proxies.isEmpty else { return .unsupported }
        return .parsed(ParsedSubscriptionText(subscriptionName: subscriptionName, proxies: proxies))
    }

    private static func value(after prefix: String, in line: String) -> String? {
        guard let range = line.range(of: prefix) else { return nil }
        let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func parseInlineMap(_ line: String) -> [String: String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else { return nil }
        let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
        guard content.hasPrefix("{"), content.hasSuffix("}") else { return nil }

        let body = content.dropFirst().dropLast()
        var fields: [String: String] = [:]

        for chunk in body.split(separator: ",") {
            let pieces = chunk.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { continue }
            let key = pieces[0].trimmingCharacters(in: .whitespaces)
            let value = pieces[1].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                fields[key] = value
            }
        }

        return fields.isEmpty ? nil : fields
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    private static func parseURIFeed(_ text: String) -> SubscriptionTextParseResult {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return .malformed }

        var proxies: [ClashProxy] = []
        var sawShareLink = false
        var sawSupportedShareLink = false

        for line in lines {
            guard let scheme = uriScheme(in: line) else { continue }
            sawShareLink = true

            guard supportedURISchemes.contains(scheme) else { continue }
            sawSupportedShareLink = true

            switch parseURIProxy(line, scheme: scheme) {
            case .accepted(let proxy):
                proxies.append(proxy)
            case .ignoredMetadata:
                continue
            case .malformed:
                return .malformed
            }
        }

        if !proxies.isEmpty {
            return .parsed(ParsedSubscriptionText(subscriptionName: nil, proxies: proxies))
        }
        if sawSupportedShareLink || sawShareLink {
            return .unsupported
        }
        return .malformed
    }

    private static func parseURIProxy(_ line: String, scheme: String) -> URIProxyParseResult {
        guard let components = URLComponents(string: line),
              let host = components.host,
              let port = components.port
        else {
            return .malformed
        }

        let decodedName = decodedFragment(from: components) ?? "\(scheme.uppercased()) \(host)"
        if isMetadataOnlyProxyName(decodedName) {
            return .ignoredMetadata
        }

        var metadata: [String: String] = [
            "rawURI": line,
            "scheme": scheme
        ]

        if let user = components.user, !user.isEmpty {
            metadata["credential"] = user
        }

        if let password = components.password, !password.isEmpty {
            metadata["password"] = password
        }

        for item in components.queryItems ?? [] {
            guard let value = item.value, !value.isEmpty else { continue }
            metadata[item.name] = value
        }

        return .accepted(
            ClashProxy(
                name: decodedName,
                type: scheme,
                server: host,
                port: port,
                udp: metadata["udp"].flatMap(parseBool),
                metadata: metadata
            )
        )
    }

    private static func decodedFragment(from components: URLComponents) -> String? {
        let rawFragment = components.percentEncodedFragment ?? components.fragment
        let decoded = rawFragment?.removingPercentEncoding ?? rawFragment
        let trimmed = decoded?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func uriScheme(in line: String) -> String? {
        guard let separator = line.range(of: "://") else { return nil }
        let scheme = line[..<separator.lowerBound].lowercased()
        return scheme.isEmpty ? nil : scheme
    }

    private static func looksLikeClashYAML(_ text: String) -> Bool {
        text.contains("proxies:") || text.contains("proxy-providers:")
    }

    private static func looksLikeURIFeed(_ text: String) -> Bool {
        text.split(whereSeparator: \.isNewline).contains { line in
            uriScheme(in: String(line)) != nil
        }
    }

    private static func isMetadataOnlyProxyName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let metadataMarkers = [
            "剩余流量",
            "流量",
            "到期",
            "套餐",
            "订阅",
            "官网",
            "客服",
            "群"
        ]

        return metadataMarkers.contains { trimmed.localizedCaseInsensitiveContains($0) }
    }

    private static let supportedURISchemes: Set<String> = ["vless", "vmess", "trojan", "ss"]
}

private enum URIProxyParseResult {
    case accepted(ClashProxy)
    case ignoredMetadata
    case malformed
}
