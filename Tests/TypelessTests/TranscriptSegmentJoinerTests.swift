import Testing
@testable import Typeless

struct TranscriptSegmentJoinerTests {
    @Test
    func fullStopAtACutBecomesACommaWithoutASpace() {
        // The boundaries of a real 86s dictation, decoded as independent segments.
        let joined = TranscriptSegmentJoiner.join([
            "我们有没有必要回到这个app里面来使用。",
            "或者是怎么样的，然后以及。",
            "它的速度是快的。",
        ])
        #expect(joined == "我们有没有必要回到这个app里面来使用，或者是怎么样的，然后以及，它的速度是快的。")
    }

    @Test
    func hanSegmentsJoinWithoutWordSpacing() {
        #expect(TranscriptSegmentJoiner.join(["我们用的是本地的麦克风", "采样率是16000赫兹"])
            == "我们用的是本地的麦克风采样率是16000赫兹")
    }

    @Test
    func latinBoundariesKeepTheirSpace() {
        #expect(TranscriptSegmentJoiner.join(["等下我们用 GitHub", "Action 跑一遍"]) == "等下我们用 GitHub Action 跑一遍")
        #expect(TranscriptSegmentJoiner.join(["This is one sentence.", "This is another."])
            == "This is one sentence. This is another.")
        #expect(TranscriptSegmentJoiner.join(["16000", "16000"]) == "16000 16000")
    }

    @Test
    func emptySegmentsAreSkipped() {
        #expect(TranscriptSegmentJoiner.join(["", "  ", "你好。", ""]) == "你好。")
        #expect(TranscriptSegmentJoiner.join([]) == "")
    }
}
