import ApplicationServices

@MainActor
struct AccessibilityTextInserter: FocusedTextInserter {
    func captureTarget() -> FocusedInputTarget? {
        guard let focusedElement = currentFocusedElement() else {
            return nil
        }

        return FocusedInputTarget(
            element: focusedElement,
            debugDescription: copyRoleDescription(from: focusedElement) ?? "focused-element",
            capturedValue: copyStringAttribute(kAXValueAttribute, from: focusedElement)
        )
    }

    func insert(_ text: String) throws {
        guard let focusedElement = currentFocusedElement() else {
            throw InsertionError.unsupportedFocusedElement
        }

        try insert(text, intoElement: focusedElement)
    }

    func insert(_ text: String, into target: FocusedInputTarget) throws {
        guard let targetElement = target.element else {
            throw InsertionError.unsupportedFocusedElement
        }

        try insert(text, intoElement: targetElement, capturedValue: target.capturedValue)
    }

    private func currentFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )

        guard focusedResult == .success,
              let focusedElementValue,
              CFGetTypeID(focusedElementValue) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(focusedElementValue, to: AXUIElement.self)
    }

    private func insert(
        _ text: String,
        intoElement element: AXUIElement,
        capturedValue: String? = nil
    ) throws {
        if try replaceSelectedText(in: element, with: text, capturedValue: capturedValue) {
            return
        }

        if try appendText(text, to: element, capturedValue: capturedValue) {
            return
        }

        throw InsertionError.unsupportedFocusedElement
    }

    private func replaceSelectedText(
        in element: AXUIElement,
        with text: String,
        capturedValue: String?
    ) throws -> Bool {
        guard let currentValue = copyStringAttribute(kAXValueAttribute, from: element),
              let selectedRange = copySelectedRange(from: element) else {
            return false
        }

        if let capturedValue, capturedValue != currentValue {
            return false
        }

        let currentNSString = currentValue as NSString
        guard selectedRange.location != NSNotFound,
              selectedRange.location <= currentNSString.length,
              selectedRange.location + selectedRange.length <= currentNSString.length else {
            return false
        }

        let updatedValue = currentNSString.replacingCharacters(in: selectedRange, with: text)
        guard setStringAttribute(kAXValueAttribute, value: updatedValue, on: element) else {
            return false
        }

        let newCaretLocation = selectedRange.location + (text as NSString).length
        let newRange = NSRange(location: newCaretLocation, length: 0)
        _ = setSelectedRange(newRange, on: element)
        return verifyValue(updatedValue, on: element)
    }

    private func appendText(
        _ text: String,
        to element: AXUIElement,
        capturedValue: String?
    ) throws -> Bool {
        guard let currentValue = copyStringAttribute(kAXValueAttribute, from: element) else {
            return false
        }

        if let capturedValue, capturedValue != currentValue {
            return false
        }

        let updatedValue = currentValue + text
        guard setStringAttribute(kAXValueAttribute, value: updatedValue, on: element) else {
            return false
        }

        let endLocation = (updatedValue as NSString).length
        _ = setSelectedRange(NSRange(location: endLocation, length: 0), on: element)
        return verifyValue(updatedValue, on: element)
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func copyRoleDescription(from element: AXUIElement) -> String? {
        copyStringAttribute(kAXRoleDescriptionAttribute, from: element)
            ?? copyStringAttribute(kAXRoleAttribute, from: element)
    }

    private func copySelectedRange(from element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard result == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let rangeValue = unsafeDowncast(axValue, to: AXValue.self)
        guard AXValueGetType(rangeValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return nil
        }

        return NSRange(location: range.location, length: range.length)
    }

    private func setStringAttribute(_ attribute: String, value: String, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef) == .success
    }

    private func setSelectedRange(_ range: NSRange, on element: AXUIElement) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let axValue = AXValueCreate(.cfRange, &cfRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axValue
        ) == .success
    }

    private func verifyValue(_ expectedValue: String, on element: AXUIElement) -> Bool {
        guard copyStringAttribute(kAXValueAttribute, from: element) == expectedValue else {
            AppLogger.log("insert: accessibility write verification failed")
            return false
        }

        return true
    }
}
