import CoreGraphics
import Foundation

public enum CaptureMethod: String, Codable, Sendable {
    case accessibilityAPI
    case clipboardFallback
}

public enum CaptureFallbackReason: String, Codable, Sendable {
    case unsupportedElement
    case noSelection
    case extractorFailure
}

public struct CaptureMetadata: Equatable, Sendable {
    public let method: CaptureMethod
    public let timestamp: Date
    public let sourceAppBundleIdentifier: String?
    public let selectionBounds: CGRect?
    public let usedFallback: Bool
    public let fallbackReason: CaptureFallbackReason?

    public init(
        method: CaptureMethod,
        timestamp: Date,
        sourceAppBundleIdentifier: String?,
        selectionBounds: CGRect?,
        usedFallback: Bool,
        fallbackReason: CaptureFallbackReason?
    ) {
        self.method = method
        self.timestamp = timestamp
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
        self.selectionBounds = selectionBounds
        self.usedFallback = usedFallback
        self.fallbackReason = fallbackReason
    }
}

public struct CaptureResult: Equatable, Sendable {
    public let text: String
    public let metadata: CaptureMetadata

    public init(text: String, metadata: CaptureMetadata) {
        self.text = text
        self.metadata = metadata
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
