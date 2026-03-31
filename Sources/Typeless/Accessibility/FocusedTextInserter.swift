@MainActor
protocol FocusedTextInserter {
    func insert(_ text: String) throws
}

@MainActor
protocol FallbackTextInserter {
    func paste(_ text: String, preserveClipboard: Bool) throws
}
