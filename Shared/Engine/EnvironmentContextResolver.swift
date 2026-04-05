import Foundation

public protocol EnvironmentContextResolving: Sendable {
    func currentEnvironment() -> NetworkEnvironment
}

public struct StaticEnvironmentContextResolver: EnvironmentContextResolving {
    public let environment: NetworkEnvironment

    public init(environment: NetworkEnvironment = .unknown) {
        self.environment = environment
    }

    public func currentEnvironment() -> NetworkEnvironment {
        environment
    }
}
