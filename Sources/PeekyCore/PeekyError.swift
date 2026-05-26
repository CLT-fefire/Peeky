import Foundation

public enum PeekyError: Error, Sendable {
    case invalidPlist(url: URL)
    case unsupportedSource(url: URL)
    case profileDecodeFailed(reason: String)
    case ipaExtractFailed(reason: String)
}
