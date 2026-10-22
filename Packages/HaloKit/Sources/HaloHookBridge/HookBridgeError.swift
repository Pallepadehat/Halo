import Foundation

public enum HookBridgeError: Error, Equatable {
    case socketPathTooLong(URL)
    case system(operation: String, code: Int32)
    case malformedMessage
    case messageTooLarge

    static func posix(_ operation: String) -> HookBridgeError {
        .system(operation: operation, code: errno)
    }
}

extension HookBridgeError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .socketPathTooLong(let url): "Socket path is too long: \(url.path(percentEncoded: false))"
        case .system(let operation, let code): "\(operation) failed: \(String(cString: strerror(code)))"
        case .malformedMessage: "Malformed hook bridge message"
        case .messageTooLarge: "Hook bridge message exceeds the size limit"
        }
    }
}
