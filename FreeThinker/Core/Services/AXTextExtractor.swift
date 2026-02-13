import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public protocol AXTextExtractorProtocol: Sendable {
    func extractSelectedText() throws -> AXExtractedText
}

public struct AXExtractedText: Equatable, Sendable {
    public let text: String
    public let selectionBounds: CGRect?
    public let sourceAppBundleIdentifier: String?

    public init(text: String, selectionBounds: CGRect?, sourceAppBundleIdentifier: String?) {
        self.text = text
        self.selectionBounds = selectionBounds
        self.sourceAppBundleIdentifier = sourceAppBundleIdentifier
    }
}

public protocol AXUIElementAccessing: Sendable {
    func systemWideElement() -> AXUIElement
    func copyAttributeValue(element: AXUIElement, attribute: CFString) -> (AXError, CFTypeRef?)
    func copyParameterizedAttributeValue(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (AXError, CFTypeRef?)
}

public struct SystemAXUIElementClient: AXUIElementAccessing {
    public init() {}

    public func systemWideElement() -> AXUIElement {
        AXUIElementCreateSystemWide()
    }

    public func copyAttributeValue(element: AXUIElement, attribute: CFString) -> (AXError, CFTypeRef?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return (result, value)
    }

    public func copyParameterizedAttributeValue(element: AXUIElement, attribute: CFString, parameter: CFTypeRef) -> (AXError, CFTypeRef?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(element, attribute, parameter, &value)
        return (result, value)
    }
}

public protocol FrontmostApplicationProviding: Sendable {
    var frontmostBundleIdentifier: String? { get }
}

public struct WorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {
    public init() {}

    public var frontmostBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

public final class AXTextExtractor: AXTextExtractorProtocol {
    private let axClient: AXUIElementAccessing
    private let frontmostApplicationProvider: FrontmostApplicationProviding

    public init(
        axClient: AXUIElementAccessing = SystemAXUIElementClient(),
        frontmostApplicationProvider: FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()
    ) {
        self.axClient = axClient
        self.frontmostApplicationProvider = frontmostApplicationProvider
    }

    public func extractSelectedText() throws -> AXExtractedText {
        let systemWideElement = axClient.systemWideElement()

        guard let focusedElement = try focusedElement(from: systemWideElement) else {
            throw FreeThinkerError.noFocusedElement
        }

        let selectedText = try selectedText(from: focusedElement)
        let normalized = Self.normalize(selectedText)

        guard !normalized.isEmpty else {
            throw FreeThinkerError.noSelection
        }

        let bounds = try selectionBounds(from: focusedElement)
        return AXExtractedText(
            text: normalized,
            selectionBounds: bounds,
            sourceAppBundleIdentifier: frontmostApplicationProvider.frontmostBundleIdentifier
        )
    }

    private func focusedElement(from systemWideElement: AXUIElement) throws -> AXUIElement? {
        let (result, value) = axClient.copyAttributeValue(
            element: systemWideElement,
            attribute: kAXFocusedUIElementAttribute as CFString
        )

        switch result {
        case .success:
            guard let value else {
                return nil
            }
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeBitCast(value, to: AXUIElement.self)
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw FreeThinkerError.captureFailed(reason: "Focused element lookup failed: \(result.rawValue)")
        }
    }

    private func selectedText(from focusedElement: AXUIElement) throws -> String {
        if let explicit = try attributeString(
            from: focusedElement,
            attribute: kAXSelectedTextAttribute as CFString
        ), !Self.normalize(explicit).isEmpty {
            return explicit
        }

        guard let range = try selectedRange(from: focusedElement) else {
            let role = try attributeString(from: focusedElement, attribute: kAXRoleAttribute as CFString)
            throw FreeThinkerError.unsupportedElement(role: role)
        }

        guard range.length > 0 else {
            throw FreeThinkerError.noSelection
        }

        guard let value = try attributeString(from: focusedElement, attribute: kAXValueAttribute as CFString) else {
            let role = try attributeString(from: focusedElement, attribute: kAXRoleAttribute as CFString)
            throw FreeThinkerError.unsupportedElement(role: role)
        }

        let nsRange = NSRange(location: range.location, length: range.length)
        guard let swiftRange = Range(nsRange, in: value) else {
            throw FreeThinkerError.captureFailed(reason: "Selected range did not map to text value.")
        }

        return String(value[swiftRange])
    }

    private func selectionBounds(from focusedElement: AXUIElement) throws -> CGRect? {
        guard let range = try selectedRange(from: focusedElement), range.length > 0 else {
            return nil
        }

        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return nil
        }

        let (result, value) = axClient.copyParameterizedAttributeValue(
            element: focusedElement,
            attribute: kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter: rangeValue
        )

        guard result == .success else {
            return nil
        }

        guard let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var rect = CGRect.null
        let didExtract = AXValueGetValue(axValue as! AXValue, .cgRect, &rect)
        return didExtract ? rect : nil
    }

    private func selectedRange(from focusedElement: AXUIElement) throws -> CFRange? {
        let (result, value) = axClient.copyAttributeValue(
            element: focusedElement,
            attribute: kAXSelectedTextRangeAttribute as CFString
        )

        switch result {
        case .success:
            guard let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
                return nil
            }

            var range = CFRange(location: 0, length: 0)
            let didExtract = AXValueGetValue(axValue as! AXValue, .cfRange, &range)
            return didExtract ? range : nil
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw FreeThinkerError.captureFailed(reason: "Selected range lookup failed: \(result.rawValue)")
        }
    }

    private func attributeString(from element: AXUIElement, attribute: CFString) throws -> String? {
        let (result, value) = axClient.copyAttributeValue(element: element, attribute: attribute)

        switch result {
        case .success:
            if let text = value as? String {
                return text
            }
            if let attributed = value as? NSAttributedString {
                return attributed.string
            }
            return nil
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw FreeThinkerError.captureFailed(reason: "Attribute lookup failed (\(attribute)): \(result.rawValue)")
        }
    }

    private static func normalize(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
