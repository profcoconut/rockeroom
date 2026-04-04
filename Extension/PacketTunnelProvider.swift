import Foundation
import NetworkExtension
import SharedKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let adapter = ClashAdapter(engine: ProviderRuntimeClashEngine())

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let configData = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["subscriptionConfig"] as? Data else {
            completionHandler(PacketTunnelProviderError.missingConfiguration)
            return
        }

        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(SubscriptionConfig.self, from: configData)
            let adapter = self.adapter
            let completion = ErrorCompletionBox(completionHandler)
            Task {
                do {
                    try await adapter.start(with: config)
                    completion.call(nil)
                } catch {
                    completion.call(error)
                }
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        let adapter = self.adapter
        let completion = VoidCompletionBox(completionHandler)
        Task {
            await adapter.stop()
            completion.call()
        }
    }
}

enum PacketTunnelProviderError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Missing subscription configuration for tunnel startup."
        }
    }
}

private final class ErrorCompletionBox: @unchecked Sendable {
    private let handler: (Error?) -> Void

    init(_ handler: @escaping (Error?) -> Void) {
        self.handler = handler
    }

    func call(_ error: Error?) {
        handler(error)
    }
}

private final class VoidCompletionBox: @unchecked Sendable {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func call() {
        handler()
    }
}
