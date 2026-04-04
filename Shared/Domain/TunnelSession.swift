import Foundation

public struct TunnelSession: Codable, Equatable, Sendable {
    public enum RequestedState: String, Codable, Equatable, Sendable {
        case idle
        case startRequested
        case stopRequested
    }

    public enum RuntimeState: Codable, Equatable, Sendable {
        case stopped
        case starting
        case running
        case failed(message: String)

        private enum CodingKeys: String, CodingKey {
            case state
            case message
        }

        private enum StateValue: String, Codable {
            case stopped
            case starting
            case running
            case failed
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let state = try container.decode(StateValue.self, forKey: .state)

            switch state {
            case .stopped:
                self = .stopped
            case .starting:
                self = .starting
            case .running:
                self = .running
            case .failed:
                self = .failed(message: try container.decode(String.self, forKey: .message))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .stopped:
                try container.encode(StateValue.stopped, forKey: .state)
            case .starting:
                try container.encode(StateValue.starting, forKey: .state)
            case .running:
                try container.encode(StateValue.running, forKey: .state)
            case .failed(let message):
                try container.encode(StateValue.failed, forKey: .state)
                try container.encode(message, forKey: .message)
            }
        }
    }

    public var configurationID: String?
    public var requestedState: RequestedState
    public var runtimeState: RuntimeState
    public var updatedAt: Date

    public init(
        configurationID: String? = nil,
        requestedState: RequestedState = .idle,
        runtimeState: RuntimeState = .stopped,
        updatedAt: Date = Date()
    ) {
        self.configurationID = configurationID
        self.requestedState = requestedState
        self.runtimeState = runtimeState
        self.updatedAt = updatedAt
    }
}
