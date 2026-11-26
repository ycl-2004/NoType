import CoreGraphics
import Testing
@testable import Typeless

@MainActor
struct EscapeKeyInterceptorTests {
    private let escape = EscapeKeyInterceptor.escapeKeyCode

    @Test
    func plainEscapeCancelsOnceAndIsConsumedWithItsRelease() {
        var cancels = 0
        let interceptor = EscapeKeyInterceptor { cancels += 1 }

        #expect(interceptor.handle(type: .keyDown, keyCode: escape, flags: [], isRepeat: false))
        #expect(interceptor.handle(type: .keyDown, keyCode: escape, flags: [], isRepeat: true))
        #expect(interceptor.handle(type: .keyUp, keyCode: escape, flags: [], isRepeat: false))
        #expect(cancels == 1)
    }

    @Test
    func otherKeysAndModifiedEscapeReachTheFocusedApp() {
        var cancels = 0
        let interceptor = EscapeKeyInterceptor { cancels += 1 }

        #expect(interceptor.handle(type: .keyDown, keyCode: 0, flags: [], isRepeat: false) == false)
        #expect(interceptor.handle(type: .keyDown, keyCode: escape, flags: .maskCommand, isRepeat: false) == false)
        #expect(interceptor.handle(type: .keyDown, keyCode: escape, flags: .maskShift, isRepeat: false) == false)
        // A release whose press was never consumed is not ours to drop.
        #expect(interceptor.handle(type: .keyUp, keyCode: escape, flags: [], isRepeat: false) == false)
        // Caps Lock and other non-blocking flags do not turn Escape into another gesture.
        #expect(interceptor.handle(type: .keyDown, keyCode: escape, flags: .maskAlphaShift, isRepeat: false))
        #expect(cancels == 1)
    }
}
