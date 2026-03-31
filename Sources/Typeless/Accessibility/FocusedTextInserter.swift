import ApplicationServices

@MainActor
final class FocusedInputTarget {
    let element: AXUIElement?
    let debugDescription: String

    init(element: AXUIElement?, debugDescription: String = "unknown") {
        self.element = element
        self.debugDescription = debugDescription
    }
}

@MainActor
protocol FocusedTextInserter {
    func captureTarget() -> FocusedInputTarget?
    func insert(_ text: String) throws
    func insert(_ text: String, into target: FocusedInputTarget) throws
}

@MainActor
protocol FallbackTextInserter {
    func paste(_ text: String, preserveClipboard: Bool) throws
}
