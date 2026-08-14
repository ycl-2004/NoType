import Testing
@testable import Typeless

struct ModifierDoubleTapMonitorTests {
    @Test
    func triggersOnlyAfterTwoCompletedModifierTaps() {
        var detector = ModifierDoubleTapDetector()

        #expect(detector.modifierChanged(isPressed: true, timestamp: 1.00) == false)
        #expect(detector.modifierChanged(isPressed: false, timestamp: 1.08) == false)
        #expect(detector.modifierChanged(isPressed: true, timestamp: 1.20) == false)
        #expect(detector.modifierChanged(isPressed: false, timestamp: 1.28) == true)
    }

    @Test
    func longPressDoesNotCountAsATap() {
        var detector = ModifierDoubleTapDetector(maximumTapDuration: 0.2)

        #expect(detector.modifierChanged(isPressed: true, timestamp: 1.0) == false)
        #expect(detector.modifierChanged(isPressed: false, timestamp: 1.4) == false)
        #expect(detector.modifierChanged(isPressed: true, timestamp: 1.5) == false)
        #expect(detector.modifierChanged(isPressed: false, timestamp: 1.6) == false)
    }

    @Test
    func anotherInputCancelsTheDoubleTapSequence() {
        var detector = ModifierDoubleTapDetector()

        _ = detector.modifierChanged(isPressed: true, timestamp: 1.0)
        _ = detector.modifierChanged(isPressed: false, timestamp: 1.1)
        detector.cancelSequence()
        _ = detector.modifierChanged(isPressed: true, timestamp: 1.2)

        #expect(detector.modifierChanged(isPressed: false, timestamp: 1.3) == false)
    }
}
