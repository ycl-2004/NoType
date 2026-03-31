import AVFoundation

@MainActor
protocol MicrophonePermissionManaging {
    func currentState() -> PermissionState
    func requestIfNeeded() async -> PermissionState
}

@MainActor
struct MicrophonePermissionManager: MicrophonePermissionManaging {
    func currentState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .authorized
        case .notDetermined:
            .notDetermined
        case .denied, .restricted:
            .denied
        @unknown default:
            .denied
        }
    }

    func requestIfNeeded() async -> PermissionState {
        let state = currentState()
        guard state == .notDetermined else { return state }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }
}
