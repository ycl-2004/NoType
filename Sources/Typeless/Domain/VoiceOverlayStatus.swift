/// Presentation state is separate from dictation so feedback can outlive a completed session.
enum VoiceOverlayStatus: CaseIterable, Equatable {
    case hidden, recording, transcribing, inserting, copying
    case inserted, copied, noSpeech, recordingFailed, transcriptionFailed, insertionFailed, copyFailed
    case permissionRequired

    var text: String {
        switch self {
        case .hidden: ""
        case .recording: "输入中…"
        case .transcribing: "转写中…"
        case .inserting: "插入中…"
        case .copying: "复制中…"
        case .inserted: "已插入"
        case .copied: "已复制"
        case .noSpeech: "未听清"
        case .recordingFailed: "录音失败"
        case .transcriptionFailed: "转写失败"
        case .insertionFailed: "插入失败"
        case .copyFailed: "复制失败"
        case .permissionRequired: "请授权"
        }
    }

    var isFailure: Bool {
        switch self {
        case .recordingFailed, .transcriptionFailed, .insertionFailed, .copyFailed, .permissionRequired: true
        default: false
        }
    }

    var isTransient: Bool {
        switch self {
        case .hidden, .recording, .transcribing, .inserting, .copying: false
        default: true
        }
    }

    static func failure(_ error: DictationError) -> Self {
        switch error {
        case .microphonePermissionRequired: .permissionRequired
        case .accessibilityPermissionRequired: .insertionFailed
        case .invalidAudioInput, .noRecordedAudio: .recordingFailed
        case .transcriptionFailed: .transcriptionFailed
        case .insertionFailed: .insertionFailed
        }
    }
}
